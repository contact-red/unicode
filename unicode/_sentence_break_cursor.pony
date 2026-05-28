// UAX #29 sentence-boundary state machine.
//
// Sentences break by DEFAULT only at the rule-specified positions
// (SB4 paragraph separators, SB11 end-of-sentence-terminator). Every
// other rule (SB6..SB10, SB8a) says "do NOT break" — they suppress
// the SB11 break in specific local contexts.
//
// Two-pass design (same as `_WordBreakCursor`): decode codepoints into
// (offset, class), then apply rules with full backward + forward
// scanning available. SB7 needs a 2-step lookback, SB8 needs a
// potentially long forward scan past Close/Sp/transparent chars
// looking for Lower.
//
// Definitions:
//   ParaSep = Sep | CR | LF
//   SATerm  = STerm | ATerm

class ref _SentenceBreakCursor
  let _boundaries: Array[USize] val
  var _idx: USize

  new ref create(bytes: String box) =>
    _boundaries = _SentenceBoundaries.compute(bytes)
    _idx = 0

  fun ref next_range(): ((USize, USize) | None) =>
    if (_idx + 1) >= _boundaries.size() then return None end
    let result =
      try (_boundaries(_idx)?, _boundaries(_idx + 1)?)
      else return None
      end
    _idx = _idx + 1
    result


primitive _SentenceBoundaries
  fun compute(bytes: String box): Array[USize] val =>
    let n_bytes = bytes.size()
    let offsets = Array[USize]
    let classes = Array[SentenceBreak]
    var i: USize = 0
    while i < n_bytes do
      (let cp, let len) =
        try _decode(bytes, i)? else (U32(0xFFFD), USize(1)) end
      offsets.push(i)
      classes.push(_UcdSentenceBreak.of(cp))
      i = i + len
    end
    offsets.push(n_bytes)
    let n_cps = classes.size()

    let bounds = recover trn Array[USize] end
    bounds.push(0)
    if n_cps == 0 then return consume bounds end

    // Walk through; emit boundary positions after each rule-detected
    // break. The boundary is in `offsets` index space.
    var pos: USize = 0
    while pos < n_cps do
      // Decide: is there a break BETWEEN pos and pos+1?
      let break_here = _break_after(classes, pos)
      if break_here then
        try bounds.push(offsets(pos + 1)?) end
      end
      pos = pos + 1
    end
    // Final sentence ends at end-of-input.
    try
      let last = bounds(bounds.size() - 1)?
      if last < n_bytes then bounds.push(n_bytes) end
    end
    consume bounds

  fun _break_after(classes: Array[SentenceBreak] box, i: USize): Bool =>
    """
    Decide whether to break BETWEEN codepoint `i` and `i+1`.
    Returns false if `i` is the last cp (caller adds end-of-input
    boundary separately).
    """
    let n = classes.size()
    if (i + 1) >= n then return false end
    let curr =
      try classes(i)? else SBOther end
    let next =
      try classes(i + 1)? else SBOther end

    // SB3: CR × LF — no break between CR and LF.
    if (curr is SBCR) and (next is SBLF) then return false end

    // SB4: ParaSep ÷ — break after Sep, CR, LF.
    if (curr is SBSep) or (curr is SBCR) or (curr is SBLF) then
      return true
    end

    // SB5: × (Extend | Format) — never break before Extend/Format.
    if (next is SBExtend) or (next is SBFormat) then return false end

    // From here, find the "effective current" — walk back from i past
    // Extend/Format until we find the most recent non-transparent
    // class. Also collect lookback context for SB6..SB11.
    let eff_curr = _eff_at(classes, i)

    // SB6: ATerm × Numeric
    if (eff_curr is SBATerm) and (next is SBNumeric) then return false end

    // SB7: (Upper | Lower) ATerm × Upper
    if (eff_curr is SBATerm) and (next is SBUpper) then
      match _eff_before(classes, i)
      | SBUpper => return false
      | SBLower => return false
      end
    end

    // For SB8..SB11 we need to know whether there is a recent
    // "SATerm Close* Sp*" pattern that ends at `i`. _saterm_lookback
    // returns (have, saterm_class) where `have` indicates the chain
    // is present right up to `i` (inclusive of Sp* trailing chars).
    (let have_chain, let sat_class, let last_in_chain) =
      _saterm_lookback(classes, i)

    if have_chain then
      // SB8a: SATerm Close* Sp* × (SContinue | SATerm)
      if (next is SBSContinue) or (next is SBSTerm)
        or (next is SBATerm)
      then
        return false
      end

      // SB8: ATerm Close* Sp* × (¬OLetter ¬Upper ¬Lower ¬ParaSep
      //                           ¬SATerm)* Lower
      // (only ATerm — not STerm — triggers SB8 lookahead)
      if sat_class is SBATerm then
        if _sb8_forward_lower(classes, i + 1) then return false end
      end

      // SB9: SATerm Close* × (Close | Sp | ParaSep)
      // SB10: SATerm Close* Sp* × (Sp | ParaSep)
      // SB11: SATerm Close* Sp* ParaSep? ÷
      //
      // SB9 applies only while the chain is still in its "Close*"
      // phase (no Sp yet). SB10 applies once at least one Sp has
      // appeared, and is more restrictive (no Close allowed). The
      // `last_in_chain` value tells us which phase we're in:
      //   SATerm  → no Close, no Sp yet (SB9 applies)
      //   Close   → still in Close* phase (SB9 applies)
      //   Sp      → in Sp* phase (SB10 applies; Close would BREAK)
      // ParaSep handling falls through to SB4 elsewhere.
      let in_sp_phase = last_in_chain is SBSp
      if in_sp_phase then
        // SB10: only Sp or ParaSep can extend.
        if (next is SBSp) or (next is SBSep)
          or (next is SBCR) or (next is SBLF)
        then
          return false
        end
      else
        // SB9: Close, Sp, or ParaSep extend.
        if (next is SBClose) or (next is SBSp)
          or (next is SBSep) or (next is SBCR) or (next is SBLF)
        then
          return false
        end
      end
      // SB11: chain ended, next char is not chain-extending → break.
      return true
    end

    // SB998: otherwise no break.
    false

  fun _eff_at(
    classes: Array[SentenceBreak] box, i: USize): SentenceBreak
  =>
    """
    Walk back from `i` (inclusive) skipping Extend/Format; return
    the most recent non-transparent class. If `i` is itself
    non-transparent, return its class.
    """
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        let c = classes(USize.from[ISize](k))?
        if (not (c is SBExtend)) and (not (c is SBFormat)) then
          return c
        end
      end
      k = k - 1
    end
    SBOther

  fun _eff_before(
    classes: Array[SentenceBreak] box, i: USize)
    : (SentenceBreak | None)
  =>
    """
    The most recent non-transparent class STRICTLY BEFORE the
    effective class at `i`. Used by SB7 to peek past the ATerm.
    """
    // First, find the effective `i` — walk back past any X first.
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        let c = classes(USize.from[ISize](k))?
        if (not (c is SBExtend)) and (not (c is SBFormat)) then break end
      end
      k = k - 1
    end
    k = k - 1
    // Then walk back again to find the next non-X class.
    while k >= 0 do
      try
        let c = classes(USize.from[ISize](k))?
        if (not (c is SBExtend)) and (not (c is SBFormat)) then
          return c
        end
      end
      k = k - 1
    end
    None

  fun _saterm_lookback(classes: Array[SentenceBreak] box, i: USize)
    : (Bool, SentenceBreak, SentenceBreak)
  =>
    """
    Walk back from `i` (effective view, ignoring Extend/Format). The
    chain pattern is `SATerm Close* Sp*` — we should currently be in
    Sp*, Close*, or just SATerm. Returns (have_chain, saterm_class,
    last_class_in_chain). If no chain is in flight, returns
    (false, SBOther, SBOther).
    """
    var k: ISize = ISize.from[USize](i)
    var last_in_chain: SentenceBreak = SBOther
    var seen_first: Bool = false
    // Pass 1: skip trailing Sp* (effective).
    while k >= 0 do
      try
        let c = classes(USize.from[ISize](k))?
        if (c is SBExtend) or (c is SBFormat) then
          k = k - 1
          continue
        end
        if not seen_first then last_in_chain = c; seen_first = true end
        if c is SBSp then k = k - 1; continue end
        break
      end
    end
    // Pass 2: skip Close* (effective).
    while k >= 0 do
      try
        let c = classes(USize.from[ISize](k))?
        if (c is SBExtend) or (c is SBFormat) then
          k = k - 1
          continue
        end
        if c is SBClose then k = k - 1; continue end
        break
      end
    end
    // Pass 3: must be SATerm.
    while k >= 0 do
      try
        let c = classes(USize.from[ISize](k))?
        if (c is SBExtend) or (c is SBFormat) then
          k = k - 1
          continue
        end
        if (c is SBATerm) or (c is SBSTerm) then
          return (true, c, last_in_chain)
        end
        break
      end
    end
    (false, SBOther, SBOther)

  fun _sb8_forward_lower(
    classes: Array[SentenceBreak] box, start: USize): Bool
  =>
    """
    Walk forward from `start` skipping (¬OLetter ¬Upper ¬Lower
    ¬ParaSep ¬SATerm)*. Returns true if a Lower is reached without
    crossing one of the "terminator" classes. Per SB8.
    """
    let n = classes.size()
    var k: USize = start
    while k < n do
      try
        let c = classes(k)?
        // Extend/Format always skipped (transparency).
        if (c is SBExtend) or (c is SBFormat) then
          k = k + 1
          continue
        end
        // Lower → found, suppress break.
        if c is SBLower then return true end
        // Terminator: stop.
        if (c is SBOLetter) or (c is SBUpper) or (c is SBSep)
          or (c is SBCR) or (c is SBLF)
          or (c is SBATerm) or (c is SBSTerm)
        then
          return false
        end
        // Anything else (Close, Sp, Numeric, SContinue, Other) →
        // keep scanning.
        k = k + 1
      end
    end
    false

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
