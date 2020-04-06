# Package

version       = "0.1.0"
author        = "jiro4989"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["index.js"]
binDir        = "public/js"

backend       = "js"

# Dependencies

requires "nim >= 1.0.2"
requires "karax#c00d7dc34031aa9a74b54a632b21caaec03d3fea"
