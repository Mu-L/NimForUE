include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar, enumerate, tables, strutils, strformat, typetraits]
import runtimefield
import ../unreal/nimforue/nimforuebindings

proc makeUEFunc*(name, className : string) : UEFunc = 
  result.name = name
  result.className = className

proc makeUECall*(fn : UEFunc, self : int, value : RuntimeField) : UECall = 
  result.fn = fn
  result.self = self
  result.value = value 
  result.kind = uecFunc

proc makeUECall*(fn : UEFunc, self : UObjectPtr, value : RuntimeField) : UECall = 
  result.fn = fn
  result.self = cast[int](self)
  result.value = value
  result.kind = uecFunc

proc getProp*(prop:FPropertyPtr, sourceAddr:pointer) : RuntimeField
proc setProp*(rtField : RuntimeField, prop : FPropertyPtr, memoryBlock:pointer)
proc setStructProp*(rtField : RuntimeField, prop : FPropertyPtr, memoryBlock:pointer): pointer =
  assert rtField.kind == Struct, "Only structs can be set as structs got " & $rtField.kind
  let structProp = castField[FStructProperty](prop)
  let scriptStruct = structProp.getScriptStruct()
  let structProps = scriptStruct.getFPropsFromUStruct() #Lets just do this here before making it recursive
  var structMemoryRegion = memoryBlock
  for (name, val) in rtField:
    for prop in structProps:
      if name in [prop.getName(), prop.getName.firstToLow()]:
        if val.kind in [Struct]: 
          structMemoryRegion = cast[pointer](cast[uint](structMemoryRegion) + prop.getOffset().uint)
        val.setProp(prop, structMemoryRegion)

  structMemoryRegion

proc setProp*(rtField: RuntimeField, prop: FPropertyPtr, memoryBlock: pointer) =
  case rtField.kind
  of Int:    
    if prop.isFName():
      setPropertyValue[FName](prop, memoryBlock, nameFromInt(rtField.intVal))
    else:
      setPropertyValue(prop, memoryBlock, rtField.getInt)
  of Bool:
    setPropertyValue(prop, memoryBlock, rtField.getBool)
  of Float:
    if prop.isFloat32():
      setPropertyValue(prop, memoryBlock, rtField.getFloat.float32)
    else:
      setPropertyValue(prop, memoryBlock, rtField.getFloat)
  of String:
    if prop.isFString():
      setPropertyValue(prop, memoryBlock, makeFString rtField.getStr)
    elif prop.isFText():
      setPropertyValue(prop, memoryBlock, rtField.getStr.toText())
    else:
      UE_Error &"Unknown string type {prop.getCppType()}"
      raise newException(ValueError, &"Unknown string type {prop.getCppType()}")
  of Struct:
    discard setStructProp(rtField, prop, memoryBlock)
  of Array:
    if prop.isTArray(): 
      let rtArray = rtField.getArray()
      let arrayProp = castField[FArrayProperty](prop)
      let innerProp = arrayProp.getInnerProp()
      let arrayHelper = makeScriptArrayHelperInContainer(arrayProp, memoryBlock)
      arrayHelper.emptyAndAddUninitializedValues(rtArray.len.int32)
      log &"Setting array {rtArray.len}"
      for idx, elem in enumerate(rtArray):
        setProp(elem, innerProp, arrayHelper.getRawPtr(idx.int32))

      # arrayHelper.emptyAndAddUninitializedValues(rtField.getArray().len.int32)
      # for idx, elem in enumerate(rtField.getArray()):
      #   setProp(elem, innerProp, arrayHelper.getRawPtr(idx.int32))

    elif prop.isTSet():
      let setProp = castField[FSetProperty](prop)
      let elementProp = setProp.getElementProp()
      let setHelper = makeScriptSetHelper(setProp, memoryBlock)
      setHelper.emptyElements()
      for idx, elem in enumerate(rtField.getArray()):
        setHelper.addUninitializedValue()
        setProp(elem, elementProp, setProp.getElementPtr(memoryBlock, idx.int32))
      setHelper.rehash()
    else:
      UE_Error &"Unknown array type {prop.getCppType()}"
      raise newException(ValueError, &"Unknown array type {prop.getCppType()}")
  of Map:
    let mapProp = castField[FMapProperty](prop)
    let kProp = mapProp.getKeyProp()
    let vProp = mapProp.getValueProp()
    let helper = makeScriptMapHelperInContainer(mapProp, memoryBlock)

    helper.emptyValues(rtField.getMap().len.int32)# the size is actually the elements not the bytes
    for idx, (key, value) in enumerate(rtField.getMap()):
      helper.addDefaultValue_Invalid_NeedsRehash()    
      setProp(key, kProp, helper.getKeyPtr(idx.int32))
      case value.kind:
        of Int:
          vProp.copySingleValue(helper.getValuePtr(idx.int32), value.intVal.addr)
        of String:          
          var fstring = f value.stringVal
          vProp.copySingleValue(helper.getValuePtr(idx.int32), fstring.addr)
        of Bool:
          vProp.copySingleValue(helper.getValuePtr(idx.int32), value.boolVal.addr)
        of Struct:           
            let structMemoryRegion = setStructProp(value, vProp, helper.getValuePtr(idx.int32))
            vProp.copySingleValue(helper.getValuePtr(idx.int32), structMemoryRegion)
        else:
          setProp(key, vProp, helper.getValuePtr(idx.int32))      
    helper.rehash()


proc getProp*(prop:FPropertyPtr, sourceAddr:pointer) : RuntimeField = 
  proc sourceAddrWithOffset() : pointer = cast[pointer](cast[uint](sourceAddr) + prop.getOffset().uint)
  if prop.isInt() or prop.isObjectBased() or prop.isEnum() or 
    prop.isFName() or
    prop.isByte() or prop.getCppType().contains("TWeakObjectPtr"): #TODO improve this last one   
    result.kind = Int        
    if prop.isEnum():
      result.intVal = getPropertyValuePtr[uint8](prop, sourceAddr)[].int
    else:
      copyMem(addr result.intVal, sourceAddrWithOffset(), prop.getSize())

  elif prop.isBool():
    result.kind = Bool
    copyMem(addr result.boolVal, sourceAddrWithOffset(), prop.getSize())
  elif prop.isFString():
    result.kind = String  
    var sourceAddr = cast[pointer](cast[int](sourceAddr))  
    result.stringVal = getPropertyValuePtr[FString](prop, sourceAddr)[]   
  elif prop.isFText():
    result.kind = String
    var sourceAddr = cast[pointer](cast[int](sourceAddr))  
    result.stringVal = getPropertyValuePtr[FText](prop, sourceAddr)[].toFString() 
  elif prop.isFloat():
    result.kind = Float
    copyMem(addr result.floatVal, sourceAddrWithOffset(), prop.getSize())
  elif prop.isStruct():
    if prop.getCppType() == "FHitResult":
      return  getPropertyValuePtr[FHitResult](prop, sourceAddr)[].toRuntimeField() #TODO generalize this. 
    let structProp = castField[FStructProperty](prop)
    let scriptStruct = structProp.getScriptStruct()
    let structProps = scriptStruct.getFPropsFromUStruct()
    result = RuntimeField(kind:Struct)
    for paramProp in structProps:      
      let name = paramProp.getName().firstToLow() #So when we parse the type in the vm it matches      
      let value = getProp(paramProp, sourceAddrWithOffset())
      result.structVal.add((name, value))
  elif prop.isTArray():
    let arrayProp = castField[FArrayProperty](prop)
    let innerProp = arrayProp.getInnerProp()
    let arrayHelper = makeScriptArrayHelperInContainer(arrayProp, sourceAddrWithOffset())
    result = RuntimeField(kind:Array)
    for idx in 0 ..< arrayHelper.num():
      result.arrayVal.add(getProp(innerProp, arrayHelper.getRawPtr(idx.int32)))
  elif prop.isTSet():
    let setAddr = sourceAddrWithOffset()
    let setProp = castField[FSetProperty](prop)
    let elementProp = setProp.getElementProp()
    result = RuntimeField(kind:Array)
    for idx in 0 ..< setProp.getNum(setAddr):
      result.arrayVal.add(getProp(elementProp, setProp.getElementPtr(setAddr, idx)))
  elif prop.isTMap():
    let mapProp = castField[FMapProperty](prop)
    let keyProp = mapProp.getKeyProp()
    let valueProp = mapProp.getValueProp()
    let mapHelper = makeScriptMapHelperInContainer(mapProp, sourceAddrWithOffset())
    result = RuntimeField(kind:Map)  
    for idx in 0 ..< mapHelper.num():
      let key = getProp(keyProp, mapHelper.getKeyPtr(idx.int32))
      let value = getProp(valueProp, mapHelper.getValuePtr(idx.int32))
      result.mapVal.add((key, value))
  else:
    UE_Error &"Unknown property type: {prop.getName()} of Cpp type: {prop.getCppType()}"
    raise newException(ValueError, &"Unknown property type: {prop.getName()} {prop.getCppType()}")
   
func isStatic*(fn : UFunctionPtr) : bool = FUNC_Static in fn.functionFlags

proc uCallFn*(call: UECall, cls: UClassPtr): UECallResult =
  let fn = cls.findFunctionByNameWithPrefixes(call.fn.name.capitalizeAscii()).get(nil)
  if fn.isNil():
    UE_Error "uCall: Function " & $call.fn.name & " not found in class " & $call.fn.className
    return result
  let self = 
    if fn.isStatic():
      getDefaultObjectFromClassName(call.fn.className.removeFirstLetter())
    else:
      cast[UObjectPtr](call.self)

  let propParams = fn.getFPropsFromUStruct().filterIt(it != fn.getReturnProperty())
  if propParams.any() or fn.doesReturn():
    var memoryBlock = alloc0(fn.parmsSize)
    let memoryBlockAddr = cast[uint](memoryBlock)    
    #TODO check return param and out params
    for paramProp in propParams:
      try:
        # UE_Log "Param prop name: " & $paramProp.getName() & " type: " & paramProp.getCppType()
        let propName = paramProp.getName().firstToLow() #So when we parse the type in the vm it matches (should we tried both?)
        if propName notin call.value:
          UE_Warn "Param " & $propName & " not in call value"
          continue
      
        let rtField = call.value[propName]
        rtField.setProp(paramProp, memoryBlock)

      except:
        UE_Error "Error setting the value in  " & $paramProp.getName()  & " for " & $fn.getName()
        UE_Error getCurrentExceptionMsg()
        UE_Error getStackTrace()    


    self.processEvent(fn, memoryBlock)

    if fn.doesReturn():
      let returnProp = fn.getReturnProperty()
      let returnRuntimeField = getProp(returnProp, cast[pointer](memoryBlockAddr))
      result = UECallResult(value: some(returnRuntimeField))
    result.outParams = RuntimeField(kind:Struct)
    #set the out params
    for outProp in propParams.filter(isOutParam):
      try:      
        result.outParams.add(outProp.getName().firstToLow(), getProp(outProp, memoryBlock))     
      except CatchableError:
        UE_Error "Error getting the value in  " & $outProp.getName()  & " for " & $fn.getName()
        UE_Error getCurrentExceptionMsg()
        UE_Error getStackTrace()
    
    dealloc(memoryBlock)    
  else: #no params no return
    self.processEvent(fn, nil)

proc uCallProp*(call : UECall, cls:UClassPtr) : Option[RuntimeField] = 
  assert call.kind == uecGetProp or call.kind == uecSetProp
  let argField = call.value
  let propName = argField.getStruct()[0].getName()
  let prop = cls.getFPropertyByName(propName)  
  if prop.isNil():
    UE_Error &"uCall: Property {propName} not found in class {cls.getName()}"
    return none(RuntimeField)    
  let selfAddr = cast[uint](call.self)
  if call.kind == uecGetProp:        
    some getProp(prop,  cast[pointer](selfAddr))        
  else:
    #Dont ask why but we need to add the offset of the array    
    let offset = if argField[propName].kind in {Struct, Array, Map}: prop.getOffset() else: 0   
    argField[propName].setProp(prop, cast[pointer](selfAddr + offset.uint))
    none(RuntimeField)

proc uCall*(call : UECall) : UECallResult = 
  let className = call.clsName  
  var cls = getClassByName(className)
  if cls.isNil():
    cls = getClassByName(className.removeFirstLetter()) 
    if cls.isNil():
      UE_Error "uCall: Class " & $call.getClassName() & " not found"
      return UECallResult()
  case call.kind:
  of uecFunc: uCallFn(call, cls)
  else: UECallResult(value:uCallProp(call, cls))


