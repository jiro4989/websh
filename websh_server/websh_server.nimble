# Package

version       = "0.1.0"
author        = "jiro4989"
description   = "A new awesome nimble package"
license       = "Apache-2.0 License"
srcDir        = "src"
bin           = @["websh_server"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.4.0"
requires "jester >= 0.5.0"
requires "uuids >= 0.1.10"

import std/strformat

const
  image = "websh_server"

task buildDockerImage, "Build docker image":
  exec &"docker build --target base -t {image} ."

task testOnDocker, "Run test on docker container":
  exec &"docker run --rm -v $PWD:/work -it {image} nimble test -Y"