// `Words` topical primitive — UAX #29 word segmentation over UTF-8.
//
// Mirrors `Graphemes` in shape: public string-level entries validate
// UTF-8 first; package-private workhorses skip validation and are
// called by `Text` against its already-validated buffer.

primitive Words
  fun count(s: String box): (USize | InvalidUtf8) =>
    """
    Number of UAX #29 word segments in `s`. A "word segment" here is
    any boundary-delimited run — letters, numerics, and punctuation
    all count, since UAX #29 defines boundaries rather than
    "wordness". Use the test `Words.iter` and filter to letters/
    numerics yourself if you want only words-as-text.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _count(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun ranges(s: String box)
    : (Iterator[(USize, USize)] | InvalidUtf8)
  =>
    """
    Iterator over byte ranges `[start, end_exclusive)` of each word
    segment. Zero per-yield allocation.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _ranges(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun iter(s: String val)
    : (Iterator[String val] | InvalidUtf8)
  =>
    """
    Iterator yielding each word segment as a `String val` slice
    (zero byte-copy). Takes `String val` because the yielded slices
    share the same val buffer.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _iter(s)
    | let off: USize => InvalidUtf8(off)
    end

  // ============================================================
  // Workhorses (assume valid UTF-8)
  // ============================================================

  fun _count(utf8: String box): USize =>
    let cursor = _WordBreakCursor(utf8)
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
    _WordRangeIterator(utf8)

  fun _iter(utf8: String val): Iterator[String val] =>
    _WordSliceIterator(utf8)
