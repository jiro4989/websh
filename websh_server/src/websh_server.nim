import asyncdispatch, os, osproc, strutils, json, base64, times, streams
from strformat import `&`

import jester, uuids

type
  ReqShellgeiJSON* = object
    code*: string
  ImageObj* = object
    image*: string
    filesize*: int

const
  statusOk = 0
  statusTimeout = 1
  statusSystemError = 100

proc logging(level: string, msgs: varargs[string, `$`]) =
  ## **Note:** マルチスレッドだとloggingモジュールがうまく機能しないので仮で実装
  var s: string
  for msg in msgs:
    s.add(msg)
  let now = now()
  let dt = now.format("yyyy-MM-dd")
  let ti = now.format("HH:mm:ss")
  echo &"{dt}T{ti}+0900 {level} {s}"

proc info(msgs: varargs[string, `$`]) =
  logging "INFO", msgs

proc error(msgs: varargs[string, `$`]) =
  logging "ERROR", msgs

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
    info &"exitCode={exitCode}, msg={msg}"
  else:
    status = statusSystemError
    msg = &"failed to run command: command={command}, args={args}"
    error &"exitCode={exitCode}, msg={msg}"

  # 出力の取得
  block:
    var strm = p.outputStream
    stdoutStr = strm.readStream()
  block:
    var strm = p.errorStream
    stderrStr = strm.readStream()

  result = (stdoutStr, stderrStr, status, msg)

router myrouter:
  post "/shellgei":
    try:
      # TODO:
      # uuidを使ってるけれど、どうせならシェル芸botと同じアルゴリズムでファ
      # イルを生成したい
      var respJson = request.body().parseJson().to(ReqShellgeiJSON)
      info respJson
      # シェバンを付けないとshとして評価されるため一部の機能がつかえない模様(プロ
      # セス置換とか) (#7)
      if not respJson.code.startsWith("#!"):
        # シェバンがついてないときだけデフォルトbash
        respJson.code = "#!/bin/bash\n" & respJson.code
      let uuid = $genUUID()
      let scriptName = &"{uuid}.sh"
      let shellScriptPath = getTempDir() / scriptName
      writeFile(shellScriptPath, respJson.code)

      let img = "images"
      let imageDir = getCurrentDir() / img / uuid
      defer:
        removeFile(shellScriptPath)
        info &"{shellScriptPath} was removed"
        removeDir(imageDir)
        info &"{imageDir} was removed"

      # コマンドを実行するDockerイメージ名
      createDir(imageDir)
      let containerShellScriptPath = &"/tmp/{scriptName}"
      let imageName = getEnv("WEBSH_DOCKER_IMAGE", "theoldmoon0602/shellgeibot")
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
        imageName,
        "bash", "-c", &"chmod +x {containerShellScriptPath} && sync && {containerShellScriptPath} | stdbuf -o0 head -c 100K",
        ]
      let timeout = getEnv("WEBSH_REQUEST_TIMEOUT", "3").parseInt
      let (stdoutStr, stderrStr, status, systemMsg) = runCommand("docker", args, timeout)

      # 画像ファイルをbase64に変換
      var images: seq[ImageObj]
      for path in walkFiles(imageDir / "*"):
        let (dir, name, ext) = splitFile(path)
        if ext.toLowerAscii notin [".png", ".jpg", ".jpeg", ".gif"]:
          continue
        let content = readFile(path)
        let img = ImageObj(image: base64.encode(content), filesize: content.len)
        images.add(img)

      resp %*{"status":status, "system_message":systemMsg, "stdout":stdoutStr, "stderr":stderrStr, "images":images}
    except:
      let msg = getCurrentExceptionMsg()
      error msg
      resp %*{"status":statusSystemError, "system_message":"System error occured.", "stdout":"", "stderr":"", "images":[]}
  get "/ping":
    resp %*{"status":"ok"}

proc main =
  var port = getEnv("WEBSH_PORT", "5000").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule and not defined modeTest:
  main()
