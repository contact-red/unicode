// `_TextIndex` — optional bitmap index built from a Text's UTF-8 bytes.
//
// Per design/candidate-v3.md §3.5, the index lets indexed Texts answer
// `size_graphemes()` / `size_codepoints()` in O(1) (cached counts) and
// random grapheme lookups in O(n) with a ~64× constant-factor speedup
// over the unindexed UAX-#29 walk.
//
// Storage:
//   `_gr_starts: _BitVec val` — one bit per UTF-8 byte; bit set means
//     "this byte is the start of a grapheme cluster"
//   `_gr_count: USize` — cached popcount
//   `_cp_count: USize` — cached count of codepoints (derived implicitly
//     from a bitmap of "is this byte a codepoint start" — that bitmap
//     itself isn't stored because it's recoverable from the UTF-8
//     lead-byte check `(b & 0xC0) != 0x80`).

class _TextIndex
  let _gr_starts: _BitVec val
  let _gr_count:  USize
  let _cp_count:  USize

  new create(bytes: String box) =>
    """
    Walk the UTF-8 + UAX #29 to build the grapheme-start bitmap and the
    cached counts. The caller must pass a String that has already been
    validated as well-formed UTF-8 (the Text invariant).
    """
    let n = bytes.size()
    let num_words = (n + 63) / 64
    let words = recover trn Array[U64].init(0, num_words) end
    var gr_count: USize = 0
    var cp_count: USize = 0
    let cursor = _GraphemeCursor(bytes)
    var done: Bool = false
    while not done do
      match cursor.next_range()
      | (let start: USize, _) =>
        gr_count = gr_count + 1
        let word_idx = start / 64
        let bit_idx  = U64.from[USize](start % 64)
        try words(word_idx)? = words(word_idx)? or (U64(1) << bit_idx) end
      | None => done = true
      end
    end
    // Codepoint count: walk bytes, count lead bytes (not 0x80..0xBF).
    var i: USize = 0
    while i < n do
      try
        let b = bytes(i)?
        if (b and 0xC0) != 0x80 then cp_count = cp_count + 1 end
      end
      i = i + 1
    end
    _gr_starts = _BitVec(consume words, n)
    _gr_count = gr_count
    _cp_count = cp_count

  fun grapheme_count(): USize => _gr_count
  fun codepoint_count(): USize => _cp_count
  fun byte_is_grapheme_start(i: USize): Bool => _gr_starts.bit(i)
