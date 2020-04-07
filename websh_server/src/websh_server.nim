import asyncdispatch, os, osproc, strutils, json, base64, times, streams, sequtils
from strformat import `&`
from algorithm import sorted

# 外部ライブラリ
import jester, uuids

type
  ReqShellgeiJSON* = object
    code*: string
    images*: seq[string]
  ImageObj* = object
    image*: string
    filesize*: int

const
  statusOk = 0
  statusTimeout = 1
  statusSystemError = 100
  scriptName = "exec.sh"
  containerPrefix = "shellgeibot"

proc getTmpDir(): string = getCurrentDir() / "tmp"

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

proc runCommandOnContainer(scriptDir, containerName: string): (string, string, int, string) =
  let vScript = &"/tmp/script/{scriptName}"
  let args = [
    "exec",
    "-i", containerName,
    "bash", "-c", &"sync && cp {vScript} {vScript}.1 && chmod +x {vScript}.1 && {vScript}.1 | stdbuf -o0 head -c 100K",
    ]
  let timeout = getEnv("WEBSH_REQUEST_TIMEOUT", "3").parseInt
  result = runCommand("docker", args, timeout)

proc getImages(dir: string): seq[ImageObj] =
  ## 画像ディレクトリから画像ファイルを取得。
  ## 取得の際はBase64エンコードした文字列として取得する。
  for path in walkFiles(dir / "*"):
    if not path.existsFile:
      continue
    let content = readFile(path)
    let img = ImageObj(image: base64.encode(content), filesize: content.len)
    result.add(img)

proc fetchContainerName(count: int): string =
  ## 一番起動時間の長いコンテナ名を返す
  ##
  ## TODO: コマンドラインで実行した結果をパースしていてとても気に入らないけれど
  ## 、かと言ってAPIリクエストを調べるのも面倒なのでとりあえずはコレで...
  let conts = toSeq(1..count).mapIt(&"{containerPrefix}_{it}")
  var args = @["inspect", "-f", "{{.State.StartedAt}} {{.State.Status}} {{.Name}}"]
  args = args.concat(conts)
  let stdoutstr = execProcess("docker",
              args = args,
              options = {poUsePath})
  result = stdoutstr.strip().split("\n").filterIt(" running " in it).sorted()[0].split(" ")[^1]

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
      xForHeader = "X-Forwarded-for"
    let
      now = now()
      uuid = $genUUID()
      xFor = request.headers().getOrDefault(xForHeader)
    try:
      var respJson = request.body().parseJson().to(ReqShellgeiJSON)

      # 一連の処理開始のログ
      echo %*{xForHeader: xFor, "time": $now(), "level": "info", "uuid": uuid, "code": respJson.code, "msg": "request begin"}

      let
        containersCount = getEnv("WEBSH_CONTAINERS_COUNT", "4").parseInt()
        containerName = fetchContainerName(containersCount)
        contDir = getTmpDir() / containerName
        scriptDir = contDir / "script"
        imageDir = contDir / "images"
        mediaDir = contDir / "media"
        lockDir = contDir / "lock"
        rmflagDir = contDir / "removes"

      # ロックファイルの生成
      # trueが反るときはすでにディレクトリが存在する(ロック中)なので終了
      if existsOrCreateDir(lockDir):
        resp %*{
          "status": statusSystemError,
          "system_message": "System is busy. Please wait a second.",
          "stdout": "",
          "stderr": "",
          "images": [],
          "elapsed_time": "0milsec",
        }

      defer:
        # 削除フラグファイルの作成
        discard existsOrCreateDir(rmflagDir)

      # コンテナ内で実行するスクリプトの生成
      let shellScriptPath = scriptDir/scriptName
      writeFile(shellScriptPath, respJson.code)

      # Mediaの配置
      createMediaFiles(mediaDir, respJson.images)

      # コンテナ上でシェルを実行
      let (stdoutStr, stderrStr, status, systemMsg) = runCommandOnContainer(scriptDir, containerName)

      # TODO: ここ邪魔だなぁ
      case status
      of statusOk: discard
      of statusTimeout:
        echo %*{xForHeader: xFor, "time": $now(), "level": "info", "uuid": uuid, "code": systemMsg}
      else:
        echo %*{xForHeader: xFor, "time": $now(), "level": "error", "uuid": uuid, "code": systemMsg}

      let images = getImages(imageDir)

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
