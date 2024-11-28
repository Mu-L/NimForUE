import std/[strformat, macros, genasts]
#Misc types that lives inside core
import delegates

type FArchive* {.importcpp .} = object


proc makeFArchive*(): FArchive {.importcpp: "'0()", constructor.}

type
  FSimpleMulticastDelegate* = TMulticastDelegate
  EReloadCompleteReason* {.importcpp, size:sizeof(uint8).} = enum
    None, HotReloadAutomatic, HotReloadManual
  # FReloadCompleteDelegate* = TMulticastDelegateOneParam[EReloadCompleteReason]

let onAllModuleLoadingPhasesComplete* {.importcpp:"FCoreDelegates::OnAllModuleLoadingPhasesComplete", nodecl.}: FSimpleMulticastDelegate
let reloadCompleteDelegate* {.importcpp:"FCoreUObjectDelegates::ReloadCompleteDelegate", nodecl.}: TMulticastDelegateOneParam[EReloadCompleteReason]
let onPostEngineInit* {.importcpp:"FCoreDelegates::OnPostEngineInit", nodecl.}: FSimpleMulticastDelegate

proc `<<`*(ar: var FArchive, n: SomeNumber | bool) {.importcpp:"(#<<#)".}

macro checkf*(exp: untyped, msg: static string) =
  let str = newLit(&"checkf(#, TEXT(\"{exp.repr} - {msg}\"))")
  let f = genSym(nskProc, "checkf")
  genAst(exp, str, f):
    proc f(test :bool) {.importcpp: str.}
    f(exp)