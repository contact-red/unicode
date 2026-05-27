// Iterators wrapping `_GraphemeCursor`. Two variants:
//
//   _GraphemeRangeIterator yields `(USize, USize)` byte ranges. Zero
//   per-yield allocation — for hot paths on large texts.
//
//   _GraphemeSliceIterator yields `String val` slices via `String val.trim`.
//   Each slice shares the parent's UTF-8 buffer (zero byte-copy) at the
//   cost of one small `String` wrapper allocation per yield. Convenience
//   default for `Text.graphemes()`.

class ref _GraphemeRangeIterator is Iterator[(USize, USize)]
  let _cursor: _GraphemeCursor
  var _pending: ((USize, USize) | None)

  new ref create(bytes: String box) =>
    _cursor = _GraphemeCursor(bytes)
    _pending = _cursor.next_range()

  fun ref has_next(): Bool =>
    not (_pending is None)

  fun ref next(): (USize, USize) ? =>
    match _pending = _cursor.next_range()
    | (let start: USize, let finish: USize) => (start, finish)
    | None => error
    end

class ref _GraphemeSliceIterator is Iterator[String val]
  let _bytes: String val
  let _cursor: _GraphemeCursor
  var _pending: ((USize, USize) | None)

  new ref create(bytes: String val) =>
    _bytes = bytes
    _cursor = _GraphemeCursor(bytes)
    _pending = _cursor.next_range()

  fun ref has_next(): Bool =>
    not (_pending is None)

  fun ref next(): String val ? =>
    match _pending = _cursor.next_range()
    | (let start: USize, let finish: USize) =>
      _bytes.trim(start, finish)
    | None => error
    end
