// Iterators wrapping `_LineBreakCursor`.

class ref _LineRangeIterator is Iterator[(USize, USize)]
  let _cursor: _LineBreakCursor
  var _pending: ((USize, USize) | None)

  new ref create(bytes: String box) =>
    _cursor = _LineBreakCursor(bytes)
    _pending = _cursor.next_range()

  fun ref has_next(): Bool =>
    not (_pending is None)

  fun ref next(): (USize, USize) ? =>
    match _pending = _cursor.next_range()
    | (let s: USize, let f: USize) => (s, f)
    | None => error
    end

class ref _LineSliceIterator is Iterator[String val]
  let _bytes: String val
  let _cursor: _LineBreakCursor
  var _pending: ((USize, USize) | None)

  new ref create(bytes: String val) =>
    _bytes = bytes
    _cursor = _LineBreakCursor(bytes)
    _pending = _cursor.next_range()

  fun ref has_next(): Bool =>
    not (_pending is None)

  fun ref next(): String val ? =>
    match _pending = _cursor.next_range()
    | (let s: USize, let f: USize) => _bytes.trim(s, f)
    | None => error
    end
