import ospaths

mode = ScriptMode.Silent

srcDir = "src"
let testDir = "tests"
let buildDir = "nimcache"

template commonSettings(binFile = ""): untyped =
  --threads: on
  switch("NimblePath", srcDir)
  switch("nimcache", buildDir / binFile)

proc buildTest(srcFile, binFile: string) =
  let d = thisDir() / "bin"
  if not d.dirExists:
    mkDir d

  commonSettings(binFile = binFile)
  switch("out", d / binFile)

  setCommand("c", srcFile)

task clean, "Clean the project":
  rmDir buildDir

task test, "Build and run tests":
  --run
  buildTest(testDir / "test_all.nim", "test_all")

task cfg, "Show nim configuration":
  commonSettings
  setCommand("dump")
