///|
enum Interval {
  Empty
  Interval(lo~ : Double, hi~ : Double)
}

///|
fn Interval::new(lo~ : Double, hi~ : Double) -> Interval {
  guard lo < hi
  Interval(lo~, hi~)
}

///|
impl Propagated for Interval with merge(self, other) {
  match (self, other) {
    (Interval(_) as l, Interval(_) as r) =>
      if l.hi < r.lo || r.hi < l.lo {
        Change::Change(true, Empty)
      } else {
        Change::Change(
          l.lo < r.lo || l.hi > r.hi,
          Interval::new(
            lo=@cmp.maximum(l.lo, r.lo),
            hi=@cmp.maximum(l.hi, r.lo),
          ),
        )
      }
    (Empty, _) => Change(false, Empty)
    (_, Empty) => Change(true, Empty)
  }
}
