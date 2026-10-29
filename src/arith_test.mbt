///|
fn adder(
  x : @propagator.Cell[Int32],
  y : @propagator.Cell[Int32],
  z : @propagator.Cell[Int32],
) -> Unit raise @propagator.MergeError {
  @propagator.Cell::lift2(fn(x, y) { x + y }, x, y, output=z)
  @propagator.Cell::lift2(fn(z, x) { z - x }, z, x, output=y)
  @propagator.Cell::lift2(fn(z, y) { z - y }, z, y, output=x)
}

///|
fn test_bidirct_add(x : Int32, y : Int32) -> Unit raise Error {
  let z = x + y
  // forward
  {
    let lhs_input = @propagator.Cell::default()
    let rhs_input = @propagator.Cell::default()
    let output = @propagator.Cell::default()
    adder(lhs_input, rhs_input, output)
    lhs_input.write(x)
    rhs_input.write(y)
    assert_eq(output.content().unwrap(), z)
  }
  // backward, get x
  {
    let lhs_input = @propagator.Cell::default()
    let rhs_input = @propagator.Cell::default()
    let output = @propagator.Cell::default()
    adder(lhs_input, rhs_input, output)
    output.write(z)
    rhs_input.write(y)
    assert_eq(lhs_input.content().unwrap(), x)
  }
  // backward, get y
  let lhs_input = @propagator.Cell::default()
  let rhs_input = @propagator.Cell::default()
  let output = @propagator.Cell::default()
  adder(lhs_input, rhs_input, output)
  output.write(z)
  rhs_input.write(x)
  assert_eq(lhs_input.content().unwrap(), y)
}

///|
test "forward add" {
  for x in 1..<100 {
    for y in 50..<100 {
      test_bidirct_add(x, y)
    }
  }
}
