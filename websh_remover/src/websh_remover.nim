import os, json, times
from strformat import `&`

let tmpDir = getEnv("WEBSH_REMOVER_DIR")
if tmpDir == "":
  echo %*{"time": $now(), "level": "error", "msg": "'WEBSH_REMOVER_DIR' environment variables was not set", "nimVersion": NimVersion}
  quit 1

when isMainModule and not defined modeTest:
  echo %*{"time": $now(), "level": "info", "msg": "remover begin", "nimVersion": NimVersion}
  while true:
    # containerDir = tmp/containerName
    for containerDir in walkDirs(tmpDir/"*"):
      if not dirExists(containerDir): continue
      let rmflagDir = containerDir/"removes"
      if not dirExists(rmflagDir): continue

      removeDir(containerDir)
      echo %*{"time": $now(), "level": "info", "msg": &"{containerDir} was removed"}

    sleep(500) # ミリ秒
