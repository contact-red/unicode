// `Search` — substring and prefix/suffix predicates over UTF-8.
//
// Operates at the byte level on already-validated UTF-8 buffers (the
// `Text` invariant). Because UTF-8 is self-synchronizing — a multi-
// byte codepoint can never appear as a substring of another codepoint
// at an offset that isn't a codepoint boundary — byte-level matching
// on validated input gives codepoint-aligned results.
//
// Public methods take `String box` (Text passes its `_utf8` field
// through) and validate UTF-8 for the haystack. Needles are assumed
// to be well-formed; callers building needles from arbitrary bytes
// should validate via `Bytes.is_valid_utf8` first.

primitive Search
  fun contains(haystack: String box, needle: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    True iff `haystack` contains `needle` as a contiguous byte
    subsequence. Empty needle is always contained (returns true).
    """
    match Bytes.first_bad_utf8_offset(haystack)
    | let off: USize => InvalidUtf8(off)
    | AllValid => not (_index_of(haystack, needle, 0) is None)
    end

  fun starts_with(haystack: String box, prefix: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    True iff `haystack` begins with `prefix`.
    """
    match Bytes.first_bad_utf8_offset(haystack)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _starts_with(haystack, prefix)
    end

  fun ends_with(haystack: String box, suffix: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    True iff `haystack` ends with `suffix`.
    """
    match Bytes.first_bad_utf8_offset(haystack)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _ends_with(haystack, suffix)
    end

  fun index_of(haystack: String box, needle: String box)
    : (USize | None | InvalidUtf8)
  =>
    """
    Byte offset of the first occurrence of `needle`, or `None` if
    absent. Empty needle returns 0.
    """
    match Bytes.first_bad_utf8_offset(haystack)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _index_of(haystack, needle, 0)
    end

  fun last_index_of(haystack: String box, needle: String box)
    : (USize | None | InvalidUtf8)
  =>
    """
    Byte offset of the last occurrence of `needle`, or `None`.
    """
    match Bytes.first_bad_utf8_offset(haystack)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _last_index_of(haystack, needle)
    end

  fun count(haystack: String box, needle: String box)
    : (USize | InvalidUtf8)
  =>
    """
    Non-overlapping occurrences of `needle` in `haystack`.
    """
    match Bytes.first_bad_utf8_offset(haystack)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _count(haystack, needle)
    end

  // ============================================================
  // Workhorses (assume valid haystack)
  // ============================================================

  fun _starts_with(haystack: String box, prefix: String box): Bool =>
    if prefix.size() > haystack.size() then return false end
    var i: USize = 0
    while i < prefix.size() do
      try
        if haystack(i)? != prefix(i)? then return false end
      end
      i = i + 1
    end
    true

  fun _ends_with(haystack: String box, suffix: String box): Bool =>
    if suffix.size() > haystack.size() then return false end
    let off = haystack.size() - suffix.size()
    var i: USize = 0
    while i < suffix.size() do
      try
        if haystack(off + i)? != suffix(i)? then return false end
      end
      i = i + 1
    end
    true

  fun _index_of(haystack: String box, needle: String box, start: USize)
    : (USize | None)
  =>
    let n_size = needle.size()
    if n_size == 0 then return start end
    if n_size > haystack.size() then return None end
    var i: USize = start
    let last_start = haystack.size() - n_size
    while i <= last_start do
      var matched: Bool = true
      var j: USize = 0
      while j < n_size do
        try
          if haystack(i + j)? != needle(j)? then
            matched = false
            break
          end
        end
        j = j + 1
      end
      if matched then return i end
      i = i + 1
    end
    None

  fun _last_index_of(haystack: String box, needle: String box)
    : (USize | None)
  =>
    let n_size = needle.size()
    if n_size == 0 then return haystack.size() end
    if n_size > haystack.size() then return None end
    var i: USize = haystack.size() - n_size
    while true do
      var matched: Bool = true
      var j: USize = 0
      while j < n_size do
        try
          if haystack(i + j)? != needle(j)? then
            matched = false
            break
          end
        end
        j = j + 1
      end
      if matched then return i end
      if i == 0 then break end
      i = i - 1
    end
    None

  fun _count(haystack: String box, needle: String box): USize =>
    let n_size = needle.size()
    if n_size == 0 then return 0 end
    var n: USize = 0
    var i: USize = 0
    while (i + n_size) <= haystack.size() do
      var matched: Bool = true
      var j: USize = 0
      while j < n_size do
        try
          if haystack(i + j)? != needle(j)? then
            matched = false
            break
          end
        end
        j = j + 1
      end
      if matched then
        n = n + 1
        i = i + n_size
      else
        i = i + 1
      end
    end
    n
