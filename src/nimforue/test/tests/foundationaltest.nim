include unrealprelude
import ../testutils


uClass USampleObject of UObject:
  (DisplayName = "Test")
  uprops(DisplayName = "TestInt"):
    intValue: int

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
  
