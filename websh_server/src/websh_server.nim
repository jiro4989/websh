import asyncdispatch, os, strutils, json, base64, times, streams, osproc
from strformat import `&`

# 外部ライブラリ
import jester, uuids

import status, dockerclient

type
  ReqShellgeiJSON* = object
    code*: string
    images*: seq[string]
  ImageObj* = object
    image*: string
    filesize*: int
    format*: string

const
  scriptName = "exec.sh"
  targetScript = "/tmp/" & scriptName
  containerPrefix = "shellgeibot"
  # #158 JSONのキーにハイフンを含めるべきでないのでlowerCamelCaseにする
  xForHeader = "xForwardedFor"

proc getTmpDir(): string = getCurrentDir() / "tmp"

proc getImages(dir: string): seq[ImageObj] =
  ## 画像ディレクトリから画像ファイルを取得。
  ## 取得の際はBase64エンコードした文字列として取得する。
  for path in walkFiles(dir / "*"):
    if not path.fileExists:
      continue
    let content = readFile(path)
    var format = "png"
    if 6 < content.len:
      let f = content[0..<6]
      case f
      of "GIF89a": format = "gif"
      else: discard
    let img = ImageObj(image: base64.encode(content), filesize: content.len, format: format)
    result.add(img)

proc createMediaFiles(dir: string, medias: seq[string]) =
  ## 入力の画像ファイルをディレクトリ配下に出力。
  ## 画像ファイルはbase64エンコードされたデータで渡されるので
  ## デコードしてから出力する。
  createDir(dir)
  for i, encodedImage in medias:
    let data = base64.decode(encodedImage)
    let file = dir / $i
    writeFile(file, data)

proc readStream(strm: var Stream): string =
  defer: strm.close()
  result = strm.readAll()

proc runCommand(command: string, args: openArray[string], timeout: int = 3): (string, string, int, string) =
  ## ``command`` を実行し、標準出力と標準エラー出力を返す。
  ## timeout は秒を指定する。
  var
    p = startProcess(command, args = args, options = {poUsePath})
    stdoutStr, stderrStr: string
  defer: p.close()

  let
    timeoutMilSec = timeout * 1000
    exitCode = waitForExit(p, timeout = timeoutMilSec)

  # 処理結果の判定
  var
    status: int
    msg: string
  if exitCode == 0:
    status = statusOk
  elif exitCode == 137:
    status = statusTimeout
    msg = &"timeout: {timeout} second"
  else:
    status = statusSystemError
    msg = &"failed to run command: command={command}, args={args}"

  # 出力の取得
  block:
    var strm = p.outputStream
    stdoutStr = strm.readStream()
  block:
    var strm = p.errorStream
    stderrStr = strm.readStream()

  result = (stdoutStr, stderrStr, status, msg)

template runShellgei(code: string, base64Images: seq[string]) =
  let
    startTime = now()
    uuid = $genUUID()
    xFor = request.headers().getOrDefault("X-Forwarded-for")
  try:
    # 一連の処理開始のログ
    echo %*{xForHeader: xFor, "time": $now(), "level": "info", "uuid": uuid, "code": code, "msg": "request begin"}

    let
      contDir = getTmpDir() / uuid
      scriptDir = contDir / "script"
      imageDir = contDir / "images"
      mediaDir = contDir / "media"
      removeFlag = contDir / "removes"
      hostContDir = getEnv("HOST_PWD") / "tmp" / uuid
      hostScriptDir = hostContDir / "script"
      hostImageDir = hostContDir / "images"
      hostMediaDir = hostContDir / "media"

    createDir(imageDir)

    # コンテナ内で実行するスクリプトの生成
    createDir(scriptDir)
    let shellScriptPath = scriptDir/scriptName
    writeFile(shellScriptPath, code)
    let hostShellScriptPath = hostScriptDir/scriptName

    # Mediaの配置
    createMediaFiles(mediaDir, base64Images)

    # コンテナ上でシェルを実行
    const image = "theoldmoon0602/shellgeibot"
    let cmds = @[
      "bash",
      "-c",
      &"sync && cp {targetScript} {targetScript}.1 && chmod +x {targetScript}.1 && {targetScript}.1 | stdbuf -o0 head -c 100K",
      ]
    var client = newClient()
    let (stdoutStr, stderrStr, status, systemMsg) =
      client.runContainer(
        name = uuid,
        image = image,
        cmds = cmds,
        script = hostShellScriptPath,
        mediaDir = hostMediaDir,
        imageDir = hostImageDir)

    # コマンドを実行するDockerイメージ名
    let containerShellScriptPath = &"/tmp/{scriptName}"
    let args = [
      "run",
      "--rm",
      "--net=none",
      "-m", "256MB",
      "--oom-kill-disable",
      "--pids-limit", "1024",
      "--name", uuid,
      "-v", &"{shellScriptPath}:{containerShellScriptPath}",
      "-v", &"{imageDir}:/{img}",
      # "-v", "./media:/media:ro",
      image,
      "bash", "-c", &"chmod +x {containerShellScriptPath} && sync && {containerShellScriptPath} | stdbuf -o0 head -c 100K",
      ]
    let timeout = getEnv("WEBSH_REQUEST_TIMEOUT", "3").parseInt
    let (stdoutStr, stderrStr, status, systemMsg) = runCommand("docker", args, timeout)

    # TODO: ここ邪魔だなぁ
    case status
    of statusOk: discard
    of statusTimeout:
      echo %*{xForHeader: xFor, "time": $now(), "level": "info", "uuid": uuid, "code": systemMsg}
    else:
      echo %*{xForHeader: xFor, "time": $now(), "level": "error", "uuid": uuid, "code": systemMsg}


    let images = getImages(imageDir)

    # 削除フラグをたてる
    createDir(removeFlag)

    let elapsedTime = (now() - startTime).inMilliseconds
    echo %*{xForHeader: xFor, "time": $now(), "level": "info", "uuid": uuid, "elapsedTime": elapsedTime, "msg": "request end"}

    resp %*{
      "status": status,
      "system_message": systemMsg,
      "stdout": stdoutStr,
      "stderr": stderrStr,
      "images": images,
      "elapsed_time": $elapsedTime & "milsec",
    }
  except:
    let msg = getCurrentExceptionMsg()
    let elapsedTime = $(now() - startTime).inMilliseconds & "milsec"
    echo %*{xForHeader: xFor, "time": $now(), "level": "error", "uuid": uuid, "elapsedTime": elapsedTime, "msg": msg}

    let data = $(%*{
      "status": statusSystemError,
      "system_message": "System error occured.",
      "stdout": "",
      "stderr": "",
      "images": [],
      "elapsed_time": elapsedTime,
    })
    resp(Http500, data, contentType = "application/json; charset=utf-8")

router myrouter:
  post "/shellgei":
    let req = request.body().parseJson().to(ReqShellgeiJSON)
    runShellgei(req.code, req.images)

  get "/ping":
    resp %*{"status":"ok"}

  get "/ping/shellgei":
    let emptyImages: seq[string] = @[]
    runShellgei("echo hello shellgeibot", emptyImages)

proc main =
  echo %*{"time": $now(), "level": "info", "msg": "server begin", "nimVersion": NimVersion}
  var port = getEnv("WEBSH_PORT", "5000").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()
  echo %*{"time": $now(), "level": "info", "msg": "server end"}

when isMainModule and not defined modeTest:
  main()
