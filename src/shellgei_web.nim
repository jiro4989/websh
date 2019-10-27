import jester
import asyncdispatch, os, strutils, json

type
  RespShellgeiJSON* = object
    code*: string

router myrouter:
  post "/shellgei":
    let formData = request.body().parseJson().to(RespShellgeiJSON)
    echo formData
    resp %*{"result": "test"}

proc main =
  var port = getEnv("API_PORT", "8080").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule:
  main()
