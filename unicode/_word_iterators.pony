// Iterators wrapping `_WordBreakCursor`. Two variants:
//
//   _WordRangeIterator yields `(USize, USize)` byte ranges. Zero
//   per-yield allocation.
//
//   _WordSliceIterator yields `String val` slices via `String val.trim`
//   for the convenience surface (`Text.words()`).

class ref _WordRangeIterator is Iterator[(USize, USize)]
  let _cursor: _WordBreakCursor
  var _pending: ((USize, USize) | None)

  new ref create(bytes: String box) =>
    _cursor = _WordBreakCursor(bytes)
    _pending = _cursor.next_range()

  fun ref has_next(): Bool =>
    not (_pending is None)

  fun ref next(): (USize, USize) ? =>
    match _pending = _cursor.next_range()
    | (let start: USize, let finish: USize) => (start, finish)
    | None => error
    end

class ref _WordSliceIterator is Iterator[String val]
  let _bytes: String val
  let _cursor: _WordBreakCursor
  var _pending: ((USize, USize) | None)

  new ref create(bytes: String val) =>
    _bytes = bytes
    _cursor = _WordBreakCursor(bytes)
    _pending = _cursor.next_range()

  fun ref has_next(): Bool =>
    not (_pending is None)

  fun ref next(): String val ? =>
    match _pending = _cursor.next_range()
    | (let start: USize, let finish: USize) =>
      _bytes.trim(start, finish)
    | None => error
    end
