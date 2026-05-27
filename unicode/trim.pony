// `Trim` — strip whitespace codepoints from the start and/or end.
//
// "Whitespace" is the `White_Space` binary property from PropList.txt
// (29 codepoints including ASCII tab/LF/CR/space, NBSP U+00A0,
// EN/EM spaces, IDEOGRAPHIC SPACE U+3000, etc.).

primitive Trim
  fun trim(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Strip leading and trailing whitespace codepoints. Returns a
    fresh `String iso^` containing the inner content.
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid =>
      let start = _scan_start(s)
      let stop = _scan_end(s, start)
      _slice(s, start, stop)
    end

  fun trim_start(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Strip only leading whitespace.
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid =>
      let start = _scan_start(s)
      _slice(s, start, s.size())
    end

  fun trim_end(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Strip only trailing whitespace.
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid =>
      let stop = _scan_end(s, 0)
      _slice(s, 0, stop)
    end

  // ============================================================
  // Workhorses (assume valid UTF-8)
  // ============================================================

  fun _scan_start(s: String box): USize =>
    """
    Byte offset of the first non-whitespace codepoint.
    """
    var i: USize = 0
    let n = s.size()
    while i < n do
      let cp_size = _utf8_len_at(s, i)
      let cp = _read_cp(s, i, cp_size)
      if not Codepoints.has_binary_property(cp, PropWhiteSpace) then
        return i
      end
      i = i + cp_size
    end
    n

  fun _scan_end(s: String box, lower_bound: USize): USize =>
    """
    Byte offset one past the last non-whitespace codepoint (or
    `lower_bound`). Walks codepoints from the start because UTF-8
    doesn't support efficient reverse iteration without scanning.
    """
    var i: USize = lower_bound
    let n = s.size()
    var last_non_ws_end: USize = lower_bound
    while i < n do
      let cp_size = _utf8_len_at(s, i)
      let cp = _read_cp(s, i, cp_size)
      if not Codepoints.has_binary_property(cp, PropWhiteSpace) then
        last_non_ws_end = i + cp_size
      end
      i = i + cp_size
    end
    last_non_ws_end

  fun _utf8_len_at(s: String box, i: USize): USize =>
    try
      let b = s(i)?
      if (b and 0x80) == 0 then 1
      elseif (b and 0xE0) == 0xC0 then 2
      elseif (b and 0xF0) == 0xE0 then 3
      elseif (b and 0xF8) == 0xF0 then 4
      else 1  // shouldn't reach in validated UTF-8
      end
    else 1
    end

  fun _read_cp(s: String box, i: USize, cp_size: USize): U32 =>
    """
    Decode a single codepoint at byte offset `i`. Caller has already
    determined `cp_size` via `_utf8_len_at`. Input must be valid
    UTF-8 at that position.
    """
    try
      match cp_size
      | 1 => U32.from[U8](s(i)?)
      | 2 =>
        (U32.from[U8](s(i)? and 0x1F) << 6)
          or U32.from[U8](s(i + 1)? and 0x3F)
      | 3 =>
        (U32.from[U8](s(i)? and 0x0F) << 12)
          or (U32.from[U8](s(i + 1)? and 0x3F) << 6)
          or U32.from[U8](s(i + 2)? and 0x3F)
      | 4 =>
        (U32.from[U8](s(i)? and 0x07) << 18)
          or (U32.from[U8](s(i + 1)? and 0x3F) << 12)
          or (U32.from[U8](s(i + 2)? and 0x3F) << 6)
          or U32.from[U8](s(i + 3)? and 0x3F)
      else U32(0)
      end
    else U32(0)
    end

  fun _slice(s: String box, start: USize, stop: USize): String iso^ =>
    let buf = recover iso String((stop - start).max(0)) end
    var i: USize = start
    while i < stop do
      try buf.push(s(i)?) end
      i = i + 1
    end
    consume buf
