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
  var kvs: seq[string]
  for i in 0..<(msgs.len div 2):
    let i = i * 2
    let k = msgs[i]
    var v = msgs[i+1]
    if " " in v:
      v = &"'{v}'"
    kvs.add(&"{k}={v}")

  let
    now = now()
    dt = now.format("yyyy-MM-dd")
    ti = now.format("HH:mm:ss")
    msg = kvs.join(" ")
  echo &"{dt}T{ti}+0900 {level} {msg}"

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

router myrouter:
  post "/shellgei":
    try:
      let uuid = $genUUID()
      var respJson = request.body().parseJson().to(ReqShellgeiJSON)
      info "uuid", uuid, "json", respJson
      let scriptName = &"{uuid}.sh"
      let shellScriptPath = getTempDir() / scriptName
      writeFile(shellScriptPath, respJson.code)

      let img = "images"
      let imageVolume = &"{img}_{uuid}"
      let imageDir = getCurrentDir() / img / uuid
      defer:
        info "uuid", uuid, "msg", &"removes {shellScriptPath} script ..."
        removeFile(shellScriptPath)

        info "uuid", uuid, "msg", &"removes {imageDir} directory ..."
        removeDir(imageDir)

        info "uuid", uuid, "msg", &"kills {uuid} docker container ..."
        discard execCmd(&"docker kill {uuid}")

        info "uuid", uuid, "msg", &"Remove {imageVolume} docker volume ..."
        discard execCmd(&"docker volume rm -f {imageVolume}")

      # コマンドを実行するDockerイメージ名
      let vScript = &"/tmp/{scriptName}"
      let imageName = getEnv("WEBSH_DOCKER_IMAGE", "theoldmoon0602/shellgeibot")
      let args = [
        "run",
        "--rm",
        "--net=none",
        "-m", "256MB",
        "--oom-kill-disable",
        "--pids-limit", "1024",
        "--name", uuid,
        "--log-driver=json-file",
        "--log-opt", "max-size=100m",
        "--log-opt", "max-file=3",
        "-v", &"{shellScriptPath}:{vScript}:ro",
        "-v", &"{imageVolume}:/{img}",
        # "-v", "./media:/media:ro",
        imageName,
        "bash", "-c", &"sync && cp {vScript} {vScript}.1 && chmod +x {vScript}.1 && {vScript}.1 | stdbuf -o0 head -c 100K",
        ]
      let timeout = getEnv("WEBSH_REQUEST_TIMEOUT", "3").parseInt
      let (stdoutStr, stderrStr, status, systemMsg) = runCommand("docker", args, timeout)

      case status
      of statusOk: discard
      of statusTimeout:
        info "uuid", uuid, "msg", systemMsg
      else:
        error "uuid", uuid, "msg", systemMsg

      # 画像ディレクトリにファイルだけ移動
      # 移動前に権限を操作しておく
      createDir(imageDir)
      let s = execProcess("docker", args=[
        "run",
        "--rm",
        "-v", &"{imageVolume}:/src",
        "-v", &"{imageDir}:/dst",
        "bash",
        "-c",
        """chmod -R 0777 /src/ && ls -1d /src/* | while read -r f; do [[ -f "$f" ]] && mv "$f" /dst/; done """,
        ], options={poUsePath})
      info "uuid", uuid, "msg", s

      # 画像ファイルをbase64に変換
      var images: seq[ImageObj]
      for path in walkFiles(imageDir / "*"):
        if not path.existsFile:
          continue
        let (_, _, ext) = splitFile(path)
        if ext.toLowerAscii notin [".png", ".jpg", ".jpeg", ".gif"]:
          continue
        let content = readFile(path)
        let img = ImageObj(image: base64.encode(content), filesize: content.len)
        images.add(img)

      resp %*{"status":status, "system_message":systemMsg, "stdout":stdoutStr, "stderr":stderrStr, "images":images}
    except:
      let msg = getCurrentExceptionMsg()
      error "msg", msg
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
