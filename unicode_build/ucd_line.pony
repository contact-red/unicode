// UCD file line parsing.
//
// UCD files are line-oriented, US-ASCII, semicolon-separated. Comments begin
// with `#` and run to end-of-line. Blank lines are ignored. Codepoint values
// are uppercase hex (no `0x` prefix); ranges use `..` as the separator.
//
// This primitive handles the parse-side; callers pass already-read lines.

primitive UcdLine
  fun is_skippable(line: String box): Bool =>
    """
    True for blank or comment-only lines.
    """
    let trimmed = _strip_inline_comment(line)
    _is_blank(trimmed)

  fun strip_comment(line: String box): String iso^ =>
    """
    Return the line with any `#...` comment trailer removed and trailing
    whitespace stripped. The returned `String iso^` is a fresh copy.
    """
    _strip_inline_comment(line).clone()

  fun fields(line: String box, n: USize): Array[String val] val ? =>
    """
    Split a UCD record line into `n` semicolon-separated fields, with each
    field trimmed of leading/trailing whitespace. Raises if the record has
    fewer fields than requested.

    Comment trailer is stripped before splitting.
    """
    let body = _strip_inline_comment(line)
    let parts = recover trn Array[String val] end
    var start: USize = 0
    var idx: USize = 0
    while idx < body.size() do
      if body(idx)? == ';' then
        parts.push(_trim_slice(body, start, idx))
        start = idx + 1
      end
      idx = idx + 1
    end
    parts.push(_trim_slice(body, start, body.size()))
    if parts.size() < n then error end
    consume parts

  fun parse_codepoint(s: String box): U32 ? =>
    """
    Parse a UCD codepoint (uppercase hex, no `0x` prefix) into U32.
    Raises on invalid input. Values above U+10FFFF are accepted by the
    parser — caller validates as needed.
    """
    var acc: U32 = 0
    if s.size() == 0 then error end
    for c in s.values() do
      let digit: U32 =
        if (c >= '0') and (c <= '9') then U32.from[U8](c - '0')
        elseif (c >= 'A') and (c <= 'F') then U32.from[U8]((c - 'A') + 10)
        elseif (c >= 'a') and (c <= 'f') then U32.from[U8]((c - 'a') + 10)
        else error
        end
      acc = (acc * 16) + digit
    end
    acc

  fun parse_codepoint_range(s: String box): (U32, U32) ? =>
    """
    Parse a single codepoint or codepoint range (`XXXX` or `XXXX..YYYY`)
    into an inclusive `(start, end)` pair. For a single codepoint,
    `start == end`. Raises on invalid input.
    """
    let dots = _find_dotdot(s)
    match dots
    | let i: USize =>
      let lo = parse_codepoint(_trim_slice(s, 0, i))?
      let hi = parse_codepoint(_trim_slice(s, i + 2, s.size()))?
      if hi < lo then error end
      (lo, hi)
    | None =>
      let cp = parse_codepoint(s)?
      (cp, cp)
    end

  // ---- internals ----

  fun _strip_inline_comment(line: String box): String box =>
    """
    Return a `String box` view of `line` with any `#...` trailing comment
    removed and trailing whitespace stripped. The returned string shares
    `line`'s buffer (via `String val.trim`).
    """
    var hash: USize = line.size()
    var i: USize = 0
    while i < line.size() do
      try
        if line(i)? == '#' then
          hash = i
          break
        end
      end
      i = i + 1
    end
    // Trim trailing whitespace
    var end_idx = hash
    while end_idx > 0 do
      try
        let c = line(end_idx - 1)?
        if (c == ' ') or (c == '\t') or (c == '\r') or (c == '\n') then
          end_idx = end_idx - 1
        else
          break
        end
      end
    end
    // `trim` is only on `String val`; for `box` receivers we use `substring`.
    recover val line.substring(0, ISize.from[USize](end_idx)) end

  fun _is_blank(s: String box): Bool =>
    var i: USize = 0
    while i < s.size() do
      try
        let c = s(i)?
        if (c != ' ') and (c != '\t') and (c != '\r') and (c != '\n') then
          return false
        end
      end
      i = i + 1
    end
    true

  fun _trim_slice(s: String box, start: USize, end_pos: USize): String val =>
    """
    Extract `s[start..end_pos)`, then strip leading/trailing ASCII whitespace,
    and return as an immutable `String val` (cloned).
    """
    var lo = start
    var hi = end_pos.min(s.size())
    while lo < hi do
      try
        let c = s(lo)?
        if (c == ' ') or (c == '\t') then lo = lo + 1 else break end
      end
    end
    while hi > lo do
      try
        let c = s(hi - 1)?
        if (c == ' ') or (c == '\t') then hi = hi - 1 else break end
      end
    end
    recover val s.substring(ISize.from[USize](lo), ISize.from[USize](hi)) end

  fun _find_dotdot(s: String box): (USize | None) =>
    var i: USize = 0
    while (i + 1) < s.size() do
      try
        if (s(i)? == '.') and (s(i + 1)? == '.') then return i end
      end
      i = i + 1
    end
    None
