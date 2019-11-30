from os import `/`

let
  frontDir = thisDir() / "shellgei_web_front"
  serverDir = thisDir() / "shellgei_web_server"
  siteUrl = "http://localhost/"

task run, "コンテナ停止してビルドして全部起動しなおす":
  selfExec "down"
  selfExec "buildServer"
  selfExec "buildFront"
  selfExec "up"
  selfExec "runServer"

task buildFront, "shellgei_web_frontのJSをビルドする":
  withDir frontDir:
    exec "nimble build -Y"

task buildServer, "shellgei_web_serverをビルドする":
  withDir serverDir:
    exec "nimble build -Y"

task runServer, "shellgei_web_serverを起動する":
  withDir serverDir:
    exec "./bin/shellgei_web_server"

task up, "Dockerコンテナを起動する":
  echo siteUrl
  exec "docker-compose up -d"

task down, "Dockerコンテナを停止(down)する":
  exec "docker-compose down"
