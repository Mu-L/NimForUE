include ../unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../../codegen/[codegentemplate,genreflectiondata]
import ../macros/genmodule #not sure if it's worth to process this file just for one function? 

proc NimMain() {.importc.} 

#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    delTypeName : FString = "test5"
    structPtrName : FString 
    moduleName : FString
    bOnlyBlueprint : bool 
    actorToInspect : AActorPtr

  ufuncs(BlueprintCallable, CallInEditor, Category=ActorCodegen):
    proc genReflectionDataOnly() = 
      try:
        let ueProject =  genReflectionData(getAllInstalledPlugins(getNimForUEConfig()))
       
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"
    
    proc genReflectionDataAndBindings() = 
      try:
        execBindingsGenerationInAnotherThread()
       
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"
   
    proc showType() = 
      let obj = getUTypeByName[UDelegateFunction]("UMG.ComboBoxKey:OnOpeningEvent"&DelegateFuncSuffix)
      let obj2 = getUTypeByName[UDelegateFunction]("OnOpeningEvent"&DelegateFuncSuffix)
      UE_Warn $obj
      UE_Warn $obj2
      UE_Warn $obj2

    proc showTypeModule() = 
      let obj = getUTypeByName[UField]("EFieldVectorType")

      UE_Log $obj
      if not obj.isNil():
        UE_Log $obj.getModuleName()

    proc searchDelByName() = 
      let obj = getUTypeByName[UDelegateFunction](self.delTypeName&DelegateFuncSuffix)
      if obj.isNil(): 
        UE_Error &"Error del is null. Provide a type name"
        return

      UE_Warn $obj
      UE_Warn $obj.getOuter()
    
    proc runFnInAnotherThread() = 
      proc ffiWraper(msg:int) {.cdecl.} = 
        # NimMain()   
        # UE_Log "Hello from another thread" & $msg #This cashes
        # let s = "test string"
        UE_Log "Hello from another thread" 
     
      executeTaskInTaskGraph(2, ffiWraper)   

    
    proc showUEModule() = 
      let pkg = tryGetPackageByName(self.moduleName)
      let rules = 
        if self.bOnlyBlueprint:  
          @[makeImportedRuleModule(uerImportBlueprintOnly)]
        else: 
          @[]

      let modules = pkg.map((pkg:UPackagePtr) => pkg.toUEModule(rules, @[], @[])).get(@[])
      UE_Log $modules.head().map(x=>x.types.mapIt(it.name))
      UE_Log "Len " & $modules.len
      UE_Log "Types " & $modules.head().map(x=>x.types).get(@[]).len
    
    proc showClassPropsForSelectedActor() = 
      if self.actorToInspect.isNil():
        UE_Error "Actor is null"
        return
      let obj = self.actorToInspect.getClass()
      let props = obj.getFPropsFromUStruct()
      for p in props:
        UE_Log $p
      
    proc showClassFuncsForSelectedActor() = 
      if self.actorToInspect.isNil():
        UE_Error "Actor is null"
        return
      let obj = self.actorToInspect.getClass()
      let funcs = obj.getFuncsFromClass()
      for f in funcs:
        UE_Log $f
      
