import os, json, times

let
  tmpDir = getCurrentDir() / "tmp"

when isMainModule and not defined modeTest:
  echo %*{"time": $now(), "level": "info", "msg": "remover begin", "nimVersion": NimVersion}
  while true:
    # containerDir = tmp/containerName
    for containerDir in walkDirs(tmpDir/"*"):
      if not existsDir(containerDir): continue
      let rmflagDir = containerDir/"removes"
      if not existsDir(rmflagDir): continue
      removeDir(containerDir)

    sleep(500) # ミリ秒
