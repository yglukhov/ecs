# Package

version       = "0.1"
author        = "Yuriy Glukhov"
description   = "Entity Component System"
license       = "MIT"

# Dependencies
requires "variant"
requires "https://github.com/yglukhov/typelists"


task test, "Run tests":
  exec "nim c -r tests/common.nim"
  # exec "nim js -r tests/common.nim"
