import jester,
  asyncdispatch, os, strutils

router myrouter:
  get "/":
    resp "hello"

proc main =
  var port = getEnv("API_PORT", "8080").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule:
  main()
