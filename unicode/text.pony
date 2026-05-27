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

  new val from_string(s: String val) ? =>
    """
    Wrap a `String val` after validating it as UTF-8. Raises if the
    input is ill-formed. Callers that want the offset/kind of the bad
    sequence should call `Bytes.first_bad_utf8_offset(s)` first.
    """
    if not Bytes.is_valid_utf8(s) then error end
    _utf8 = s.clone()
    _index = None

  new val from_array(a: Array[U8] val) ? =>
    """
    Wrap a byte array after validating it as UTF-8. Raises on
    ill-formed input. The bytes are copied into the Text's internal
    `String ref` buffer.
    """
    if not Bytes.is_valid_utf8(a) then error end
    let buf = String(a.size())
    buf.append(a)
    _utf8 = buf
    _index = None

  new iso from_iso_string(s: String iso) ? =>
    """
    Zero-byte-copy adoption of an `iso` String. Validates UTF-8 in
    place (walks the bytes directly via index access — see
    `_IsoUtf8.validate_string`) and consumes the iso into the Text on
    success. Raises on ill-formed input.
    """
    _utf8 = _IsoUtf8.validate_string(consume s)?
    _index = None

  new iso from_iso_array(a: Array[U8] iso) ? =>
    """
    Zero-byte-copy adoption of an `iso` byte array. Validates UTF-8 in
    place and consumes the array into a String on success. Raises on
    ill-formed input.
    """
    let validated = _IsoUtf8.validate_array(consume a)?
    _utf8 = String.from_iso_array(consume validated)
    _index = None

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
    _GraphemeSliceIterator(_utf8)

  fun box grapheme_ranges(): Iterator[(USize, USize)] =>
    """
    Iterate over grapheme clusters as `(start_byte, end_byte_exclusive)`
    pairs. No per-yield allocation. Pair with `utf8_bytes()` to
    materialize specific clusters lazily.
    """
    _GraphemeRangeIterator(_utf8)

  fun box size_graphemes(): USize =>
    """
    Number of extended grapheme clusters in this Text. O(n) — walks
    the bytes to count. Indexed `Text` will get O(1) via the cached
    bitmap count once M4d lands.
    """
    var n: USize = 0
    let it = _GraphemeRangeIterator(_utf8)
    while it.has_next() do
      try it.next()? end
      n = n + 1
    end
    n
