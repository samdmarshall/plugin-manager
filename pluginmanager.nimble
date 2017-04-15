# Package

version       = "0.1.0"
author        = "Samantha Marshall"
description   = "Simple plugin implementation"
license       = "BSD 3-Clause"
srcDir        = "src"

skipDirs      = @["tests"]

# Dependencies

requires "nim >= 0.16.0"


task test, "Runs the test suite":
  exec "nim c tests/plugin/plugin.nim"
  exec "nim c -r tests/test"
