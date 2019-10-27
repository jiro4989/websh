import jester, uuids
import asyncdispatch, os, osproc, strutils, json
from strformat import `&`

type
  RespShellgeiJSON* = object
    code*: string

router myrouter:
  post "/shellgei":
    let respJson = request.body().parseJson().to(RespShellgeiJSON)
    echo respJson
    let tmpDir = "." / "tmp"
    let uuid = $genUUID()
    let scriptName = uuid / ".sh"
    let shellScriptPath = tmpDir / scriptName
    writeFile(shellScriptPath, respJson.code)
    defer: removeFile(shellScriptPath)

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
      "theoldmoon0602/shellgeibot:master",
      "bash", "-c", &"chmod +x {containerShellScriptPath} && sync && {containerShellScriptPath} | stdbuf -o0 head -c 100K",
      ]
    let outp = execProcess("docker", args = args)
    resp %*{"result":outp}

proc main =
  var port = getEnv("API_PORT", "8080").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule:
  main()
