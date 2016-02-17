#!/usr/bin/env nim

mode = ScriptMode.Silent

packageName   = "nimactors"
version       = "0.0.1"
author        = "Anatoly Galiulin <galiulin.anatoly@gmail.com>"
description   = "Actors library for Nim"
license       = "MIT"
srcDir        = "src"

requires "nim >= 0.13.0", "nimfp >= 0.0.3"

import ospaths

proc build_test(srcFile: string) =
  let d = thisDir() / "bin"
  if not d.dirExists:
    mkDir d

  --threads: on
  switch("NimblePath", srcDir)
  switch("out", d / srcFile.splitPath[1].toExe)

  setCommand("c", srcFile)

task tests, "Build and run tests":
  --run
  build_test("tests/test_all.nim")
