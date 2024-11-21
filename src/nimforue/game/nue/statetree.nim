
include unrealprelude
#TODO This will need to be changed to exported when deploying, review others extras
when WithEditor:
  import ../../unreal/bindings/imported/statetreemodule
  import ../../unreal/bindings/imported/statetreeeditormodule
else:
  import ../../unreal/bindings/exported/statetreemodule


when WithEditor:
  proc getPath*(state: UStateTreeStatePtr): FString {.importcpp: "#.GetPath()".}