# Package

version       = "0.1"
author        = "Yuriy Glukhov"
description   = "Entity Component System"
license       = "MIT"

# Dependencies

task tests, "Run tests":
    exec "nim c -r tests/common.nim"
    exec "nim js -r tests/common.nim"
