// `Text` — the canonical typed text wrapper.
//
// `Text` carries the well-formed-UTF-8 invariant (validated at every
// public constructor via `?` partial functions) plus an optional bitmap
// index (added in M4) for fast random grapheme access. The default cap
// is `val` (immutable, shareable across actors). Constructors return
// ephemeral `iso^` so callers can recover to whichever cap they need —
// `val` for sharing, `iso`/`ref` for the build-then-freeze pattern.
//
// Internal storage:
//   `_utf8: String ref` — a String reference. Through `Text val`
//   viewpoint adaptation, this appears as `String val`; through
//   `Text ref`, it appears as `String ref` (mutable). Mutator methods
//   (M8) require a `ref` receiver to invoke `String ref` methods like
//   `truncate`, `append`, etc.
//   `_index: (_TextIndex val | None)` — placeholder for M4's bitmap
//   index. Always `None` at M2.

class Text
  let _utf8:  String ref
  let _index: (_TextIndex val | None)

  new create(len: USize = 0) =>
    """
    An empty Text. `len` is a capacity hint passed through to the
    underlying String. Returns ephemeral; bind to whichever cap the
    context requires (most often `val`, matching Pony's `String`
    constructor convention).
    """
    _utf8 = String(len)
    _index = None

  new val from_string(s: String val, indexed: Bool = false) ? =>
    """
    Wrap a `String val` after validating it as UTF-8. Raises if the
    input is ill-formed.

    If `indexed` is true, also builds the grapheme-start bitmap index
    so subsequent `size_graphemes()` / `size_codepoints()` are O(1)
    and random grapheme lookups are ~64× faster (see §3.5 of the
    design notes). Pay-for-what-you-use — pass-through workloads that
    never index pay nothing.
    """
    if not Bytes.is_valid_utf8(s) then error end
    _index = if indexed then recover val _TextIndex(s) end else None end
    _utf8 = s.clone()

  new val from_array(a: Array[U8] val, indexed: Bool = false) ? =>
    """
    Wrap a byte array after validating it as UTF-8. Raises on
    ill-formed input. The bytes are copied into the Text's internal
    `String ref` buffer. See `from_string` for the `indexed` flag.
    """
    if not Bytes.is_valid_utf8(a) then error end
    let buf_val: String val = recover val
      let b = String(a.size())
      b.append(a)
      b
    end
    _index = if indexed then recover val _TextIndex(buf_val) end else None end
    _utf8 = buf_val.clone()

  new iso from_iso_string(s: String iso, indexed: Bool = false) ? =>
    """
    Zero-byte-copy adoption of an `iso` String when `indexed` is false.
    When `indexed` is true, builds the optional bitmap index — this
    requires viewing the bytes via a val alias, which costs one extra
    byte-copy (the opt-in price of indexing).

    Validates UTF-8 in place. Raises on ill-formed input. See
    `from_string` for the `indexed` flag.
    """
    let buf = _IsoUtf8.validate_string(consume s)?
    if indexed then
      let buf_val: String val = consume buf
      _index = recover val _TextIndex(buf_val) end
      _utf8 = buf_val.clone()
    else
      _index = None
      _utf8 = consume buf
    end

  new iso from_iso_array(a: Array[U8] iso, indexed: Bool = false) ? =>
    """
    Zero-byte-copy adoption of an `iso` byte array when `indexed` is
    false. See `from_iso_string` for the `indexed` tradeoff.
    """
    let validated = _IsoUtf8.validate_array(consume a)?
    let buf = String.from_iso_array(consume validated)
    if indexed then
      let buf_val: String val = consume buf
      _index = recover val _TextIndex(buf_val) end
      _utf8 = buf_val.clone()
    else
      _index = None
      _utf8 = consume buf
    end

  fun box size_bytes(): USize =>
    """
    Number of UTF-8 bytes in this Text. O(1).
    """
    _utf8.size()

  fun box utf8_bytes(): String iso^ =>
    """
    Return a fresh `String iso^` containing a copy of this Text's
    UTF-8 bytes. The caller owns the returned String and can mutate,
    consume, or recover to any cap. One byte-copy per call — for
    callers that just want a read-only view, the underlying String
    can be reached via viewpoint adaptation in the package's own
    code; external callers always pay the copy.
    """
    _utf8.clone()

  fun val graphemes(): Iterator[String val] =>
    """
    Iterate over the UAX #29 extended grapheme clusters in this Text.
    Each yielded `String val` is a zero-byte-copy slice of the
    underlying UTF-8 buffer (one small `String` wrapper allocation
    per yield).

    For zero-allocation iteration on large texts, use
    `grapheme_ranges()`.
    """
    Graphemes._iter(_utf8)

  fun box grapheme_ranges(): Iterator[(USize, USize)] =>
    """
    Iterate over grapheme clusters as `(start_byte, end_byte_exclusive)`
    pairs. No per-yield allocation. Pair with `utf8_bytes()` to
    materialize specific clusters lazily.
    """
    Graphemes._ranges(_utf8)

  fun val words(): Iterator[String val] =>
    """
    Iterate over UAX #29 word segments as zero-byte-copy `String val`
    slices. UAX #29 defines *boundaries*, not "wordness" — punctuation
    runs and whitespace runs each show up as their own segment. Use
    `Codepoints.is_letter` / `is_digit` on the first cp of a segment
    to filter to words-as-text yourself.
    """
    Words._iter(_utf8)

  fun box word_ranges(): Iterator[(USize, USize)] =>
    """
    Iterate over word segments as `(start_byte, end_byte_exclusive)`
    byte pairs. No per-yield allocation.
    """
    Words._ranges(_utf8)

  fun val sentences(): Iterator[String val] =>
    """
    Iterate over UAX #29 sentence segments as zero-byte-copy
    `String val` slices.
    """
    Sentences._iter(_utf8)

  fun box sentence_ranges(): Iterator[(USize, USize)] =>
    """
    Iterate over sentence segments as `(start_byte, end_byte_exclusive)`
    byte pairs.
    """
    Sentences._ranges(_utf8)

  fun val lines(): Iterator[String val] =>
    """
    Iterate over UAX #14 line-break opportunities, yielding each line
    as a zero-byte-copy `String val` slice. Each yielded slice ends
    where a line break would occur (either a mandatory break — LF, CR,
    NEL — or a soft opportunity).
    """
    Lines._iter(_utf8)

  fun box line_ranges(): Iterator[(USize, USize)] =>
    """
    Iterate over line segments as `(start_byte, end_byte_exclusive)`
    byte pairs.
    """
    Lines._ranges(_utf8)

  fun box scripts(): ScriptSet val =>
    """
    The set of `script(cp)` values for every codepoint in this Text.
    Includes `ScriptCommon` (digits, punctuation) and
    `ScriptInherited` (combining marks) when present; call
    `.resolved()` on the result to drop those.
    """
    Scripts.of(_utf8)

  fun box dominant_script(): Script =>
    """
    The most-frequent non-Common, non-Inherited script in this Text.
    Ties broken by first-seen. Returns `ScriptCommon` for an empty
    or all-Common/Inherited Text.
    """
    Scripts.dominant(_utf8)

  fun box contains_unassigned_codepoint(): Bool =>
    """
    True iff this Text contains at least one codepoint with
    `General_Category` = `Cn` (unassigned). Useful as an
    identifier-input filter: unassigned codepoints in user input are
    usually a sign of bad data or an attempt to exploit Unicode
    version skew.
    """
    for cp in _utf8.runes() do
      match Codepoints.category(cp)
      | Cn => return true
      end
    end
    false

  fun box size_graphemes(): USize =>
    """
    Number of extended grapheme clusters in this Text. O(1) on an
    indexed Text (cached count); O(n) otherwise (walks the bytes).
    """
    match _index
    | let idx: _TextIndex val => idx.grapheme_count()
    | None => Graphemes._count(_utf8)
    end

  fun box size_codepoints(): USize =>
    """
    Number of Unicode codepoints in this Text. O(1) on an indexed
    Text; O(n) otherwise (walks the UTF-8 bytes counting lead bytes).
    """
    match _index
    | let idx: _TextIndex val => idx.codepoint_count()
    | None => Codepoints._count(_utf8)
    end

  fun box is_indexed(): Bool =>
    """
    True iff this Text carries the optional bitmap index. Use
    `with_index()` / `without_index()` to obtain a copy with the
    index flipped.
    """
    match _index
    | let _: _TextIndex val => true
    | None => false
    end

  fun val with_index(): Text val ? =>
    """
    Return a copy of this Text carrying the optional bitmap index.
    The byte buffer is cloned and the index is rebuilt. Partial only
    because `from_string` is partial — the bytes here are guaranteed
    valid so the error path is unreachable.
    """
    Text.from_string(_utf8.clone(), true)?

  fun val without_index(): Text val ? =>
    """
    Return an index-free copy of this Text. The byte buffer is
    cloned; partial for the same reason as `with_index()`.
    """
    Text.from_string(_utf8.clone(), false)?

  // ============================================================
  // Index construction (range-checked)
  // ============================================================

  fun box byte_index(n: USize): (ByteIndex | OutOfRange) =>
    """
    Construct a `ByteIndex` pointing at byte position `n` (or the
    one-past-end position `size_bytes()`). Returns `OutOfRange` for
    values larger than `size_bytes()`.
    """
    if n <= _utf8.size() then Index[_ByteIdx]._raw(n)
    else OutOfRange(n, _utf8.size())
    end

  fun box codepoint_index(n: USize): (CodepointIndex | OutOfRange) =>
    """
    Construct a `CodepointIndex` pointing at the n-th codepoint (or
    the one-past-end position). Range-checked against
    `size_codepoints()` — O(n) until M4d's indexed Text caches the
    count.
    """
    let count = size_codepoints()
    if n <= count then Index[_CodepointIdx]._raw(n)
    else OutOfRange(n, count)
    end

  fun box grapheme_index(n: USize): (GraphemeIndex | OutOfRange) =>
    """
    Construct a `GraphemeIndex` pointing at the n-th grapheme cluster
    (or the one-past-end position). Range-checked against
    `size_graphemes()`.
    """
    let count = size_graphemes()
    if n <= count then Index[_GraphemeIdx]._raw(n)
    else OutOfRange(n, count)
    end

  // ============================================================
  // Indexing — argument kind enforces correctness at compile time
  // ============================================================

  fun box byte_at(i: ByteIndex): (U8 | OutOfRange) =>
    """
    The raw UTF-8 byte at position `i`. Returns `OutOfRange` if `i`
    is at or past the end.
    """
    let n = i.value()
    if n >= _utf8.size() then OutOfRange(n, _utf8.size())
    else
      try _utf8(n)? else OutOfRange(n, _utf8.size()) end
    end

  fun box codepoint_at(i: CodepointIndex): (Codepoint val | OutOfRange) =>
    """
    The `Codepoint val` at position `i`. Walks the UTF-8 bytes from
    the start; O(n) until M4d adds an indexed fast path.
    """
    let target = i.value()
    var n: USize = 0
    for u in _utf8.runes() do
      if n == target then
        return Codepoint._create(u)
      end
      n = n + 1
    end
    OutOfRange(target, n)

  fun val grapheme_at(i: GraphemeIndex): (String val | OutOfRange) =>
    """
    The grapheme cluster at position `i`, returned as a `String val`
    slice of the underlying UTF-8 buffer (zero byte-copy). Walks the
    bytes; O(n) until M4d. Receiver is `val` because the returned
    slice shares the val view of `_utf8`.
    """
    let target = i.value()
    var n: USize = 0
    let it = _GraphemeRangeIterator(_utf8)
    while it.has_next() do
      try
        (let start, let finish) = it.next()?
        if n == target then
          return _utf8.trim(start, finish)
        end
        n = n + 1
      end
    end
    OutOfRange(target, n)

  // ============================================================
  // Slicing — by codepoint or grapheme, both returning a new Text
  // ============================================================

  fun val slice_codepoints(
    start: CodepointIndex,
    end_idx: CodepointIndex)
    : (Text val | OutOfRange)
  =>
    """
    A new Text containing codepoints in the half-open range
    `[start, end_idx)`. The result is unindexed; chain `with_index()`
    if you need O(1) sizes on the slice.

    Returns `OutOfRange` if `start > end_idx` or `end_idx` exceeds
    `size_codepoints()`. An empty range yields an empty Text.
    """
    let s = start.value()
    let e = end_idx.value()
    let total = size_codepoints()
    if (s > e) or (e > total) then return OutOfRange(e, total) end
    if s == e then
      return try Text.from_string("")? else OutOfRange(0, 0) end
    end
    var cp: USize = 0
    var i: USize = 0
    var sbyte: USize = 0
    var ebyte: USize = _utf8.size()
    let n = _utf8.size()
    var done: Bool = false
    while (i < n) and (not done) do
      try
        let b = _utf8(i)?
        if (b and 0xC0) != 0x80 then
          if cp == s then sbyte = i end
          if cp == e then ebyte = i; done = true end
          cp = cp + 1
        end
      end
      if not done then i = i + 1 end
    end
    try Text.from_string(_utf8.trim(sbyte, ebyte))?
    else OutOfRange(s, total) end

  fun val slice_graphemes(
    start: GraphemeIndex,
    end_idx: GraphemeIndex)
    : (Text val | OutOfRange)
  =>
    """
    A new Text containing grapheme clusters in the half-open range
    `[start, end_idx)`. The result is unindexed.

    Returns `OutOfRange` if `start > end_idx` or `end_idx` exceeds
    `size_graphemes()`. An empty range yields an empty Text.
    """
    let s = start.value()
    let e = end_idx.value()
    let total = size_graphemes()
    if (s > e) or (e > total) then return OutOfRange(e, total) end
    if s == e then
      return try Text.from_string("")? else OutOfRange(0, 0) end
    end
    var n: USize = 0
    var sbyte: USize = 0
    var ebyte: USize = _utf8.size()
    var done: Bool = false
    let it = _GraphemeRangeIterator(_utf8)
    while it.has_next() and (not done) do
      try
        (let gs, let ge) = it.next()?
        if n == s then sbyte = gs end
        if (n + 1) == e then ebyte = ge; done = true end
        n = n + 1
      end
    end
    try Text.from_string(_utf8.trim(sbyte, ebyte))?
    else OutOfRange(s, total) end

  // ============================================================
  // Conversions: cross-unit ByteIndex resolution
  // ============================================================

  fun box codepoint_byte_index(c: CodepointIndex): (ByteIndex | OutOfRange) =>
    """
    The `ByteIndex` of the first UTF-8 byte of codepoint `c`. If `c`
    equals `size_codepoints()`, returns the one-past-end `ByteIndex`.
    """
    let target = c.value()
    let total = size_codepoints()
    if target > total then return OutOfRange(target, total) end
    if target == total then return Index[_ByteIdx]._raw(_utf8.size()) end
    var cp: USize = 0
    var i: USize = 0
    let n = _utf8.size()
    while i < n do
      try
        let b = _utf8(i)?
        if (b and 0xC0) != 0x80 then
          if cp == target then return Index[_ByteIdx]._raw(i) end
          cp = cp + 1
        end
      end
      i = i + 1
    end
    OutOfRange(target, total)

  fun box grapheme_byte_index(g: GraphemeIndex): (ByteIndex | OutOfRange) =>
    """
    The `ByteIndex` of the first UTF-8 byte of grapheme cluster `g`.
    If `g` equals `size_graphemes()`, returns the one-past-end
    `ByteIndex`.
    """
    let target = g.value()
    let total = size_graphemes()
    if target > total then return OutOfRange(target, total) end
    if target == total then return Index[_ByteIdx]._raw(_utf8.size()) end
    let cursor = _GraphemeCursor(_utf8)
    var n: USize = 0
    var done: Bool = false
    while not done do
      match cursor.next_range()
      | (let gs: USize, _) =>
        if n == target then return Index[_ByteIdx]._raw(gs) end
        n = n + 1
      | None => done = true
      end
    end
    OutOfRange(target, total)
