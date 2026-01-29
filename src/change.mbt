///|
enum Change[T] {
  Change(Bool, T)
  Contradiction(support~ : @immutset.SortedSet[String], err_msg~ : String)
}

///|
suberror MergeError {
  MergeError(String)
}
