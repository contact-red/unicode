// `Lines` topical primitive — UAX #14 line-break opportunities.
//
// Each "line" returned spans up to the next break opportunity (which
// may be mandatory or optional per UAX #14). For text reflow into a
// width, callers typically run this iterator and pack segments until
// the width budget is consumed.
//
// See `_LineBreakCursor` for the rule coverage; some EAW-dependent
// tailoring details (LB19a, LB30 width restrictions) are not yet
// implemented.

primitive Lines
  fun count(s: String box): (USize | InvalidUtf8) =>
    """
    Number of UAX #14 line segments.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _count(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun ranges(s: String box)
    : (Iterator[(USize, USize)] | InvalidUtf8)
  =>
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _ranges(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun iter(s: String val)
    : (Iterator[String val] | InvalidUtf8)
  =>
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _iter(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun _count(utf8: String box): USize =>
    let cursor = _LineBreakCursor(utf8)
    var n: USize = 0
    var done: Bool = false
    while not done do
      match cursor.next_range()
      | (_, _) => n = n + 1
      | None => done = true
      end
    end
    n

  fun _ranges(utf8: String box): Iterator[(USize, USize)] =>
    _LineRangeIterator(utf8)

  fun _iter(utf8: String val): Iterator[String val] =>
    _LineSliceIterator(utf8)
