import asyncdispatch, os, strutils, json, base64, times
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

router myrouter:
  post "/shellgei":
    const
      # #158 JSONのキーにハイフンを含めるべきでないのでlowerCamelCaseにする
      xForHeader = "xForwardedFor"
    let
      now = now()
      uuid = $genUUID()
      xFor = request.headers().getOrDefault("X-Forwarded-for")
    try:
      var respJson = request.body().parseJson().to(ReqShellgeiJSON)

      # 一連の処理開始のログ
      echo %*{xForHeader: xFor, "time": $now(), "level": "info", "uuid": uuid, "code": respJson.code, "msg": "request begin"}

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
      writeFile(shellScriptPath, respJson.code)
      let hostShellScriptPath = hostScriptDir/scriptName

      # Mediaの配置
      createMediaFiles(mediaDir, respJson.images)

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

      let elapsedTime = (now() - now).inMilliseconds
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
      let elapsedTime = $(now() - now).inMilliseconds & "milsec"
      echo %*{xForHeader: xFor, "time": $now(), "level": "error", "uuid": uuid, "elapsedTime": elapsedTime, "msg": msg}

      resp %*{
        "status": statusSystemError,
        "system_message": "System error occured.",
        "stdout": "",
        "stderr": "",
        "images": [],
        "elapsed_time": elapsedTime,
      }
  get "/ping":
    resp %*{"status":"ok"}

proc main =
  echo %*{"time": $now(), "level": "info", "msg": "server begin", "nimVersion": NimVersion}
  var port = getEnv("WEBSH_PORT", "5000").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()
  echo %*{"time": $now(), "level": "info", "msg": "server end"}

when isMainModule and not defined modeTest:
  main()
