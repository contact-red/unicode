// `Graphemes` topical primitive.
//
// String-level UAX #29 extended-grapheme-cluster operations. Public
// entry points validate the bytes as UTF-8 first and return
// `InvalidUtf8` on failure; package-private workhorses skip validation
// and are called by `Text` (which carries the well-formed invariant on
// its `_utf8` buffer).
//
// Mirrors `Codepoints` in shape (per the logic-in-primitives pattern):
// receiver type signals scale — single cluster vs. whole string —
// with the primitive owning the rules and `Text` delegating.

primitive Graphemes
  // ============================================================
  // String-level operations (validate first)
  // ============================================================

  fun count(s: String box): (USize | InvalidUtf8) =>
    """
    Number of extended grapheme clusters in `s` per UAX #29.
    Returns `InvalidUtf8` if `s` isn't well-formed UTF-8 — error
    carries the byte offset of the first ill-formed sequence.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _count(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun ranges(s: String box)
    : (Iterator[(USize, USize)] | InvalidUtf8)
  =>
    """
    Iterator over the byte ranges `[start, end_exclusive)` of each
    grapheme cluster in `s`. No per-yield allocation. Returns
    `InvalidUtf8` if `s` isn't well-formed UTF-8.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _ranges(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun iter(s: String val)
    : (Iterator[String val] | InvalidUtf8)
  =>
    """
    Iterator yielding each grapheme cluster as a `String val` slice
    (zero byte-copy; one small `String` wrapper allocation per yield).
    Takes `String val` because the yielded slices share the same val
    buffer. Returns `InvalidUtf8` if `s` isn't well-formed.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _iter(s)
    | let off: USize => InvalidUtf8(off)
    end

  // ============================================================
  // Package-private workhorses (assume valid UTF-8)
  // ============================================================

  fun _count(utf8: String box): USize =>
    """
    Count UAX #29 clusters in already-validated UTF-8.
    """
    let cursor = _GraphemeCursor(utf8)
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
    _GraphemeRangeIterator(utf8)

  fun _iter(utf8: String val): Iterator[String val] =>
    _GraphemeSliceIterator(utf8)
