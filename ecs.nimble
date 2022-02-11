# Package

version       = "1.0"
author        = "Yuriy Glukhov"
description   = "Entity Component System"
license       = "MIT"
srcDir        = "."
skipDirs = @["tests"]

# Dependencies
requires "variant"


task tests, "Run tests":
    exec "nim c -r tests/common.nim"
    # exec "nim js -r tests/common.nim"
