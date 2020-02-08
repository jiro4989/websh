from os import `/`

let
  frontDir = thisDir() / "websh_front"
  serverDir = thisDir() / "websh_server"
  siteUrl = "http://localhost/"

task run, "コンテナ停止してビルドして全部起動しなおす":
  selfExec "down"
  selfExec "buildServer"
  selfExec "buildFront"
  selfExec "up"
  selfExec "runServer"

task buildFront, "websh_frontのJSをローカル用にビルドする":
  withDir frontDir:
    exec "nimble build -Y -d:local"

task buildServer, "websh_serverをビルドする":
  withDir serverDir:
    exec "nimble build -Y"

task runServer, "websh_serverを起動する":
  withDir serverDir:
    exec "WEBSH_REQUEST_TIMEOUT=10 ./bin/websh_server"

task up, "Dockerコンテナを起動する":
  echo siteUrl
  exec "docker-compose up -d"

task down, "Dockerコンテナを停止(down)する":
  exec "docker-compose down"

task pullShellgeiBotImage, "シェル芸botのDockerイメージを取得する":
  exec "docker pull theoldmoon0602/shellgeibot"
