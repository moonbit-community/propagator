///|
enum Interval {
  Empty
  Interval(lo~ : Double, hi~ : Double)
}

///|
#callsite(autofill(loc))
fn Interval::new(lo~ : Double, hi~ : Double, loc~ : SourceLoc) -> Interval {
  guard lo < hi else { abort("lower limit = \{lo}, upper limit =\{hi}", loc~) }
  Interval(lo~, hi~)
}

///|
fn interval_from_candidates(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
) -> Interval {
  Interval::new(
    lo=Double::min(Double::min(a, b), Double::min(c, d)),
    hi=Double::max(Double::max(a, b), Double::max(c, d)),
  )
}

///|
fn interval_all() -> Interval {
  Interval::new(lo=@double.neg_infinity, hi=@double.infinity)
}

///|
impl Propagated for Interval with merge(self, other) {
  match (self, other) {
    (Interval(_) as l, Interval(_) as r) =>
      if l.hi <= r.lo || r.hi <= l.lo {
        Change::Change(true, Empty)
      } else {
        Change::Change(
          l.lo < r.lo || l.hi > r.hi,
          Interval::new(lo=Double::max(l.lo, r.lo), hi=Double::min(l.hi, r.hi)),
        )
      }
    (Empty, _) => Change(false, Empty)
    (_, Empty) => Change(true, Empty)
  }
}

///|
impl Mul for Interval with mul(lhs, rhs) {
  if lhs is Interval(lo=lhs_lo, hi=lhs_hi) &&
    rhs is Interval(lo=rhs_lo, hi=rhs_hi) {
    interval_from_candidates(
      lhs_lo * rhs_lo,
      lhs_lo * rhs_hi,
      lhs_hi * rhs_lo,
      lhs_hi * rhs_hi,
    )
  } else {
    Empty
  }
}

///|
impl Add for Interval with add(lhs, rhs) {
  if lhs is Interval(lo=lhs_lo, hi=lhs_hi) &&
    rhs is Interval(lo=rhs_lo, hi=rhs_hi) {
    Interval::new(lo=lhs_lo + rhs_lo, hi=lhs_hi + rhs_hi)
  } else {
    Empty
  }
}

///|
impl Sub for Interval with sub(minuend, subtrahend) {
  if minuend is Interval(lo=minuend_lo, hi=minuend_hi) &&
    subtrahend is Interval(lo=subtrahend_lo, hi=subtrahend_hi) {
    Interval::new(lo=minuend_lo - subtrahend_hi, hi=minuend_hi - subtrahend_lo)
  } else {
    Empty
  }
}

///|
impl Div for Interval with div(dividend, divisor) {
  if dividend is Interval(lo=dividend_lo, hi=dividend_hi) &&
    divisor is Interval(lo=divisor_lo, hi=divisor_hi) {
    if divisor_lo < 0.0 && divisor_hi > 0.0 {
      interval_all()
    } else if divisor_lo == 0.0 {
      if dividend_hi <= 0.0 {
        Interval::new(lo=@double.neg_infinity, hi=dividend_hi / divisor_hi)
      } else if dividend_lo >= 0.0 {
        Interval::new(lo=dividend_lo / divisor_hi, hi=@double.infinity)
      } else {
        interval_all()
      }
    } else if divisor_hi == 0.0 {
      if dividend_hi <= 0.0 {
        Interval::new(lo=dividend_hi / divisor_lo, hi=@double.infinity)
      } else if dividend_lo >= 0.0 {
        Interval::new(lo=@double.neg_infinity, hi=dividend_lo / divisor_lo)
      } else {
        interval_all()
      }
    } else {
      interval_from_candidates(
        dividend_lo / divisor_lo,
        dividend_lo / divisor_hi,
        dividend_hi / divisor_lo,
        dividend_hi / divisor_hi,
      )
    }
  } else {
    Empty
  }
}

///|
fn Interval::sqrt(self : Interval) -> Interval {
  match self {
    Empty => Empty
    Interval(lo~, hi~) =>
      if hi <= 0.0 {
        Empty
      } else if lo >= 0.0 {
        Interval::new(lo=lo.sqrt(), hi=hi.sqrt())
      } else {
        Interval::new(lo=0.0, hi=hi.sqrt())
      }
  }
}

///|
fn Interval::square(self : Interval) -> Interval {
  match self {
    Empty => Empty
    Interval(lo~, hi~) =>
      if hi <= 0.0 {
        Interval::new(lo=hi * hi, hi=lo * lo)
      } else if lo >= 0.0 {
        Interval::new(lo=lo * lo, hi=hi * hi)
      } else {
        Interval::new(lo=0.0, hi=Double::max(lo * lo, hi * hi))
      }
  }
}

///|
fn Interval::square_preimage(self : Interval) -> Interval {
  match self {
    Empty => Empty
    Interval(lo=_, hi~) =>
      if hi <= 0.0 {
        Empty
      } else {
        let bound = hi.sqrt()
        Interval::new(lo=-bound, hi=bound)
      }
  }
}

///|
fn squarer(x : Cell[Interval], y : Cell[Interval]) -> Unit raise MergeError {
  Cell::lift(fn(x : Interval) { x.square() }, x, output=y)
  Cell::lift(fn(y : Interval) { y.square_preimage() }, y, output=x)
}

///|
fn sqrter(x : Cell[Interval], y : Cell[Interval]) -> Unit raise MergeError {
  Cell::lift(fn(x : Interval) { x.sqrt() }, x, output=y)
  Cell::lift(fn(y : Interval) { y.square() }, y, output=x)
}

///|
#callsite(autofill(loc))
fn assert_double_eq(
  actual : Double,
  expected : Double,
  loc~ : SourceLoc,
) -> Unit {
  let same = if actual.is_inf() || expected.is_inf() {
    actual == expected
  } else {
    actual.is_close(expected, absolute_tolerance=0.000_000_001)
  }
  guard same else { abort("expected \{expected}, got \{actual}", loc~) }
}

///|
#callsite(autofill(loc))
fn assert_interval_eq(
  actual : Interval,
  expected : Interval,
  loc~ : SourceLoc,
) -> Unit {
  match (actual, expected) {
    (Empty, Empty) => ()
    (
      Interval(lo=actual_lo, hi=actual_hi),
      Interval(lo=expected_lo, hi=expected_hi),
    ) => {
      assert_double_eq(actual_lo, expected_lo, loc~)
      assert_double_eq(actual_hi, expected_hi, loc~)
    }
    _ => abort("interval mismatch", loc~)
  }
}

///|
test "interval add/sub/mul/div" {
  let lhs = Interval::new(lo=1.0, hi=3.0)
  let rhs = Interval::new(lo=2.0, hi=4.0)
  assert_interval_eq(lhs + rhs, Interval::new(lo=3.0, hi=7.0))
  assert_interval_eq(lhs - rhs, Interval::new(lo=-3.0, hi=1.0))
  assert_interval_eq(
    Interval::new(lo=-2.0, hi=3.0) * Interval::new(lo=4.0, hi=5.0),
    Interval::new(lo=-10.0, hi=15.0),
  )
  assert_interval_eq(
    Interval::new(lo=2.0, hi=4.0) / Interval::new(lo=1.0, hi=2.0),
    Interval::new(lo=1.0, hi=4.0),
  )
}

///|
test "interval merge narrows by intersection" {
  match
    Propagated::merge(
      Interval::new(lo=1.0, hi=5.0),
      Interval::new(lo=2.0, hi=3.0),
    ) {
    Change(changed, interval) => {
      assert_eq(changed, true)
      assert_interval_eq(interval, Interval::new(lo=2.0, hi=3.0))
    }
    Contradiction(_) => abort("unexpected contradiction")
  }
  match
    Propagated::merge(
      Interval::new(lo=1.0, hi=2.0),
      Interval::new(lo=2.0, hi=3.0),
    ) {
    Change(changed, interval) => {
      assert_eq(changed, true)
      assert_interval_eq(interval, Empty)
    }
    Contradiction(_) => abort("unexpected contradiction")
  }
}

///|
test "interval division near zero" {
  assert_interval_eq(
    Interval::new(lo=1.0, hi=2.0) / Interval::new(lo=0.0, hi=3.0),
    Interval::new(lo=1.0 / 3.0, hi=@double.infinity),
  )
  assert_interval_eq(
    Interval::new(lo=1.0, hi=2.0) / Interval::new(lo=-1.0, hi=3.0),
    interval_all(),
  )
  assert_interval_eq(Empty / Interval::new(lo=1.0, hi=2.0), Empty)
}

///|
test "interval sqrt and square" {
  assert_interval_eq(
    Interval::new(lo=4.0, hi=9.0).sqrt(),
    Interval::new(lo=2.0, hi=3.0),
  )
  assert_interval_eq(
    Interval::new(lo=-1.0, hi=9.0).sqrt(),
    Interval::new(lo=0.0, hi=3.0),
  )
  assert_interval_eq(
    Interval::new(lo=-3.0, hi=-2.0).square(),
    Interval::new(lo=4.0, hi=9.0),
  )
  assert_interval_eq(
    Interval::new(lo=-2.0, hi=3.0).square(),
    Interval::new(lo=0.0, hi=9.0),
  )
  assert_interval_eq(Empty.sqrt(), Empty)
  assert_interval_eq(Empty.square(), Empty)
}

///|
test "squarer propagates both ways" {
  {
    let input = Cell::default()
    let output = Cell::default()
    squarer(input, output)
    input.write(Interval::new(lo=2.0, hi=3.0))
    assert_interval_eq(output.content().unwrap(), Interval::new(lo=4.0, hi=9.0))
  }
  {
    let input = Cell::default()
    let output = Cell::default()
    squarer(input, output)
    input.write(Interval::new(lo=2.0, hi=10.0))
    output.write(Interval::new(lo=4.0, hi=9.0))
    assert_interval_eq(input.content().unwrap(), Interval::new(lo=2.0, hi=3.0))
  }
  let input = Cell::default()
  let output = Cell::default()
  squarer(input, output)
  input.write(Interval::new(lo=-10.0, hi=-2.0))
  output.write(Interval::new(lo=4.0, hi=9.0))
  assert_interval_eq(input.content().unwrap(), Interval::new(lo=-3.0, hi=-2.0))
}

///|
test "sqrter propagates both ways" {
  {
    let input = Cell::default()
    let output = Cell::default()
    sqrter(input, output)
    input.write(Interval::new(lo=4.0, hi=9.0))
    assert_interval_eq(output.content().unwrap(), Interval::new(lo=2.0, hi=3.0))
  }
  {
    let input = Cell::default()
    let output = Cell::default()
    sqrter(input, output)
    input.write(Interval::new(lo=0.0, hi=100.0))
    output.write(Interval::new(lo=2.0, hi=3.0))
    assert_interval_eq(input.content().unwrap(), Interval::new(lo=4.0, hi=9.0))
  }
  let input = Cell::default()
  let output = Cell::default()
  sqrter(input, output)
  output.write(Interval::new(lo=-3.0, hi=-2.0))
  assert_interval_eq(input.content().unwrap(), Empty)
  assert_interval_eq(output.content().unwrap(), Empty)
}
