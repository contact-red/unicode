// UAX #29 word-boundary state machine.
//
// Word break rules WB1..WB999. Two-pass approach: a precompute step
// walks the UTF-8 bytes once and records (byte_offset, WordBreak) for
// each codepoint, then a second pass applies the rules with full
// lookahead to populate a `_boundaries` array. Iterating yields
// (start, end) byte ranges between successive boundaries.
//
// Rules requiring lookahead:
//   WB6: AHLetter × (MidLetter | MidNumLetQ) AHLetter
//   WB7b: Hebrew_Letter × Double_Quote Hebrew_Letter
//   WB11/WB12 mirror for Numeric
// "Effective" prev class for WB5..WB13b ignores transparent X
// (Extend | Format | ZWJ) per WB4, except where the actual cp matters
// (WB3, WB3a, WB3b, WB3c, WB3d).

class ref _WordBreakCursor
  let _boundaries: Array[USize] val
  var _idx: USize

  new ref create(bytes: String box) =>
    _boundaries = _WordBoundaries.compute(bytes)
    _idx = 0

  fun ref next_range(): ((USize, USize) | None) =>
    if (_idx + 1) >= _boundaries.size() then return None end
    let result =
      try (_boundaries(_idx)?, _boundaries(_idx + 1)?)
      else return None
      end
    _idx = _idx + 1
    result


primitive _WordBoundaries
  fun compute(bytes: String box): Array[USize] val =>
    // Step 1: decode every codepoint into (byte_offset, WordBreak).
    let n_bytes = bytes.size()
    let offsets = Array[USize]
    let classes = Array[WordBreak]
    var i: USize = 0
    while i < n_bytes do
      (let cp, let len) =
        try _decode(bytes, i)? else (U32(0xFFFD), USize(1)) end
      offsets.push(i)
      classes.push(_UcdWordBreak.of(cp))
      i = i + len
    end
    offsets.push(n_bytes)  // sentinel end offset
    let n_cps = classes.size()

    // Step 2: rule application.
    let bounds = recover trn Array[USize] end
    bounds.push(0)
    if n_cps == 0 then
      return consume bounds
    end

    var pos: USize = 0
    while pos < n_cps do
      let next_pos = _next_boundary(classes, pos)
      try bounds.push(offsets(next_pos)?) end
      pos = next_pos
    end
    consume bounds

  fun _next_boundary(classes: Array[WordBreak] box, start: USize): USize =>
    """
    Starting at codepoint index `start`, scan forward applying the
    WB rules. Returns the codepoint index AT which the next word
    starts (i.e., the break is between `result - 1` and `result`).
    A return value of `classes.size()` means the rest of the input
    is one word.
    """
    let n = classes.size()
    if start >= n then return n end
    // Establish "effective" lookback state. eff_prev1 is the most
    // recent non-X (non-Extend/Format/ZWJ) class; eff_prev2 the one
    // before that. Both are None at the start of a word.
    var eff_prev1: (WordBreak | None) = None
    var eff_prev2: (WordBreak | None) = None
    var raw_prev: (WordBreak | None) = None
    var ri_count: USize = 0  // effective RI count in current run

    var i: USize = start
    while i < n do
      let c1 =
        try classes(i)? else WBOther end

      // Decide whether there is a break BEFORE c1 (i.e., between
      // raw_prev and c1). At i == start, by definition the previous
      // boundary is right before i — no rule applies (skip into the
      // state update).
      if i > start then
        let prev_raw =
          match raw_prev | let p: WordBreak => p else WBOther end
        if _break_before(c1, prev_raw, eff_prev1, eff_prev2,
            ri_count, classes, i)
        then
          return i
        end
      end

      // No break — c1 joins the current word. Update state.
      match c1
      | WBExtend => None    // transparent
      | WBFormat => None    // transparent
      | WBZWJ    => None    // transparent (WB4)
      else
        eff_prev2 = eff_prev1
        eff_prev1 = c1
        if c1 is WBRegionalIndicator then
          ri_count = ri_count + 1
        else
          ri_count = 0
        end
      end
      raw_prev = c1
      i = i + 1
    end
    n  // reached end without a break

  fun _break_before(
    c1: WordBreak,
    prev_raw: WordBreak,
    eff_prev1: (WordBreak | None),
    eff_prev2: (WordBreak | None),
    ri_count: USize,
    classes: Array[WordBreak] box,
    pos: USize)
    : Bool
  =>
    """
    Decide whether to break before the codepoint at `pos` (whose
    class is `c1`). `prev_raw` is the actual previous class;
    `eff_prev1` / `eff_prev2` are the most recent non-transparent
    classes (None at start of word). `pos` and `classes` allow
    lookahead for WB6, WB7b, WB11, WB12.
    """
    // WB3: CR × LF
    if (prev_raw is WBCR) and (c1 is WBLF) then return false end
    // WB3a: (Newline | CR | LF) ÷
    if (prev_raw is WBNewline) or (prev_raw is WBCR)
      or (prev_raw is WBLF) then return true end
    // WB3b: ÷ (Newline | CR | LF)
    if (c1 is WBNewline) or (c1 is WBCR) or (c1 is WBLF) then
      return true
    end
    // WB3c: ZWJ × Extended_Pictographic
    if (prev_raw is WBZWJ) and (c1 is WBExtendedPictographic) then
      return false
    end
    // WB3d: WSegSpace × WSegSpace
    if (prev_raw is WBWSegSpace) and (c1 is WBWSegSpace) then
      return false
    end
    // WB4: × (Extend | Format | ZWJ)
    if (c1 is WBExtend) or (c1 is WBFormat) or (c1 is WBZWJ) then
      return false
    end

    // From here we use the effective previous (WB4 transparency).
    let p1 = eff_prev1
    let p2 = eff_prev2

    // WB5: AHLetter × AHLetter
    if _is_ahletter_opt(p1) and _is_ahletter(c1) then return false end
    // WB6: AHLetter × (MidLetter | MidNumLetQ) AHLetter (lookahead)
    if _is_ahletter_opt(p1) and _is_midletter_or_midnumletq(c1) then
      if _next_eff_ahletter(classes, pos + 1) then return false end
    end
    // WB7: AHLetter (MidLetter | MidNumLetQ) × AHLetter
    if _is_ahletter(c1)
      and _is_midletter_or_midnumletq_opt(p1)
      and _is_ahletter_opt(p2)
    then
      return false
    end
    // WB7a: Hebrew_Letter × Single_Quote
    if (p1 is WBHebrewLetter) and (c1 is WBSingleQuote) then return false end
    // WB7b: Hebrew_Letter × Double_Quote Hebrew_Letter (lookahead)
    if (p1 is WBHebrewLetter) and (c1 is WBDoubleQuote) then
      if _next_eff_hebrew(classes, pos + 1) then return false end
    end
    // WB7c: Hebrew_Letter Double_Quote × Hebrew_Letter
    if (c1 is WBHebrewLetter) and (p1 is WBDoubleQuote)
      and (p2 is WBHebrewLetter)
    then
      return false
    end
    // WB8: Numeric × Numeric
    if (p1 is WBNumeric) and (c1 is WBNumeric) then return false end
    // WB9: AHLetter × Numeric
    if _is_ahletter_opt(p1) and (c1 is WBNumeric) then return false end
    // WB10: Numeric × AHLetter
    if (p1 is WBNumeric) and _is_ahletter(c1) then return false end
    // WB11: Numeric (MidNum | MidNumLetQ) × Numeric
    if (c1 is WBNumeric) and _is_midnum_or_midnumletq_opt(p1)
      and (p2 is WBNumeric)
    then
      return false
    end
    // WB12: Numeric × (MidNum | MidNumLetQ) Numeric (lookahead)
    if (p1 is WBNumeric) and _is_midnum_or_midnumletq(c1) then
      if _next_eff_numeric(classes, pos + 1) then return false end
    end
    // WB13: Katakana × Katakana
    if (p1 is WBKatakana) and (c1 is WBKatakana) then return false end
    // WB13a: (AHLetter | Numeric | Katakana | ExtendNumLet) × ExtendNumLet
    if (c1 is WBExtendNumLet) and
      (_is_ahletter_opt(p1) or (p1 is WBNumeric)
        or (p1 is WBKatakana) or (p1 is WBExtendNumLet))
    then
      return false
    end
    // WB13b: ExtendNumLet × (AHLetter | Numeric | Katakana)
    if (p1 is WBExtendNumLet) and
      (_is_ahletter(c1) or (c1 is WBNumeric) or (c1 is WBKatakana))
    then
      return false
    end
    // WB15/WB16: pair Regional_Indicators (odd RI run keeps pair open)
    if (c1 is WBRegionalIndicator) and (p1 is WBRegionalIndicator) then
      if (ri_count % 2) == 1 then return false end
    end
    // WB999
    true

  fun _is_ahletter(c: WordBreak): Bool =>
    (c is WBALetter) or (c is WBHebrewLetter)

  fun _is_ahletter_opt(c: (WordBreak | None)): Bool =>
    match c
    | let cc: WordBreak => _is_ahletter(cc)
    else false
    end

  fun _is_midletter_or_midnumletq(c: WordBreak): Bool =>
    (c is WBMidLetter) or (c is WBMidNumLet) or (c is WBSingleQuote)

  fun _is_midletter_or_midnumletq_opt(c: (WordBreak | None)): Bool =>
    match c
    | let cc: WordBreak => _is_midletter_or_midnumletq(cc)
    else false
    end

  fun _is_midnum_or_midnumletq(c: WordBreak): Bool =>
    (c is WBMidNum) or (c is WBMidNumLet) or (c is WBSingleQuote)

  fun _is_midnum_or_midnumletq_opt(c: (WordBreak | None)): Bool =>
    match c
    | let cc: WordBreak => _is_midnum_or_midnumletq(cc)
    else false
    end

  fun _next_eff(
    classes: Array[WordBreak] box, start: USize)
    : (WordBreak | None)
  =>
    """
    The next non-transparent (non-Extend/Format/ZWJ) class at or
    after `start`, or None if none remains.
    """
    var i: USize = start
    let n = classes.size()
    while i < n do
      try
        let c = classes(i)?
        if (not (c is WBExtend)) and (not (c is WBFormat))
          and (not (c is WBZWJ))
        then
          return c
        end
      end
      i = i + 1
    end
    None

  fun _next_eff_ahletter(
    classes: Array[WordBreak] box, start: USize)
    : Bool
  =>
    _is_ahletter_opt(_next_eff(classes, start))

  fun _next_eff_hebrew(
    classes: Array[WordBreak] box, start: USize)
    : Bool
  =>
    match _next_eff(classes, start)
    | WBHebrewLetter => true
    else false
    end

  fun _next_eff_numeric(
    classes: Array[WordBreak] box, start: USize)
    : Bool
  =>
    match _next_eff(classes, start)
    | WBNumeric => true
    else false
    end

  fun _decode(bytes: String box, offset: USize): (U32, USize) ? =>
    let b0 = bytes(offset)?
    if b0 < 0x80 then
      (U32.from[U8](b0), USize(1))
    elseif b0 < 0xE0 then
      let b1 = bytes(offset + 1)?
      let cp = ((U32.from[U8](b0) and 0x1F) << 6)
        or (U32.from[U8](b1) and 0x3F)
      (cp, USize(2))
    elseif b0 < 0xF0 then
      let b1 = bytes(offset + 1)?
      let b2 = bytes(offset + 2)?
      let cp = ((U32.from[U8](b0) and 0x0F) << 12)
        or ((U32.from[U8](b1) and 0x3F) << 6)
        or (U32.from[U8](b2) and 0x3F)
      (cp, USize(3))
    else
      let b1 = bytes(offset + 1)?
      let b2 = bytes(offset + 2)?
      let b3 = bytes(offset + 3)?
      let cp = ((U32.from[U8](b0) and 0x07) << 18)
        or ((U32.from[U8](b1) and 0x3F) << 12)
        or ((U32.from[U8](b2) and 0x3F) << 6)
        or (U32.from[U8](b3) and 0x3F)
      (cp, USize(4))
    end
