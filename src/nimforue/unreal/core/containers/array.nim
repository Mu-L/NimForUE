include ../../definitions
import std/[sugar, enumerate]

type TArray*[out T] {.importcpp } = object

func num*[T](arr:TArray[T]): int32 {.importcpp: "#.Num()" noSideEffect}
proc removeAt*[T](arr: var TArray[T], idx:Natural) {.importcpp: "#.RemoveAt(#)".}
proc add*[T](arr:var TArray[T], value:T) {.importcpp: "#.Add(#)".}
proc addUnique*[T](arr:TArray[T], value:T) {.importcpp: "#.AddUnique(#)".}
proc append*[T](a, b:TArray[T]) {.importcpp: "#.Append(#)".}
func reserve*[T](arr:TArray[T], value:Natural) {.importcpp: "#.Reserve(#)".}
func indexOf*[T](arr:TArray[T], value:T): int32 {.importcpp: "#.IndexOfByKey(#)"}


# proc `[]`*[T](arr:TArray[T], i: int): var T {. inline, noSideEffect.} = arr[i.int32]

# proc `[]=`*[T](arr:TArray[T], i: int, val : T)  {. inline  .} = arr[i.int32] = val why this doesnt work like so?



func makeTArray*[T](): TArray[T] {.importcpp: "'0(@)", constructor.}
func makeTArray*[T](a:T, args:varargs[T]): TArray[T] =
  result = makeTArray[T]()
  result.reserve(args.len.int32 + 1)
  result.add a
  for arg in args:
    result.add arg


# proc makeTArray*[T](): TArray[T] {.importcpp: "'0(@)", constructor, nodecl.}

# proc makeTArray*[T](values:openarray[T]): TArray[T] {.importcpp: "'0({@})", constructor, nodecl.} #TODO

func getData*[T](arr:TArray[T]): ptr T {.importcpp: "#.GetData()", nodecl.}

func len*[T](arr:TArray[T]) : int32 {.inline.} = arr.num()

proc `[]`*[T](arr:TArray[T], i: Natural): var T {. importcpp: "#[#]",  noSideEffect.}
# proc `[]`*[T](arr:TArray[T], i: BackwardsIndex): var T = arr[arr.len - int(i)]
proc `[]=`*[T](arr:TArray[T], i: Natural, val : T)  {. importcpp: "#[#]=#",  }
# proc `[]=`*[T](arr:TArray[T], i: BackwardsIndex, val : T) = arr[arr.len - int(i)] = val


iterator items*[T](arr: TArray[T]): T =
  for i in 0..(arr.num()-1):
    yield arr[i.int32]

iterator mitems*[T](arr: TArray[T]): var T =
  for i in 0..(arr.num()-1):
    yield arr[i.int32]

proc map*[T, U](xs:TArray[T], fn : T -> U) : TArray[U] = 
  var arr = makeTArray[U]()
  arr.reserve(xs.num())
  for x in xs:
    arr.add(fn(x))
  arr

func filter*[T](xs:TArray[T], fn : proc(t:T): bool ) : TArray[T] =
  var arr = makeTArray[T]()
  arr.reserve(xs.num())
  {.cast(noSideEffect).}:
    for x in xs:
      if fn(x):
        arr.add x
  arr

func toSeq*[T](arr:TArray[T]) : seq[T] = 
  if arr.num() == 0:
    return @[]
  var xs = newSeqOfCap[T](arr.num())
  for x in arr:
    xs.add x
  xs

func contains*[T](arr:TArray[T], value:T): bool = 
  for x in arr:
    if x == value:
      return true
  false

func `$`*[T](arr:TArray[T]) : string = $toSeq(arr)
func `&`*[T](a, b:TArray[T]) : TArray[T] = 
  a.append(b)
  a

func toTArray*[T](arr:seq[T]) : TArray[T] = 
  var xs = makeTArray[T]()
  xs.reserve(arr.len().int32)
  for x in arr:
    xs.add x
  xs

proc removeBy*[T](arr: var TArray[T], fn: T -> bool) = 
  for idx, e in enumerate(arr):
    if fn(e):
      arr.removeAt idx
      break

proc remove*[T](arr: var TArray[T], value:T) = 
  for idx, e in enumerate(arr):
    if e == value:
      arr.removeAt idx
      break

proc flatten*[T](arr: TArray[TArray[T]]): TArray[T] = 
  var xs = makeTArray[T]()
  for x in arr:
    xs.append x
  xs

proc addUnique*[T](arr: var TArray[T], value:T) = 
  if value notin arr:
    arr.add value