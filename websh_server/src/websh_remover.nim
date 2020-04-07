import os, json, times
from strformat import `&`

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

      let (_, containerName, _) = containerDir.splitFile()
      discard execShellCmd(&"docker kill {containerName}")

      # lockだけは一番最後に削除する必要がある
      for dir in walkDirs(containerDir/"*"):
        let (_, base, _) = splitFile(dir)
        echo %*{"time": $now(), "level": "info", "msg": "remove " & base}
        if base == "lock": continue
        removeDir(dir)
        if base in ["images", "media", "script"]:
          createDir(dir)
          dir.setFilePermissions({
            fpUserRead,
            fpUserWrite,
            fpUserExec,
            fpGroupRead,
            fpGroupWrite,
            fpGroupExec,
            fpOthersRead,
            fpOthersWrite,
            fpOthersExec,
            })
      removeDir(containerDir/"lock")

    sleep(500) # ミリ秒
