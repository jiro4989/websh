# Package

version       = "0.1.0"
author        = "jiro4989"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["websh_server", "websh_remover"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.0.2"
requires "jester#7e8df6543a57c3ef31d1e5ae33f88a707486ec11"
requires "uuids >= 0.1.10"
