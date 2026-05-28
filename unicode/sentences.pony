// `Sentences` topical primitive — UAX #29 sentence segmentation
// over UTF-8.

primitive Sentences
  fun count(s: String box): (USize | InvalidUtf8) =>
    """
    Number of UAX #29 sentence segments in `s`. Sentences break at
    paragraph separators (SB4) and after end-of-sentence terminators
    like `.`, `!`, `?` followed by appropriate trailing context
    (SB11). Default is NO break — single text run with no sentence
    terminators yields one segment.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _count(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun ranges(s: String box)
    : (Iterator[(USize, USize)] | InvalidUtf8)
  =>
    """
    Iterator over byte ranges `[start, end_exclusive)` for each
    sentence segment.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _ranges(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun iter(s: String val)
    : (Iterator[String val] | InvalidUtf8)
  =>
    """
    Iterator yielding each sentence as a `String val` slice.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _iter(s)
    | let off: USize => InvalidUtf8(off)
    end

  // ============================================================
  // Workhorses (assume valid UTF-8)
  // ============================================================

  fun _count(utf8: String box): USize =>
    let cursor = _SentenceBreakCursor(utf8)
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
    _SentenceRangeIterator(utf8)

  fun _iter(utf8: String val): Iterator[String val] =>
    _SentenceSliceIterator(utf8)
