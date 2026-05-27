// Compact bit-vector used by `_TextIndex` to record which UTF-8 byte
// offsets are grapheme-cluster starts. Storage is `Array[U64] val` for
// 64-bit-word access; `bit(i)` extracts the i-th bit.

class val _BitVec
  let _words: Array[U64] val
  let _size:  USize        // number of bits actually populated

  new val create(words: Array[U64] val, bits: USize) =>
    _words = words
    _size = bits

  fun size(): USize => _size

  fun bit(i: USize): Bool =>
    """
    True iff bit `i` is set. Out-of-range queries return false rather
    than raising — the caller (binary search, popcount range, etc.)
    can rely on a clean boundary without try/end ceremony.
    """
    if i >= _size then return false end
    let word_idx = i / 64
    let bit_idx  = U64.from[USize](i % 64)
    try (_words(word_idx)? and (U64(1) << bit_idx)) != 0 else false end

  fun popcount(): USize =>
    """
    Number of set bits in the whole vector.
    """
    var n: USize = 0
    for w in _words.values() do
      n = n + USize.from[U64](w.popcount())
    end
    n
