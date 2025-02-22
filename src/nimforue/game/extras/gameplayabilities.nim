include unrealprelude
 
import ../../unreal/bindings/imported/gameplayabilities/[abilities, gameplayabilities, enums]
export abilities, gameplayabilities, enums

type 
  IAbilitySystemInterface* {.importcpp.} = object
  IAbilitySystemInterfacePtr* = ptr IAbilitySystemInterface

proc getAbilitySystemGlobals*() : UAbilitySystemGlobals {.importcpp: "UAbilitySystemGlobals::Get()".}
proc initGlobalData*(globals:UAbilitySystemGlobals) {.importcpp: "#.InitGlobalData()".}
proc getBaseValue*(attrb: FGameplayAttributeData) : float32 {.importcpp: "#.GetBaseValue()".}
proc setBaseValue*(attrb: FGameplayAttributeData, newValue: float32 ) {.importcpp: "#.SetBaseValue(#)".}
proc getCurrentValue*(attrb: FGameplayAttributeData) : float32 {.importcpp: "#.GetCurrentValue()".}
proc setCurrentValue*(attrb: FGameplayAttributeData, newValue: float32 ) {.importcpp: "#.SetCurrentValue(#)".}
proc makeFGameplayAttributeData*(defaultValue: float32) : FGameplayAttributeData {.importcpp: "FGameplayAttributeData(#)", constructor.}

proc makeFGameplayAttribute*(prop: FPropertyPtr): FGameplayAttribute {.importcpp: "FGameplayAttribute(#)", constructor.}
proc getOwningAbilitySystemComponent*(attributeSet: UAttributeSetPtr): UAbilitySystemComponentPtr {.importcpp: "#->GetOwningAbilitySystemComponent()".}
proc setNumericAttributeBase*(asc: UAbilitySystemComponentPtr, attribute: FGameplayAttribute, value: float32) {.importcpp: "#->SetNumericAttributeBase(@)".}


proc initAbilityActorInfo*(asc:UAbilitySystemComponentPtr, actor: AActorPtr, avatar: AActorPtr) {.importcpp: "#->InitAbilityActorInfo(#, #)".}
proc getSpawnedAttributesMutable*(asc:UAbilitySystemComponentPtr): var TArray[UAttributeSetPtr] {.importcpp: "#->GetSpawnedAttributes_Mutable()".}

