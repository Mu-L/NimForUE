import std/[json, jsonutils, os, tables, strformat, sequtils]
import buildscripts/nimforueconfig

import ../utils/utils   

export utils
type
  TestResult* = object
    name*: string
    success*: bool
    message*: string
  
  TestSuite* = object
    name*: string
    results*: TableRef[string, TestResult]
    success*: bool
  
var testSuites = newTable[string, TestSuite]()
var testsToRun = newSeq[proc()]()

proc runTests*() =
  for test in testsToRun:
    test()

proc saveTestResults*() =
  for suiteName in testSuites.keys:
    var suite = testSuites[suiteName]
    suite.success = suite.results.values.toSeq.mapIt(it.success).foldl(a and b, true)
    testSuites[suiteName] = suite

  let json = testSuites.toJson().pretty
  writeFile(PluginDir / "test.json", json)

template suite*(n {.inject.}:static string, body: untyped)  = 
  block:
    var suiteName {.inject.} = n       
    body
    
template internalTest(testName : string, body:untyped) =
  block:
    let test = proc() = 
      var suiteName {.inject.} = when declared(suiteName): suiteName else: "Global"
      if suiteName notin testSuites:
        testSuites[suiteName] = TestSuite(name: suiteName, results: newTable[string, TestResult]())  
      try:
        body            
        testSuites[suiteName].results[testName] = TestResult(name: testName, success: true, message: "")
      except Exception as e:
        UE_Error "Test failed: " & testName & " in suite " & suiteName & " with message: " & e.msg
        let msg = e.msg
        testSuites[suiteName].results[testName] = TestResult(name: testName, success: false, message: msg)
      
    testsToRun.add test

template test*(name:string, body:untyped) = 
  internalTest(name, body)

 

