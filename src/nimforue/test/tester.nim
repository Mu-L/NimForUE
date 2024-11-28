
import buildscripts/nimforueconfig
import testutils
import std/[os, macros, genasts, sequtils, strutils]
macro importAll*(path: static string, filter: static string = "test.nim") : untyped =
  let modules =
        walkDirRec(path)
        .toSeq()
        .filterIt(it.endsWith(filter))

  func importStmts(modName:string) : NimNode =
    genAst(module=ident modName):
      import module
  echo "Importing: ", modules
  result = nnkStmtList.newTree(modules.map(importStmts))

importAll(currentSourcePath.parentDir / "tests",  "test.nim")

# template ueTestOnly*(name:string, body:untyped) = internalTest(name, true, body)
proc runNUETests() {.exportc, cdecl, dynlib.} =
  runTests()
  saveTestResults()


