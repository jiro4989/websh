import asyncdispatch, os, osproc, strutils, json, random, logging
from strformat import `&`

import jester, uuids

addHandler(newConsoleLogger(lvlInfo, fmtStr = verboseFmtStr, useStderr = true))

type
  RespShellgeiJSON* = object
    code*: string

router myrouter:
  post "/shellgei":
    # TODO:
    # uuidを使ってるけれど、どうせならシェル芸botと同じアルゴリズムでファ
    # イルを生成したい
    let respJson = request.body().parseJson().to(RespShellgeiJSON)
    echo respJson
    let uuid = $genUUID()
    let scriptName = &"{uuid}.sh"
    let shellScriptPath = getTempDir() / scriptName
    writeFile(shellScriptPath, respJson.code)
    defer:
      removeFile(shellScriptPath)
      echo &"{shellScriptPath} was removed"

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
      # "-v", "./images:/images",
      # "-v", "./media:/media:ro",
      "theoldmoon0602/shellgeibot",
      #"theoldmoon0602/shellgeibot:master",
      "bash", "-c", &"chmod +x {containerShellScriptPath} && sync && {containerShellScriptPath} | stdbuf -o0 head -c 100K",
      ]
    let outp = execProcess("docker", args = args, options = {poUsePath})
    resp %*{"result":outp}

  get "/webhook/deploy/@env":
    let env = @"env"
    case env
    of "prd":
      if 0 != execShellCmd("deploy"):
        error "デプロイに失敗: Command = deploy"
    of "stg":
      if 0 != execShellCmd("deploy"):
        error "デプロイに失敗: Command = deploy"
    else:
      error &"不正なenv: env = {env}"

proc main =
  var port = getEnv("API_PORT", "8080").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule:
  main()
