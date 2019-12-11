import asyncdispatch, os, osproc, strutils, json, base64, times, streams
from strformat import `&`

import jester, uuids

type
  RespShellgeiJSON* = object
    code*: string

proc info(msgs: varargs[string, `$`]) =
  ## **Note:** マルチスレッドだとloggingモジュールがうまく機能しないので仮で実装
  var s: string
  for msg in msgs:
    s.add(msg)
  let now = now()
  let dt = now.format("yyyy-MM-dd")
  let ti = now.format("HH:mm:ss")
  echo &"{dt}T{ti}+0900 INFO {s}"

proc readStream(strm: var Stream): string =
  defer: strm.close()
  var lines: seq[string]
  for line in strm.lines:
    lines.add(line)
  result = lines.join("\n")

proc runCommand(command: string, args: openArray[string]): (string, string) =
  ## ``command`` を実行し、標準出力と標準エラー出力を返す。
  var
    p = startProcess(command, args = args, options = {poUsePath})
    stdoutStr, stderrStr: string
  defer: p.close()
  while p.running():
    # プロセスが処理完了するまで待機
    sleep 10
  block:
    var strm = p.outputStream
    stdoutStr = strm.readStream()
  block:
    var strm = p.errorStream
    stderrStr = strm.readStream()
  result = (stdoutStr, stderrStr)

router myrouter:
  post "/shellgei":
    # TODO:
    # uuidを使ってるけれど、どうせならシェル芸botと同じアルゴリズムでファ
    # イルを生成したい
    var respJson = request.body().parseJson().to(RespShellgeiJSON)
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
      "bash", "-c", &"chmod +x {containerShellScriptPath} && sync && timeout -sKILL 3 {containerShellScriptPath} | stdbuf -o0 head -c 100K",
      ]
    let (stdoutStr, stderrStr) = runCommand("docker", args)

    # 画像ファイルをbase64に変換
    var images: seq[string]
    for kind, path in walkDir(imageDir):
      if kind != pcFile:
        continue
      let (dir, name, ext) = splitFile(path)
      if ext.toLowerAscii notin [".png", ".jpg", ".jpeg", ".gif"]:
        continue
      images.add(base64.encode(readFile(path)))

    resp %*{"stdout":stdoutStr, "stderr":stderrStr, "images":images}
  get "/ping":
    resp %*{"status":"ok"}

proc main =
  var port = getEnv("WEBSH_PORT", "5000").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule and not defined modeTest:
  main()
