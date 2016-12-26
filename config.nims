import ospaths

mode = ScriptMode.Silent

srcDir = "src"

proc buildTest(srcFile: string) =
  let d = thisDir() / "bin"
  if not d.dirExists:
    mkDir d

  --threads: on
  switch("NimblePath", srcDir)
  switch("path", srcDir)
  switch("out", d / srcFile.splitFile[1].toExe)

  setCommand("c", srcFile)

task test, "Build and run tests":
  --run
  buildTest("tests/test_all.nim")
