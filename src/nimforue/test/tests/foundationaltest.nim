include unrealprelude
import ../testutils


uClass USampleObject of UObject:
  (DisplayName = "Test")
  uprops(DisplayName = "TestInt", Category = "TestCategory"):
    intValue: int

uClass USampleColonMetadata of UObject:
  (DisplayName: "Test")
  uprops(DisplayName: "TestInt", Category: "TestCategory", EditAnywhere):
    intValue: int

  ufuncs(Static, Category: "Whatever"):
    proc testStaticFunc(): bool = true

uFunctions:
  (self: USampleColonMetadataPtr, BlueprintCallable, Static)
  proc detachedStaticFunc(): bool = true

suite "Foundation tests":

  test "Should be able to create a UObject":
    let obj = newUObject[USampleObject]()
    obj.intValue = 5
    assert obj.intValue == 5

  test "Should have the display name metadata up":
    let obj = newUObject[USampleObject]()

    assert obj.getClass().getMetadata("DisplayName").isSome()
    assert obj.getClass().getMetadata("DisplayName").get() == "Test"

  test "Should have the display name metadata for the property":
    let obj = newUObject[USampleObject]()
    let prop = obj.getClass().getFPropertyByName("intValue")

    assert prop.isNotNil()
    assert prop.getMetadata("DisplayName").isSome()
    assert prop.getMetadata("DisplayName").get() == "TestInt"
    assert prop.getMetadata("Category").isSome()
    assert prop.getMetadata("Category").get() == "TestCategory"

  test "Should have the display name metadata using colon syntax":
    let obj = newUObject[USampleColonMetadata]()

    assert obj.getClass().getMetadata("DisplayName").isSome()
    assert obj.getClass().getMetadata("DisplayName").get() == "Test"

  test "Should have all property metadata using colon syntax":
    let obj = newUObject[USampleColonMetadata]()
    let prop = obj.getClass().getFPropertyByName("intValue")

    assert prop.isNotNil()
    assert prop.getMetadata("DisplayName").isSome()
    assert prop.getMetadata("DisplayName").get() == "TestInt"
    assert prop.getMetadata("Category").isSome()
    assert prop.getMetadata("Category").get() == "TestCategory"
    assert CPF_Edit in prop.getPropertyFlags()
  
  test "Should be able to use static ufunctions":
    assert testStaticFunc()
  
  test "Should be able to use detached static ufunctions":
    assert detachedStaticFunc()
