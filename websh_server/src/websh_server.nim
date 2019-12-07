import asyncdispatch, os, osproc, strutils, json, random, base64
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
  echo "INFO " & s

router myrouter:
  post "/shellgei":
    # TODO:
    # uuidを使ってるけれど、どうせならシェル芸botと同じアルゴリズムでファ
    # イルを生成したい
    let respJson = request.body().parseJson().to(RespShellgeiJSON)
    info respJson
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

    createDir(imageDir)
    let containerShellScriptPath = &"/tmp/{scriptName}"
    let name = "unko"
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
      "theoldmoon0602/shellgeibot",
      #"theoldmoon0602/shellgeibot:master",
      "bash", "-c", &"chmod +x {containerShellScriptPath} && sync && timeout -sKILL 20 {containerShellScriptPath} | stdbuf -o0 head -c 100K",
      ]
    let outp = execProcess("docker", args = args, options = {poUsePath})
    info outp

    # 画像ファイルをbase64に変換
    var images: seq[string]
    for kind, path in walkDir(imageDir):
      if kind != pcFile:
        continue
      let (dir, name, ext) = splitFile(path)
      if ext.toLowerAscii notin [".png", ".jpg", ".jpeg", ".gif"]:
        continue
      # JavaScriptのimg.srcにセットする時のプレフィックス
      let meta = "data:image/png;base64,"
      let data = meta & base64.encode(readFile(path))
      images.add(data)

    resp %*{"stdout":outp, "stderr":"", "images":images}

proc main =
  var port = getEnv("SHELLGEI_WEB_PORT", "5000").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule:
  main()
