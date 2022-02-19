# Package

version       = "1.0"
author        = "Yuriy Glukhov"
description   = "Entity Component System"
license       = "MIT"
srcDir        = "."
skipDirs = @["tests"]

# Dependencies
requires "variant"

template runTests =
    exec "nim c -r tests/common.nim"
    # exec "nim js -r tests/common.nim"

task test, "Run tests":
    runTests

task tests, "Run tests":
    runTests
