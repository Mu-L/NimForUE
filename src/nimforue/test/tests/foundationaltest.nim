include unrealprelude
import ../testutils


uClass USampleObject of UObject:
  uprops:
    intValue: int

suite "Foundation tests":
  test "Should be able to create a UObject":
    let obj = newUObject[USampleObject]()
    obj.intValue = 5
    assert obj.intValue == 5

