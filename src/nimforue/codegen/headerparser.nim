# include ../unreal/prelude

import std/[strformat, tables, enumerate, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans]
import ../../buildscripts/nimforueconfig
import models
import ../utils/utils


type
  CppTypeInfo* = object
    name* : string #Name of the type FSomeType USomeType
    cppDefinitionLine : string #The line where the type is defined. This will be the body at some point
    needsObjectInitializerCtor*: bool

proc getIncludesFromHeader(path, header: string): seq[string] = 
  #path only passed to show better errors
  let lines = header.split("\n")
  func getHeaderFromIncludeLine(line: string): string = 
    line.multiReplace(@[
      ("#include", ""),
      ("<", ""),
      (">", ""),
      ("\"", ""),
      ("\t", ""),
    ]).strip()

  let currentIncludeOrderVersion = UEVersion() #We assume the UEVersion matches the IncludeOrderVersion (we could read it from the cs file though)
  # echo "Current Include Order Version: ", currentIncludeOrderVersion
  assert currentIncludeOrderVersion != 0, "Current version is 0. This is not expected. Which means this function is running at compile time and it shouldnt. The cache file must be generated before compiling guest"
  #Everything within 
  #if UE_ENABLE_INCLUDE_ORDER_DEPRECATED_IN_MAJOR_MINOR should only be included if the current version is that one.

  proc isInclude(line: string): bool = 
    # if line.contains("//") and "#include" in line: discard
    #   echo "Warning: Commented include found in header", line
    "#include" in line  #this may introduce incorrect includes? like in comments. 

  var insideConditionalBlock = false
  var includesInsideCurrentBlock = newSeq[string]()
  var lastConditionalBlockVersion: float
  var isNegated = false #if the condition is negated
  const IncludeOrderDeprecated = "UE_ENABLE_INCLUDE_ORDER_DEPRECATED_IN_"
  
  for idx, line in enumerate(lines):
    if IncludeOrderDeprecated in line and "#endif" notin line:
      try:
        lastConditionalBlockVersion = 
          line
            .multiReplace(@[
              (" ", ""), 
              ("\t", ""),
              (IncludeOrderDeprecated, ""),
              ("_", "."),
              ("#if", ""),  
              ("//", ""),  
              ("!", "")                      
            ])
            .strip()
            .parseFloat()
      except CatchableError:
        echo "Error parsing version in include order:", line
        echo "Line", idx + 1
        echo path
        quit()

      isNegated = ("!" & IncludeOrderDeprecated) in line
      insideConditionalBlock = true
      continue
    if insideConditionalBlock and line.isInclude:
      includesInsideCurrentBlock.add line.getHeaderFromIncludeLine()
    elif line.isInclude:
      result.add line.getHeaderFromIncludeLine()

    if insideConditionalBlock:
      if line.contains("#endif"):
        insideConditionalBlock = false        
        if lastConditionalBlockVersion == currentIncludeOrderVersion and not isNegated or
          lastConditionalBlockVersion != currentIncludeOrderVersion and isNegated:
            result.add(includesInsideCurrentBlock)

        # echo "End of conditional include block"
        # echo "Includes inside block", includesInsideCurrentBlock
        includesInsideCurrentBlock = newSeq[string]()

proc getHeaderFromPath(path: string): Option[string] = 
  if fileExists(path):
    # echo "Header found: ", path
    some readFile(path)
  else: 
    none(string)

func getModuleRelativePathVariations(moduleName, moduleRelativePath:string) : seq[string] = 
    var variations = @["Public", "Classes"]
    
    #GameplayAbilities/Public/AbilitySystemGlobals.h <- Header can be included like so
    #"GameplayTags/Classes/GameplayTagContainer.h"
    # Classes/GameFramework/Character.h" <- module relative path
    # Include as "GameFramework/Character.h"
    #Classes/Engine/DataTable.h
    #"Engine/Classes/Engine/DataTable.h

    let header = moduleRelativePath.split("/")[^1]
    result = @[
        moduleRelativePath, #usually is Public/SomeClass.h
        moduleRelativePath.split("/").filterIt(it notin moduleName).join("/"),
        
      ] & #PROBABLY some of this only happens with engine. It may worth to reduce them
      variations.mapIt(&"{moduleName}/{it}/{header}") &
      variations.mapIt(&"{it}/{moduleName}/{header}") &
      variations.mapIt(&"{moduleName}/{it}/{moduleName}/{header}") &
      moduleRelativePath.split("/").filterIt(it notin variations).join("/")

func isModuleRelativePathInHeaders*(moduleName, moduleRelativePath:string, headers:seq[string]) : bool = 
  let paths = getModuleRelativePathVariations(moduleName, moduleRelativePath)
  # UE_Log &"Checking if {paths} is in {headers}"
  #We cant just check against the header because some headers may have the same name but be in different folders
  #So we check if the relative path is in the include. 
  if not paths.any(): false
  else: 
    for path in paths:
      if path in headers: 
        return true
    false

#returns the absolute path of all the include paths
proc getAllIncludePaths*() : seq[string] = 
  result = getNimForUEConfig().getUEHeadersIncludePaths()    
  #some modules doesnt have "Classes" in the include paths so we dont increase the cmd length, they end with "Public"
  #we add it here, because we are not running a cmd and the ubt already does it 
  result.add result.filterIt(it.endsWith "Public").mapIt(it[0..^7] / "Classes")
  result.add NimGameDir()

proc getHeaderIncludesFromIncludePaths(headerName:string, includePaths:seq[string]): seq[string] = 
  for path in includePaths:
    let headerPath = path / headerName
    var header = getHeaderFromPath(headerPath)
    #some modules doesnt have "Classes" in the include paths so we dont increase the cmd length, they end with "Public"
    #we add it here, because we are not running a cmd and the ubt already does it 
    if header.isNone and path.endsWith "Public":
      let clsPath = path[0..^7] / "Classes" / headerName
      header = getHeaderFromPath(clsPath)
    if header.isSome:
      return getIncludesFromHeader(headerPath, header.get)
  newSeq[string]()


proc traverseAllIncludes*(entryPoint:string, includePaths:seq[string], visited:seq[string], depth=0, maxDepth=3) : seq[string] = 
  let includes = getHeaderIncludesFromIncludePaths(entryPoint, includePaths).filterIt(it notin visited)
  let newVisited = (visited & includes).deduplicate()
  if depth >= maxDepth:
    return newVisited
  result = 
    includes & includes
      .mapIt(traverseAllIncludes(it, includePaths, newVisited, depth+1))
      .flatten()
  # echo "result", result


proc saveIncludesToFile*(path:string, includes:seq[string]) =   
  writeFile(path, $includes.toJson())

var pchIncludes {.compileTime.} : seq[string]
proc getPCHIncludes*(useCache=true) : seq[string] = 
  if pchIncludes.any(): 
    return pchIncludes
  let dir = PluginDir/".headerdata"
  createDir(dir)
  let path = dir / "allincludes.json"
  pchIncludes = 
    if useCache and fileExists(path): #TODO Check it's newer than the PCH
      readFile(path).parseJson().to(seq[string])
    else:      
      let includePaths = getAllIncludePaths()
      var includes = newSeq[string]()
      includes.add traverseAllIncludes("UEDeps.h", includePaths, @[])
      includes.add traverseAllIncludes("nuegame.h", includePaths, @[])
      includes = includes.deduplicate() 
      # echo "indlude paths", pchIncludes
      if useCache: 
        saveIncludesToFile(path, includes)
      includes
  pchIncludes  

  
  # UE_Log &"Includes found on the PCH: {pchIncludes.len}"
  # let uniquePCHIncludes = pchIncludes.mapIt(it.split("/")[^1]).deduplicate()
  # UE_Log &"Unique Includes found on the PCH: {uniquePCHIncludes.len}"

  # uniquePCHIncludes


# #called from genreflection data everytime the bindings are attempted to be generated, before gencppbindings
# proc savePCHTypes*(modules:seq[UEModule]) = 
#   let dir = PluginDir/".headerdata"
#   createDir(dir)
#   let path = dir/"allpchtypes.json"
#   #Is in PCH is set in UEMEta if the include is in the include list
#   let pchTypes = modules.mapIt(it.types).flatten.filterIt(it.isInPCH).mapIt(it.name)
#   let allTypes = pchTypes & getAllTypes()

#   saveIncludesToFile(path, allTypes.deduplicate())



proc readHeader(searchPaths:seq[string], header:string) : Option[string]  = 
  result = 
    searchPaths
      .first(dir=>fileExists(dir/header))
      .map(dir=>readFile(dir/header))
  if result.isNone and header.split("/").len>1:    
    return readHeader(searchPaths, header.split("/")[^1])

func getContentBetween(content: string, startChar = '{', endChar = '}'): string =
  #It assumes startChar are not nested. If another startChar is found, it will count it but it will continue until it finds the endChar with the same nesting level.
  var level = 0 
  result = ""
  for c in content:
    if c == startChar: inc level
    elif c == endChar: dec level
    if level > 0: result.add(c)
    if level == 0 and c == endChar: break

  return result

func doesClassHaveConstructorInitializerOnly(content, clsName: string): bool =
  let ctorLines = content.splitLines().filterIt(clsName in it)
  #Notive assigments (default value) makes the ctor default
  let isFObjectInitilalizerCtor = ctorLines.mapIt(getContentBetween(it, '(', ')')).filterIt("FObjectInitializer" in it and "=" notin it and "<" notin it).len > 0 
  result = ctorLines.len == 1 and isFObjectInitilalizerCtor
  if result:
    debugEcho clsName, " has FObjectInitializer ctor"

proc getUClassesNamesFromHeaders(cppCode:string) : seq[CppTypeInfo] =   
  let lines = cppCode.splitLines()
  #Two cases (for UStructs and FStrucs) Need to do UEnums
  #1. via separating class ad hoc
  #2. Next line after UCLASS 
  #Probably there is something else nto matching. But this should cover most scenarios
  #At some point we are doing full AST parsing anyways. So this is just a temporary solution
  func getTypeSeparatingSemicolon(typ:string): seq[CppTypeInfo] = 
    var needToContains = [typ, ":" ] #only class that has a base
    for idx, line in enumerate(lines):   
      if needToContains.mapIt(line.contains(it)).foldl(a and b, true):
        let separator = if line.contains("final") : "final" else: ":"
        var clsName = line.split(separator)[0].strip.split(" ")[^1] 
        let clsContent = lines[idx..^1].join("\n").getContentBetween('{', '}')
        
        let needsObjectInitializerCtor = clsContent.doesClassHaveConstructorInitializerOnly(clsName)
        result.add(CppTypeInfo(name:clsName, cppDefinitionLine:line, needsObjectInitializerCtor:needsObjectInitializerCtor))

  func getTypeAfterUType(utype, typ:string) : seq[CppTypeInfo] = 
    for idx, line in enumerate(lines):  
      if line.contains(utype):
        if len(lines) > idx+1:
          let nextLine = lines[idx+1]
          if nextLine.contains(typ):
            let separator = if line.contains("final") : "final" else: ":"
            if nextLine.contains(separator):
              continue# captured above. This could cause picking a parent that is not defined
            var clsName = nextline.strip.split(" ")[^1]     
            result.add(CppTypeInfo(name:clsName, cppDefinitionLine:nextline))

  result = getTypeSeparatingSemicolon("class")
  result.add(getTypeSeparatingSemicolon("struct"))
  result.add(getTypeAfterUType("UCLASS", "class"))
  result.add(getTypeAfterUType("USTRUCT", "struct"))
  result.add(getTypeAfterUType("UEnum", "enum"))
  result = result.deduplicate()



proc getAllTypesFromHeader*(includePaths:seq[string], headerName:string) :  seq[CppTypeInfo] = 
  let header = readHeader(includePaths, headerName)
  result = header
    .map(getUClassesNamesFromHeaders)
    .get(newSeq[CppTypeInfo]())

#This try to parse types from the PCH but it's not reliable
#It's better to use both the PCH and this ones so PCH returns this too (works for a subset of types that doesnt have a header in the uprops)
#At some point we will parse the AST and retrieve the types from there.
var pchTypes {.compileTime.}  : Table[string, CppTypeInfo]
func getAllPCHTypes*(useCache:bool=true) : lent Table[string, CppTypeInfo] =   
  {.cast(noSideEffect).}:
    if pchTypes.len > 0:
      return pchTypes
    else: 
      #TODO cache it in the macro cache. This is only accessed at compile time
      #If the file gets too big it can be splited between structs, classes (and enums in the future)
      let dir = PluginDir/".headerdata"
      let filename =  "allpchtypes.json"
      let path = dir/filename
      if fileExists(path) and useCache:
        pchTypes = readFile(path).parseJson().to(Table[string, CppTypeInfo])#.pairs.toSeq().newTable()
      else:
        #we search them
        let searchPaths = getAllIncludePaths()
        let includes = getPCHIncludes(useCache=useCache)       
        pchTypes = 
          includes
            .mapIt(getAllTypesFromHeader(searchPaths, it))
            .flatten()
            .mapIt((it.name, it))
            .toTable()
            
        if useCache: #first time, store the types
          createDir(dir)
          writeFile(path, $pchTypes.toJson())

    result = pchTypes

        







