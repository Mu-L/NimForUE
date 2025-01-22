import std/[strformat, macros, tables, options, typetraits, json, jsonutils, sequtils, strutils, genasts]
import ../utils/utils
when defined nuevm:
  import corevm
else:
  import ../unreal/coreuobject/nametypes
  import ../unreal/core/ftext
  import ../unreal/core/containers/[unrealstring, array]
type
  TableMap*[K, V] = seq[(K, V)]

  FieldKind* = enum
    Int, Bool, Float, String, Struct, Array, Map
  
  RuntimeField* = object
    case kind*: FieldKind
    of Int:
      intVal*: int
    of Bool:
      boolVal*: bool
    of Float:
      floatVal*: float
    of String:
      stringVal*: string
    of Struct:
      structVal*: RuntimeStruct
    of Array: #sets are also arrays
      arrayVal*: seq[RuntimeField]  
    of Map:
      mapVal*: seq[(RuntimeField, RuntimeField)]
    
  RuntimeStruct* = seq[(string, RuntimeField)]
 
  UEFunc* = object #Light metadata we could ue UFunc but we dont want to pull all those types into the vm
    name* : string
    className* : string
  
  UECallKind* = enum
    uecFunc, uecGetProp, uecSetProp
  
  UECall* = object
    self* : int
    value* : RuntimeField #On uebind [name] = value #let's just do runtimeFields only for now and then we can put an object in here, although a field may contain an object
    case kind* : UECallKind:
    of uecFunc:
      fn* : UEFunc    
    else:
      clsName*: string #TODO maybe I can just pass the clsPointer instead around
  
  UECallResult* = object
    value*: Option[RuntimeField]
    outParams*: RuntimeField = RuntimeField(kind: Struct)
          
  #should args be here too?
  UEBorrowInfo* = object
    fnName*: string #nimName 
    className* : string
    ueActualName* : string #in case it has Received or some other prefix
    isDelayed*: bool #only used for vmdefaultconstructor. When true means there is no native implementation yet as the class doesnt exist when calling setup borrow

func `==`*(self: RuntimeField, other: RuntimeField): bool = 
  if self.kind != other.kind: return false
  case self.kind:
  of Int:
    return self.intVal == other.intVal
  of Bool:
    return self.boolVal == other.boolVal
  of Float:
    return self.floatVal == other.floatVal
  of String:
    return self.stringVal == other.stringVal
  of Struct:
    return self.structVal == other.structVal
  of Array:
    return self.arrayVal == other.arrayVal
  of Map:
    return self.mapVal == other.mapVal
  else:
    return false

const VMDefaultConstructor* = "vmdefaultconstructor"
func isVMDefaultConstructor*(borrowInfo: UEBorrowInfo): bool = borrowInfo.fnName == borrowInfo.className & VMDefaultConstructor
func makeVMDefaultConstructorName*(className: string): string = className & VMDefaultConstructor

proc get*(self: UECallResult): lent RuntimeField {.inline.} = self.value.get()
proc get*(self:UECallResult, otherwise: RuntimeField): RuntimeField {.inline.} = self.value.get(otherwise)

func toJsonHook*(kind: FieldKind): JsonNode = 
  result = newJString($kind)

func toTableMap*[K, V](table: Table[K, V]): seq[(K, V)] =      
  for key, val in table:
    result.add((key, val))

func toTable*[K, V](tableMap: TableMap[K, V]): Table[K, V] =    
  for (key, val) in tableMap:
    result[key] = val
  
func getClassName*(ueCall: UECall): string = 
  case ueCall.kind:
  of uecFunc:
    return ueCall.fn.className
  else:
    return ueCall.clsName

# func toRuntimeField*[T](value : T) : RuntimeField 
func add*(rtField : var RuntimeField, name : string, value : RuntimeField) = 
  case rtField.kind:
  of Struct:
    rtField.structVal.add((name, value))  
  else:    
    safe:
      raise newException(ValueError, &"rtField is not a struct. It's {rtField.kind}. Trying to add name: {name} with value: {value} To {rtField}")

func add*(rtField : var RuntimeField, value: RuntimeField) = 
  case rtField.kind:
  of Array:
    rtField.arrayVal.add(value)
  else:
    safe:
      raise newException(ValueError, &"rtField is not an array. It's {rtField.kind}. Trying to add value: {value} To {rtField}")

func getInt*(rtField : RuntimeField) : int = 
  case rtField.kind:
  of Int:
    return rtField.intVal
  else:
    raise newException(ValueError, "rtField is not an int")

func getBool*(rtField : RuntimeField) : bool = 
  case rtField.kind:
  of Bool:
    return rtField.boolVal
  else:
    raise newException(ValueError, "rtField is not a bool")

func getFloat*(rtField : RuntimeField) : float =
  case rtField.kind:
  of Float:
    return rtField.floatVal
  else:
    raise newException(ValueError, "rtField is not a float")

func getStr*(rtField : RuntimeField) : string =
  case rtField.kind:
  of String:
    return rtField.stringVal
  else:
    raise newException(ValueError, "rtField is not a string")

func getStruct*(rtField : RuntimeField) : RuntimeStruct =
  case rtField.kind:
  of Struct:
    return rtField.structVal
  else:
    raise newException(ValueError, "rtField is not a struct")

func getArray*(rtField : RuntimeField) : seq[RuntimeField] =
  case rtField.kind:
  of Array:
    return rtField.arrayVal
  else:
    raise newException(ValueError, "rtField is not an array")

func getMap*(rtField : RuntimeField) : seq[(RuntimeField, RuntimeField)] =
  case rtField.kind:
  of Map:
    return rtField.mapVal
  else:
    raise newException(ValueError, "rtField is not a map")

func setInt*(rtField : var RuntimeField, value : int) = 
  case rtField.kind:
  of Int:
    rtField.intVal = value
  else:
    raise newException(ValueError, "rtField is not an int")

func setBool*(rtField : var RuntimeField, value : bool) =
  case rtField.kind:
  of Bool:
    rtField.boolVal = value
  else:
    raise newException(ValueError, "rtField is not a bool")

func setFloat*(rtField : var RuntimeField, value : float) =
  case rtField.kind:
  of Float:
    rtField.floatVal = value
  else:
    raise newException(ValueError, "rtField is not a float")

func setStr*(rtField : var RuntimeField, value : string) =
  case rtField.kind:
  of String:
    rtField.stringVal = value
  else:
    raise newException(ValueError, "rtField is not a string")

func setStruct*(rtField : var RuntimeField, value : RuntimeStruct) =
  case rtField.kind:
  of Struct:
    rtField.structVal = value
  else:
    raise newException(ValueError, "rtField is not a struct")

func setArray*(rtField : var RuntimeField, value : seq[RuntimeField]) =
  case rtField.kind:
  of Array:
    rtField.arrayVal = value
  else:
    raise newException(ValueError, "rtField is not an array")

func setMap*(rtField : var RuntimeField, value : seq[(RuntimeField, RuntimeField)]) =
  case rtField.kind:
  of Map:
    rtField.mapVal = value
  else:
    raise newException(ValueError, "rtField is not a map")

func getName*(strField: (string, RuntimeField)): string = strField[0]

func `[]`*(rtField : RuntimeField, name : string) : RuntimeField = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      if key == name.firstToLow():
        return value
    raise newException(ValueError, "Field " & name & " not found in struct")
  else:
    raise newException(ValueError, "rtField is not a struct")

func `[]`*(rtField : RuntimeField, idx : int) : RuntimeField = 
  case rtField.kind:
  of Array: #Support structs too? And what about the others only for 0?
    return rtField.arrayVal[idx]
  else:
    raise newException(ValueError, "rtField is not an array therefore not indexable ")

func contains*(rtField : RuntimeField, name : string) : bool = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      if key == name:
        return true
  else:
    raise newException(ValueError, "rtField is not a struct")


iterator items*(rtField : RuntimeField) : (string, RuntimeField) = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      yield (key, value)
  else:
    raise newException(ValueError, "rtField is not a struct")

func keys*(rtField : RuntimeField): seq[string] = 
  case rtField.kind:
  of Struct:
    return rtField.structVal.mapIt(it[0])
  else:
    raise newException(ValueError, "rtField is not a struct")

macro getField*(obj: object, fld: string): untyped =
  result = newDotExpr(obj, newIdentNode(fld.strVal))
  # echo repr result
macro getSetField*(obj: object, fld: string): untyped =
  result = newDotExpr(obj, newIdentNode("set" & fld.strVal.capitalizeAscii()))

macro setField*(obj: object, fld: static string, value: untyped): untyped =
  genAst(obj, fld = ident fld, setField = ident "set" & fld.capitalizeAscii(), value = value):
    when compiles(obj.setField):
      obj.setField(value)
    else:
      obj.fld = value

macro getterField*(obj: object, fld: static string): untyped =
  genAst(obj, fld = ident fld, getter = ident "get" & fld.capitalizeAscii()):
    when compiles(obj.getter):
      obj.getter
    else:
      obj.fld

type IntBased = int | int8 | int16 | int32 | int64 | uint | uint8 | uint16 | uint32 | uint64 | enum
# func toRuntimeFieldHook*[T](value : T) : RuntimeField = toRuntimeField*[T](value : T)
proc runtimeFieldTo*(rtField : RuntimeField, T : typedesc) : T 

proc fromRuntimeField*[T](value: var T, rtField: RuntimeField) = 
  when compiles(fromRuntimeFieldHook(value,rtField)): 
    fromRuntimeFieldHook(value, rtField)
  else:   
    case rtField.kind:
    of Int:
      when T is IntBased:        
        value = T(rtField.intVal)
      elif T is FName:
        value = nameFromInt(rtField.intVal)
      elif T is ptr:
        when defined nuevm:          
          value = if rtField.intVal == 0: nil else: cast[T](rtField.intVal)
          # castIntToPtr[T.pointerBase](rtField.intVal)         
        else:
          value = cast[T](rtField.intVal)        
    of Bool:
      when T is bool:
        value = T(rtField.boolVal)
    of Float:
      when T is float | float32 | float64:
        value = T(rtField.floatVal)  # a = cast[T](b.floatVal) #NO cast in the vm
    of String:
      when T is string | FString:
        value = rtField.stringVal
      elif T is FText:
        value = rtField.stringVal.toText()      
    of Struct:      
      when T is object | tuple:
        for fieldName, v in fieldPairs(value):     
          setField(value, fieldName, rtField[fieldName].runtimeFieldTo(typeof(v)))

    of Array:
      when T is seq | TArray:
        for i in 0 .. rtField.arrayVal.len:
          value.add(rtField.arrayVal[i].runtimeFieldTo(typeof(value[0])))

    of Map:
      when T is TableMap:
        type K = typeof(value[0][0])
        type V = typeof(value[0][1])                        
        for i in 0 ..< rtField.mapVal.len:
          let pair = rtField.mapVal[i]
          let key = pair[0].runtimeFieldTo(K)
          let val = pair[1].runtimeFieldTo(V)
          value.add((key, val))
      elif T is Table:
        fromRuntimeField(toTableMap(value), rtField)
          
        

proc runtimeFieldTo*(rtField : RuntimeField, T : typedesc) : T = 
  var obj = default(T)
  fromRuntimeField(obj, rtField)
  obj


proc toRuntimeField*(value: RuntimeField): RuntimeField = value
proc toRuntimeField*[T](value : T) : RuntimeField = 
  when compiles(toRuntimeFieldHook(value)): 
    return toRuntimeFieldHook(value)
  else:       
    when T is ptr or T is IntBased or T is FName:
      # UE_Log &"Int Value: {value}"
      result.kind = Int    
      result.intVal = when T is enum or T is FName: int(value) else: cast[int](value)    
    elif T is bool:
      result.kind = Bool
      result.boolVal = value
    elif T is float | float32 | float64:
      result.kind = Float
      result.floatVal = value
    elif T is string | FString:      
      result.kind = String
      result.stringVal = value
    elif T is FText:
      result.kind = String
      result.stringVal = value.textToFString()
    elif T is Table:
      toRuntimeField(toTableMap(value))
    elif T is TableMap:
      result.kind = Map
      for (key, val) in value:
        result.mapVal.add((toRuntimeField(key), toRuntimeField(val)))
    elif T is (seq | TArray):
      result.kind = Array
      for val in value:
        result.arrayVal.add(toRuntimeField(val))    
    elif T is (object | tuple):
      result.kind = Struct      
      for name, val in fieldPairs(value):
        when T is FTransform:
          #We prefer the getter if it exists (it scapes the protected fields in C++ and uses the getter)         
          result.structVal.add((name, toRuntimeField(getterField(value, name))))           
        else:          
          # UE_Log "Name: " & name & " Value: " & $val
          result.structVal.add((name, toRuntimeField(val)))
    else:
      when compiles(UE_Error "") and defined(typename):
        UE_Error &"Unsupported {typeName} type for RuntimeField "
      else:
        when defined(typeName):
          debugEcho &"ERROR: Unsupported {typeName} type for RuntimeField"
        else:
          debugEcho &"ERROR: Unsupported  type for RuntimeField"
      RuntimeField()    
    # raise newException(ValueError, &"Unsupported {typename} type for RuntimeField ")
    # UE_Log &"toRuntimeField {result}"

func initRuntimeField*[T](value : T) : RuntimeField = toRuntimeField(value)



