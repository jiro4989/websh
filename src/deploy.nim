when isMainModule:
  import os, times, logging
  from strformat import `&`

  addHandler(newConsoleLogger(lvlInfo, fmtStr = verboseFmtStr, useStderr = true))

  info "デプロイ開始:"

  const
    dirPrefix = "/opt"
    app = "shellgei-web"
    appDir = dirPrefix / app

  let
    now = now().format("yyyy-MM-dd-HH-mm-ss")
    repo = appDir / now
    latestDir = appDir / "latest"

  if 0 != execShellCmd(&"git clone https://github.com/jiro4989/{app} {repo}"):
    error "cloneに失敗: Path = {repo}"
    quit 1
  if 0 != execShellCmd(&"unlink {latestDir}"):
    error "unlinkに失敗: Path = {latestDir}"
    quit 1
  info &"シンボリックリンクを作成: Path = {latestDir}"
  createSymlink(repo, latestDir)

  info "デプロイ正常終了:"
