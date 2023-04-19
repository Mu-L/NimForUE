
import std/[os, strformat, strutils, sequtils]
import buildcommon, buildscripts, nimforueconfig



#[
  The structure of a UE plugin is as follows:
  - PluginName
    - PluginName.uplugin
    - Source
      #Module Structure#
      - ModuleNameFolder
        - Private
          - NimGenerateCodeFolder
            - *.nim.cpp
          - ModuleName.cpp          
        - Public
          - ModuleName.h  
        - ModuleName.Build.cs

]#


const UPluginTemplate = """
{
  "FileVersion": 3,
  "FriendlyName": "$1",
  "Version": 1,
  "VersionName": "1.0",
  "CreatedBy": "NimForUE",
  "EnabledByDefault" : true,
	"CanContainContent" : false,
	"IsBetaVersion" : false,
	"Installed" : false,
	"Modules" :
	[
$2
	]
} 
    
"""
const ModuleTemplateForUPlugin = """
    {
      "Name" : "$1",
      "Type" : "Runtime",
      "LoadingPhase" : "PostDefault",
      "AdditionalDependencies" : []
    }"""


#TODO at some point pase modules to link dinamically here too from game.json. 
const ModuleBuildcsTemplate = """
using System.IO;
using UnrealBuildTool;
 
public class $1 : ModuleRules
{
	public $1(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"InputCore", 
			"Slate", 
			"SlateCore",
			"Engine", 
			"NimForUEBindings",
			"EnhancedInput", 
			"GameplayTags",
			"PCG",
			"GameplayAbilities",
			"PhysicsCore",
			"UnrealEd",
			//"NimForUE", //DUE To reinstance bindigns. So editor only
			
		});
		PrivateDependencyModuleNames.AddRange(new string[] {  });
	
		PublicDefinitions.Add("NIM_INTBITS=64");
		if (Target.Platform == UnrealTargetPlatform.Win64){
			CppStandard = CppStandardVersion.Cpp20;
		} else {
			CppStandard = CppStandardVersion.Cpp17;
		}
		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		var nimHeadersPath = Path.Combine($2, "NimHeaders");
    PrivatePCHHeaderFile =  Path.Combine(nimHeadersPath, "nimgame.h");

		PublicIncludePaths.Add(nimHeadersPath);
		bUseUnity = false;
	}
}
"""

const ModuleHFileTemplate = """
#pragma once

#include "Modules/ModuleManager.h"

DECLARE_LOG_CATEGORY_EXTERN($1, All, All);

class F$1 : public IModuleInterface
{
	public:

	/* Called when the module is loaded */
	virtual void StartupModule() override;

	/* Called when the module is unloaded */
	virtual void ShutdownModule() override;
};

"""

const ModuleCppFileTemplate = """
#include "../Public/$1.h"
#include "CoreUObject/Public/UObject/UObjectGlobals.h"
DEFINE_LOG_CATEGORY($1);

#define LOCTEXT_NAMESPACE "FGameCorelibEditor"
#define $1 1

constexpr char NUEModule[] = "some_module";
extern  "C" void startNue(uint8 calledFrom);


#if WITH_EDITOR

extern  "C" void* getGlobalEmitterPtr();
extern  "C" void reinstanceFromGloabalEmitter(void* globalEmitter);
#endif

void GameNimMain();
void StartNue() {
#if WITH_EDITOR
  FCoreUObjectDelegates::ReloadCompleteDelegate.AddLambda([&](EReloadCompleteReason Reason) {
  UE_LOG(LogTemp, Log, TEXT("Reinstancing Lib"))
    GameNimMain();
    reinstanceFromGloabalEmitter(getGlobalEmitterPtr());
  });
#endif
  GameNimMain();
  startNue(1);
  // #endif
}



void F$1::StartupModule()
{
	  StartNue();
}

void F$1::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(F$1, $1)
"""


proc getPluginTemplateFile(name:string, modules:seq[string]) : string =
  let modulesStr = modules.mapIt(ModuleTemplateForUPlugin.format(it)).join(",\n")
  UPluginTemplate.format(name, modulesStr)

proc getModuleBuildCsFile(name:string) : string =
  #Probably bindings needs a different one
  ModuleBuildcsTemplate.format(name, escape(PluginDir))

proc getModuleHFile(name:string) : string =
  ModuleHFileTemplate.format(name)
proc getModuleCppFile(name:string) : string =
  ModuleCppFileTemplate.format(name)




#begin cpp

proc copyCppFilesToModule(cppSrcDir, nimGeneratedCodeDir:string) = 
  #TODO generate a map of what exists and what not so we can detect removals.
  #Notice we need to copy the bindings too. Maybe we can infer somehow only what needs to be copied. 
  #It doesnt really matter though since on the final build they will be optimized out but it may saved us 
  #some seconds on the first build.
  proc copyBindings() = 
    var bindingsSrcDir = PluginDir / ".nimcache/gencppbindings"
    for cppFile in walkFiles(bindingsSrcDir / &"*.cpp"):
      let filename = cppFile.extractFilename()
      if filename.contains("sbindings@sexported"):# and not (filename.contains("unrealed") or filename.contains("umgeditor")):  Should handle this in a better way TOOD
        let pathDst = nimGeneratedCodeDir / filename
        if not fileExists pathDst:
          copyFile(cppFile, pathDst)

  copyBindings()
  for cppFile in walkFiles(cppSrcDir / &"*.cpp"):    
    let filename = cppFile.extractFilename()   
    let pathDst = nimGeneratedCodeDir / filename
    if fileExists(pathDst) and readFile(cppFile) == readFile(pathDst):
      continue
    else:
      log "Will compile " & pathDst
      copyFile(cppFile, pathDst)        
  
  
    

proc generateModule(name, sourceDir:string) = 
  let moduleDir = sourceDir / name
  let privateDir = moduleDir / "Private"
  let publicDir = moduleDir / "Public"
  let nimGeneratedCodeDir = privateDir / "NimGeneratedCode"
  let moduleCppFile = privateDir / (name & ".cpp")
  let moduleHFile = publicDir / (name & ".h")
  let moduleBuildCsFile = moduleDir / (name & ".Build.cs")

  createDir(moduleDir)
  createDir(privateDir)
  createDir(publicDir)
  createDir(nimGeneratedCodeDir)
  writeFile(moduleCppFile, getModuleCppFile(name))
  writeFile(moduleHFile, getModuleHFile(name))
  writeFile(moduleBuildCsFile, getModuleBuildCsFile(name))

  var cppSrcDir : string 
  if name == "Bindings":
    cppSrcDir = PluginDir / ".nimcache/gencppbindings"
  else:
    # cppSrcDir = PluginDir / &".nimcache/{name}/release"
    cppSrcDir = PluginDir / &".nimcache/nimforuegame/release"
  copyCppFilesToModule(cppSrcDir, nimGeneratedCodeDir)
 #this is a param 




proc generatePlugin*(name:string) =
  let uePluginDir = parentDir(PluginDir)
  let genPluginDir = uePluginDir / name
  let genPluginSourceDir = genPluginDir / "Source"
  let upluginFilePath = genPluginDir / (name & ".uplugin")
  let modules = @["Game"] 

  createDir(genPluginDir)
  createDir(genPluginSourceDir)
  writeFile(upluginFilePath, getPluginTemplateFile(name, modules))
  for module in modules:
    generateModule(module, genPluginSourceDir)





#[Steps
1.[x] Do the missing cpp file
2. Toggle the module in the project file (not sure if it makes sense since it's autocompiled. Will try to make all scenarios to compile)
3. [x] At this point ubuild should work and compile the plugin
4. Compile bindings into the project.
5. At this point uebuild should work and compile the plugin
6. Compile the game


]#