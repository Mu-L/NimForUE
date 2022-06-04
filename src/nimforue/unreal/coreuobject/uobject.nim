
import ../Core/Containers/unrealstring

{.push header: "CoreUObject.h" .}

type 
    
    UObject* {.importcpp: "UObject", inheritable, pure .} = object #TODO Create a macro that takes the header path as parameter?
    UObjectPtr* = ptr UObject #This can be autogenerated by a macro

    UClass* {.importcpp: "UClass", inheritable, pure .} = object of UObject
    UClassPtr* = ptr UClass

    UFunction* {.importcpp: "UFunction", inheritable, pure .} = object
    UFunctionPtr* = ptr UFunction


proc newObject*(cls : UClassPtr) : UObjectPtr {.importcpp: "NewObject<UObject>(GetTransientPackage(), #)".}

proc getClass*(obj : UObjectPtr) : UClassPtr {. importcpp: "#->GetClass()" .}

proc getName*(obj : UObjectPtr) : FString {. importcpp:"#->GetName()" .}

{. pop .}
#CamelCase
#camelCase



