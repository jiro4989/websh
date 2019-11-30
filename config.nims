from os import `/`

let
  frontDir = thisDir() / "shellgei_web_front"
  serverDir = thisDir() / "shellgei_web_server"
  siteUrl = "http://localhost/"

task buildFront, "shellgei_web_frontのJSをビルドする":
  withDir frontDir:
    selfExec "nimble build -Y"

task buildServer, "shellgei_web_serverをビルドする":
  withDir serverDir:
    selfExec "nimble build -Y"

task up, "Dockerコンテナを起動する":
  echo siteUrl
  exec "docker-compose up"

task down, "Dockerコンテナを停止(down)する":
  exec "docker-compose down"
