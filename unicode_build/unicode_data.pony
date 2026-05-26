use "../unicode"

// UnicodeData.txt parser.
//
// Each non-comment line has 15 semicolon-separated fields (UAX #44 §5.7.1):
//
//   0: Codepoint (hex)
//   1: Name           (or <name range> markers for ranges like CJK Ideographs)
//   2: General Category (two-letter code)
//   3: Canonical Combining Class (decimal)
//   4: Bidi Class
//   5: Decomposition (optional compatibility tag + sequence of codepoints)
//   6-8: Numeric values
//   9: Bidi Mirrored (Y/N)
//   10: Unicode 1 Name (obsolete)
//   11: ISO Comment (obsolete)
//   12: Simple Uppercase Mapping
//   13: Simple Lowercase Mapping
//   14: Simple Titlecase Mapping
//
// Some entries are *range start* markers, with name `<...First>` and a
// matching `<...Last>` line giving the range end. All codepoints in the
// range share the start entry's category/CCC/etc., but have synthesized
// names (e.g., `CJK UNIFIED IDEOGRAPH-XXXX`).

class val UnicodeDataEntry
  """
  One UnicodeData.txt record after parsing. Range markers are represented
  by `range_end > codepoint` (start entry only); a non-range entry has
  `range_end == codepoint`.

  `name` is the raw field value. For range markers it is e.g.
  `"<CJK Ideograph, First>"`; for non-range entries it is the canonical
  name. Callers that want the synthesized name for a specific codepoint
  in a range derive it themselves.
  """
  let codepoint:        U32
  let range_end:        U32
  let name:             String val
  let category:         Category
  let combining_class:  U8
  let simple_upper:     (U32 | None)
  let simple_lower:     (U32 | None)
  let simple_title:     (U32 | None)
  // Decomposition: empty if none. First element is a compatibility tag
  // codepoint sentinel (0 for canonical, else U32 encoding of "<font>" etc.).
  let decomposition:    Array[U32] val
  let is_compat_decomp: Bool

  new val create(
    codepoint': U32,
    range_end': U32,
    name': String val,
    category': Category,
    combining_class': U8,
    simple_upper': (U32 | None),
    simple_lower': (U32 | None),
    simple_title': (U32 | None),
    decomposition': Array[U32] val,
    is_compat_decomp': Bool)
  =>
    codepoint = codepoint'
    range_end = range_end'
    name = name'
    category = category'
    combining_class = combining_class'
    simple_upper = simple_upper'
    simple_lower = simple_lower'
    simple_title = simple_title'
    decomposition = decomposition'
    is_compat_decomp = is_compat_decomp'


primitive UnicodeDataParser
  fun parse_line(line: String box): (UnicodeDataEntry val | None) ? =>
    """
    Parse one UnicodeData.txt line. Returns `None` for blank/comment lines;
    raises on malformed records.

    Note this returns the line's individual record. The caller is
    responsible for pairing `<...First>` with `<...Last>` to expand ranges
    into `range_end`.
    """
    if UcdLine.is_skippable(line) then return None end
    let f = UcdLine.fields(line, 15)?

    let cp = UcdLine.parse_codepoint(f(0)?)?
    let name = f(1)?
    let cat = _parse_category(f(2)?)?
    let ccc =
      try U8.from[USize](_parse_decimal(f(3)?)?) else 0 end
    let upper = _parse_optional_cp(f(12)?)
    let lower = _parse_optional_cp(f(13)?)
    let title = _parse_optional_cp(f(14)?)
    (let decomp, let is_compat) = _parse_decomposition(f(5)?)?

    UnicodeDataEntry(cp, cp, name, cat, ccc, upper, lower, title, decomp,
      is_compat)

  fun _parse_category(s: String box): Category ? =>
    match Categories.from_iso(s)
    | let c: Category => c
    else
      error
    end

  fun _parse_decimal(s: String box): USize ? =>
    var acc: USize = 0
    if s.size() == 0 then error end
    for c in s.values() do
      if (c >= '0') and (c <= '9') then
        acc = (acc * 10) + USize.from[U8](c - '0')
      else
        error
      end
    end
    acc

  fun _parse_optional_cp(s: String box): (U32 | None) =>
    if s.size() == 0 then return None end
    try UcdLine.parse_codepoint(s)? else None end

  fun _parse_decomposition(s: String box): (Array[U32] val, Bool) ? =>
    """
    Parse a decomposition field. Returns the codepoint sequence (empty for
    no decomposition) and a flag indicating whether this is a compatibility
    decomposition (`<...>` tag present) rather than canonical.
    """
    if s.size() == 0 then return (recover val Array[U32] end, false) end

    let buf = recover trn Array[U32] end
    var is_compat: Bool = false

    var i: USize = 0
    if s(0)? == '<' then
      is_compat = true
      // Skip past closing '>'
      while (i < s.size()) and (s(i)? != '>') do i = i + 1 end
      i = i + 1
      // Skip whitespace after the tag
      while (i < s.size()) and (s(i)? == ' ') do i = i + 1 end
    end

    // Now parse space-separated hex codepoints
    while i < s.size() do
      // Skip whitespace
      while (i < s.size()) and (s(i)? == ' ') do i = i + 1 end
      if i >= s.size() then break end
      var j = i
      while (j < s.size()) and (s(j)? != ' ') do j = j + 1 end
      let token = recover val s.substring(ISize.from[USize](i), ISize.from[USize](j)) end
      buf.push(UcdLine.parse_codepoint(token)?)
      i = j
    end
    (consume buf, is_compat)


primitive UnicodeDataReader
  fun parse_all(lines: ReadSeq[String val] box): Array[UnicodeDataEntry val] val ? =>
    """
    Parse all lines from UnicodeData.txt into a sequence of entries with
    `<...First>`/`<...Last>` ranges already collapsed into single entries
    spanning `codepoint..range_end`.

    Raises if any line is malformed or if a First marker has no matching
    Last marker.
    """
    let out = recover trn Array[UnicodeDataEntry val] end
    var pending_first: (UnicodeDataEntry val | None) = None

    for line in lines.values() do
      match UnicodeDataParser.parse_line(line)?
      | let e: UnicodeDataEntry val =>
        if e.name.at("<", 0) then
          if e.name.contains("First>", 0) then
            pending_first = e
          elseif e.name.contains("Last>", 0) then
            match pending_first
            | let first: UnicodeDataEntry val =>
              out.push(UnicodeDataEntry(
                first.codepoint, e.codepoint, first.name, first.category,
                first.combining_class, first.simple_upper, first.simple_lower,
                first.simple_title, first.decomposition, first.is_compat_decomp))
              pending_first = None
            else
              error
            end
          else
            out.push(e)
          end
        else
          out.push(e)
        end
      | None => None
      end
    end
    if pending_first isnt None then error end
    consume out
