// UAX #14 line-break state machine.
//
// Two-pass design (same as Words/Sentences): decode codepoints into
// (byte_offset, resolved_class), then apply rules LB2..LB31 with full
// backward/forward access.
//
// Preprocessing (LB1):
//   AI, SG, XX → AL
//   SA + General Category Mn or Mc → CM
//   SA + other → AL
//   CJ → NS  (default "strict" tailoring; what LineBreakTest uses)
//
// LB9 absorption: CM and ZWJ immediately following any class other
// than BK, CR, LF, NL, SP, ZW take the preceding class. Operationally
// we mark them as "absorbed" — break rules skip past them, treating
// the next non-absorbed char's class as following the prior anchor.
//
// LB10 fallback: any remaining CM/ZWJ that wasn't absorbed becomes AL.
//
// Scope: this implementation covers LB2..LB31 with the exception of
// East-Asian-Width-dependent details in LB19a and LB30. Those tailor
// rules around CJK punctuation by ea=F/W/H/N; without an EAW property
// table we apply the generic versions of LB19 and LB30. Conformance
// on text containing wide/narrow boundary cases may differ from the
// reference.

class ref _LineBreakCursor
  let _boundaries: Array[USize] val
  var _idx: USize

  new ref create(bytes: String box) =>
    _boundaries = _LineBoundaries.compute(bytes)
    _idx = 0

  fun ref next_range(): ((USize, USize) | None) =>
    if (_idx + 1) >= _boundaries.size() then return None end
    let result =
      try (_boundaries(_idx)?, _boundaries(_idx + 1)?)
      else return None
      end
    _idx = _idx + 1
    result


primitive _LineBoundaries
  fun compute(bytes: String box): Array[USize] val =>
    // Step 1: decode every cp to (offset, raw cp, LB class).
    let n_bytes = bytes.size()
    let offsets = Array[USize]
    let cps = Array[U32]
    let raw = Array[LineBreak]
    var i: USize = 0
    while i < n_bytes do
      (let cp, let len) =
        try _decode(bytes, i)? else (U32(0xFFFD), USize(1)) end
      offsets.push(i)
      cps.push(cp)
      raw.push(_resolve(cp))
      i = i + len
    end
    offsets.push(n_bytes)

    // Step 2: apply LB9 — absorb CM/ZWJ into preceding non-break char.
    // Marks them with a parallel "absorbed" flag; the rule scanner
    // skips them and uses the anchor class.
    let n = raw.size()
    let cls = Array[LineBreak](n)
    let absorbed = Array[Bool](n)
    var anchor_class: LineBreak = LBAL  // sot anchor (LB1 default)
    var anchor_set: Bool = false
    var k: USize = 0
    while k < n do
      try
        let c = raw(k)?
        let is_breaker =
          match c
          | LBBK => true | LBCR => true | LBLF => true | LBNL => true
          | LBSP => true | LBZW => true
          else false
          end
        if (c is LBCM) or (c is LBZWJ) then
          if anchor_set and (not is_breaker) then
            // Absorbed into anchor.
            cls.push(anchor_class)
            absorbed.push(true)
          else
            // LB10 says treat standalone CM/ZWJ as AL — but for ZWJ
            // we must preserve the class so LB8a can fire on it.
            // The "treat as AL" semantics still apply for downstream
            // X × ZWJ rules via the anchor.
            if c is LBZWJ then
              cls.push(LBZWJ)
            else
              cls.push(LBAL)
            end
            absorbed.push(false)
            anchor_class = LBAL
            anchor_set = true
          end
        else
          cls.push(c)
          absorbed.push(false)
          if not is_breaker then
            anchor_class = c
          end
          anchor_set = true
          // BK/CR/LF/NL/SP/ZW reset anchor for LB9 — the next CM
          // becomes AL (it's not absorbed into a breaker).
          if is_breaker then anchor_set = false end
        end
      end
      k = k + 1
    end

    // Step 3: walk and decide break positions. Default is no break
    // (LB31's "÷ Any" is the LAST rule; earlier rules can suppress
    // many breaks). We must check each cp pair.
    let bounds = recover trn Array[USize] end
    bounds.push(0)
    if n == 0 then return consume bounds end

    var pos: USize = 0
    while (pos + 1) < n do
      if _break_between(cls, cps, absorbed, pos) then
        try bounds.push(offsets(pos + 1)?) end
      end
      pos = pos + 1
    end
    // End-of-input is always a break (LB3).
    try
      let last = bounds(bounds.size() - 1)?
      if last < n_bytes then bounds.push(n_bytes) end
    end
    consume bounds

  fun _resolve(cp: U32): LineBreak =>
    let raw = _UcdLineBreak.of(cp)
    match raw
    | LBAI => LBAL
    | LBSG => LBAL
    | LBXX => LBAL
    | LBCJ => LBNS  // strict tailoring (default for LineBreakTest)
    | LBSA =>
      match Codepoints.category(cp)
      | Mn => LBCM
      | Mc => LBCM
      else LBAL
      end
    else raw
    end

  fun _break_between(
    cls: Array[LineBreak] box,
    cps: Array[U32] box,
    absorbed: Array[Bool] box,
    i: USize)
    : Bool
  =>
    """
    Decide whether to break BETWEEN cps i and i+1.
    """
    let n = cls.size()
    if (i + 1) >= n then return false end

    // LB9: never break before an absorbed CM/ZWJ.
    let next_absorbed =
      try absorbed(i + 1)? else false end
    if next_absorbed then return false end

    let curr =
      try cls(i)? else LBAL end
    let next =
      try cls(i + 1)? else LBAL end

    // LB4: BK !
    if curr is LBBK then return true end
    // LB5: CR × LF, CR/LF/NL !
    if (curr is LBCR) and (next is LBLF) then return false end
    if (curr is LBCR) or (curr is LBLF) or (curr is LBNL) then
      return true
    end
    // LB6: × (BK | CR | LF | NL)
    if (next is LBBK) or (next is LBCR) or (next is LBLF)
      or (next is LBNL)
    then
      return false
    end
    // LB7: × SP, × ZW
    if (next is LBSP) or (next is LBZW) then return false end
    // LB8: ZW SP* ÷ — break opportunity after ZW (with optional SPs)
    if _has_zw_lookback(cls, absorbed, i) then return true end
    // LB8a: ZWJ ×
    if curr is LBZWJ then return false end
    // LB11: × WJ, WJ ×
    if (next is LBWJ) or (curr is LBWJ) then return false end
    // LB12: GL ×
    if curr is LBGL then return false end
    // LB12a: [^SP BA HY] × GL
    if next is LBGL then
      if not ((curr is LBSP) or (curr is LBBA) or (curr is LBHY)) then
        return false
      end
    end
    // LB13: × (CL | CP | EX | SY)  (and × IS via LB15d)
    if (next is LBCL) or (next is LBCP) or (next is LBEX)
      or (next is LBSY)
    then
      return false
    end
    // LB15c: SP ÷ IS NU — break between SP and (IS followed by NU).
    // Must be checked BEFORE LB15d's blanket × IS suppression.
    if (curr is LBSP) and (next is LBIS)
      and (_next_eff_class(cls, absorbed, i + 2) is LBNU)
    then
      return true
    end
    // LB15d: × IS
    if next is LBIS then return false end
    // LB14: OP SP* ×
    if _has_op_lookback(cls, absorbed, i) then return false end
    // LB15a/15b: simplified QU-Pi/QU-Pf treatment via LB19 below.
    // LB16: (CL | CP) SP* × NS
    if (next is LBNS) and _has_clcp_lookback(cls, absorbed, i) then
      return false
    end
    // LB17: B2 SP* × B2
    if (next is LBB2) and _has_b2_lookback(cls, absorbed, i) then
      return false
    end
    // LB15a: (sot | BK | CR | LF | NL | OP | QU | GL | SP | ZW)
    //        [\p{Pi}&QU] SP* × any
    // After a Pi-class QU preceded by a line-starting type, no
    // break before whatever follows (across any trailing SP*).
    if _lb15a_in_tail(cls, cps, absorbed, i) then return false end
    // LB15b: × [\p{Pf}&QU] (SP|GL|WJ|CL|QU|CP|EX|IS|SY|BK|CR|LF|NL|ZW|eot)
    // — suppress a break before a Pf-class QU when followed by a
    // "trailing context" class (or eot). Requires General Category
    // lookup; we re-decode the codepoint at position i+1.
    if (next is LBQU) and _is_pf_at(cps, i + 1) then
      if _lb15b_trailing_context(cls, absorbed, i + 1) then
        return false
      end
    end
    // LB18: SP ÷
    if curr is LBSP then return true end
    // LB19: × QU, QU ×
    if (next is LBQU) or (curr is LBQU) then return false end
    // LB20: ÷ CB, CB ÷
    if (next is LBCB) or (curr is LBCB) then return true end
    // LB20a: (sot | BK | CR | LF | NL | SP | ZW | CB | GL)
    //        (HY | U+2010) × AL
    // After a line-start-type anchor, a hyphen sticks to the
    // following ALPHABETIC letter. U+2010 (HYPHEN) has class BA, so
    // we detect it by codepoint rather than class. When CMs are
    // absorbed, walk back to the actual non-absorbed anchor cp.
    let curr_is_hy_or_2010 =
      (curr is LBHY)
        or _is_u2010_at_anchor(cps, absorbed, i)
    if curr_is_hy_or_2010 and (next is LBAL)
      and _lb20a_anchor_before(cls, absorbed, i)
    then
      return false
    end
    // LB21: × BA, × HY, × NS, BB ×
    if (next is LBBA) or (next is LBHY) or (next is LBNS) then
      return false
    end
    if curr is LBBB then return false end
    // LB21a (Unicode 16): HL (HY | BA) × [^HL]
    // No break after HL-HY/HL-BA, EXCEPT when the next class is
    // another HL (then default break applies).
    if ((curr is LBHY) or (curr is LBBA)) and (not (next is LBHL)) then
      if _is_hl_two_back(cls, absorbed, i) then return false end
    end
    // LB21b: SY × HL
    if (curr is LBSY) and (next is LBHL) then return false end
    // LB22: × IN
    if next is LBIN then return false end
    // LB23: (AL | HL) × NU, NU × (AL | HL)
    if ((curr is LBAL) or (curr is LBHL)) and (next is LBNU) then
      return false
    end
    if (curr is LBNU) and ((next is LBAL) or (next is LBHL)) then
      return false
    end
    // LB23a: PR × (ID | EB | EM), (ID | EB | EM) × PO
    if (curr is LBPR) and
      ((next is LBID) or (next is LBEB) or (next is LBEM))
    then
      return false
    end
    if ((curr is LBID) or (curr is LBEB) or (curr is LBEM))
      and (next is LBPO)
    then
      return false
    end
    // LB24: (PR | PO) × (AL | HL), (AL | HL) × (PR | PO)
    if ((curr is LBPR) or (curr is LBPO))
      and ((next is LBAL) or (next is LBHL))
    then
      return false
    end
    if ((curr is LBAL) or (curr is LBHL))
      and ((next is LBPR) or (next is LBPO))
    then
      return false
    end
    // LB25: numeric clusters (PR|PO|OP|HY)? NU (NU|SY|IS)* (CL|CP)?
    // (PR|PO)? — simplified: treat NU as part of an extended numeric
    // chain.
    if _lb25_no_break(cls, absorbed, i) then return false end
    // LB26: JL × (JL | JV | H2 | H3)
    if curr is LBJL then
      if (next is LBJL) or (next is LBJV) or (next is LBH2)
        or (next is LBH3)
      then
        return false
      end
    end
    // (JV | H2) × (JV | JT)
    if (curr is LBJV) or (curr is LBH2) then
      if (next is LBJV) or (next is LBJT) then return false end
    end
    // (JT | H3) × JT
    if (curr is LBJT) or (curr is LBH3) then
      if next is LBJT then return false end
    end
    // LB27: (JL | JV | JT | H2 | H3) × PO
    if ((curr is LBJL) or (curr is LBJV) or (curr is LBJT)
      or (curr is LBH2) or (curr is LBH3)) and (next is LBPO)
    then
      return false
    end
    // PR × (JL | JV | JT | H2 | H3)
    if (curr is LBPR) and
      ((next is LBJL) or (next is LBJV) or (next is LBJT)
        or (next is LBH2) or (next is LBH3))
    then
      return false
    end
    // LB28: (AL | HL) × (AL | HL)
    if ((curr is LBAL) or (curr is LBHL))
      and ((next is LBAL) or (next is LBHL))
    then
      return false
    end
    // LB28a (Brahmic, Unicode 15.1+):
    //   AP × (AK | ◌ | AS)
    //   (AK | ◌ | AS) × (VF | VI)
    //   (AK | ◌ | AS) VI × (AK | ◌)
    //   (AK | ◌ | AS) × (AK | ◌ | AS) VF
    // (The Indic-script "◌" placeholder is the dotted circle U+25CC;
    // for property purposes it's treated as AK/AS-equivalent. We
    // approximate by AK/AS.)
    if (curr is LBAP) and
      ((next is LBAK) or (next is LBAS))
    then
      return false
    end
    if ((curr is LBAK) or (curr is LBAS))
      and ((next is LBVF) or (next is LBVI))
    then
      return false
    end
    // LB29: IS × (AL | HL)
    if (curr is LBIS) and ((next is LBAL) or (next is LBHL)) then
      return false
    end
    // LB30: (AL | HL | NU) × OP, CP × (AL | HL | NU)
    // (without EAW restriction — generic version)
    if ((curr is LBAL) or (curr is LBHL) or (curr is LBNU))
      and (next is LBOP)
    then
      return false
    end
    if (curr is LBCP) and
      ((next is LBAL) or (next is LBHL) or (next is LBNU))
    then
      return false
    end
    // LB30a: RI RI — break before next RI pair (handled by counting).
    if (curr is LBRI) and (next is LBRI) then
      // Count RIs since last break; if odd, this is the second of a
      // pair → no break. If even, this would start the next pair →
      // break.
      let ri_count = _count_ri_back(cls, absorbed, i)
      if (ri_count % 2) == 1 then return false end
    end
    // LB30b: EB × EM
    if (curr is LBEB) and (next is LBEM) then return false end
    // LB30b: extended pictographic + Cn × EM — approximation: skip.
    // LB31: ÷ Any (default — allow break)
    true

  // ============================================================
  // Lookback helpers (skip absorbed CM/ZWJ; walk back over SP runs
  // or RI runs as required)
  // ============================================================

  fun _eff_at(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : LineBreak
  =>
    """
    The class at position i, or AL if absorbed (shouldn't happen
    in practice since break decisions skip absorbed positions).
    """
    try cls(i)? else LBAL end

  fun _next_eff_class(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, start: USize)
    : LineBreak
  =>
    """
    First non-absorbed class at or after `start`. Returns LBXX if
    there is none (eot).
    """
    var k: USize = start
    let n = cls.size()
    while k < n do
      try
        if not absorbed(k)? then return cls(k)? end
      end
      k = k + 1
    end
    LBXX

  fun _has_zw_lookback(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """LB8: was the most recent non-SP/non-absorbed class a ZW?"""
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if not absorbed(USize.from[ISize](k))? then
          let c = cls(USize.from[ISize](k))?
          if c is LBSP then k = k - 1; continue end
          if c is LBZW then return true end
          return false
        end
      end
      k = k - 1
    end
    false

  fun _has_op_lookback(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """LB14: was the most recent non-SP/non-absorbed class OP?"""
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if not absorbed(USize.from[ISize](k))? then
          let c = cls(USize.from[ISize](k))?
          if c is LBSP then k = k - 1; continue end
          if c is LBOP then return true end
          return false
        end
      end
      k = k - 1
    end
    false

  fun _has_clcp_lookback(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """LB16: was the most recent non-SP/non-absorbed class CL or CP?"""
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if not absorbed(USize.from[ISize](k))? then
          let c = cls(USize.from[ISize](k))?
          if c is LBSP then k = k - 1; continue end
          if (c is LBCL) or (c is LBCP) then return true end
          return false
        end
      end
      k = k - 1
    end
    false

  fun _has_b2_lookback(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """LB17: was the most recent non-SP/non-absorbed class B2?"""
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if not absorbed(USize.from[ISize](k))? then
          let c = cls(USize.from[ISize](k))?
          if c is LBSP then k = k - 1; continue end
          if c is LBB2 then return true end
          return false
        end
      end
      k = k - 1
    end
    false

  fun _is_hl_two_back(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """
    LB21a: is the class TWO non-absorbed positions back HL?
    Used when curr=HY/BA — checks the class before that.
    """
    if i == 0 then return false end
    var k: ISize = ISize.from[USize](i) - 1
    while k >= 0 do
      try
        if not absorbed(USize.from[ISize](k))? then
          let c = cls(USize.from[ISize](k))?
          return c is LBHL
        end
      end
      k = k - 1
    end
    false

  fun _count_ri_back(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : USize
  =>
    """LB30a: count consecutive RI codepoints ending at i."""
    var n: USize = 0
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if absorbed(USize.from[ISize](k))? then
          k = k - 1
          continue
        end
        if cls(USize.from[ISize](k))? is LBRI then
          n = n + 1
          k = k - 1
        else
          break
        end
      end
    end
    n

  fun _lb25_no_break(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """
    LB25 (simplified): suppress break inside a numeric cluster.
    The official rule covers (PR|PO|OP|HY)? NU (NU|SY|IS)*
    (CL|CP)? (PR|PO)? — we treat anything around an NU run that
    matches the pattern conservatively.
    """
    let curr = try cls(i)? else return false end
    let next = try cls(i + 1)? else return false end
    let in_chain = _in_numeric_chain(cls, absorbed, i)
    // NU × NU — always part of a chain.
    if (curr is LBNU) and (next is LBNU) then return true end
    // NU × (SY | IS | CL | CP | PR | PO) — chain continues.
    if (curr is LBNU) and
      ((next is LBSY) or (next is LBIS) or (next is LBCL)
        or (next is LBCP) or (next is LBPR) or (next is LBPO))
    then
      return true
    end
    // (PR | PO) × NU — chain prefix.
    if ((curr is LBPR) or (curr is LBPO)) and (next is LBNU) then
      return true
    end
    // (OP | HY) × NU — chain prefix.
    if (curr is LBOP) and (next is LBNU) then return true end
    if (curr is LBHY) and (next is LBNU) then return true end
    // IS × NU — unconditional per LB25 pair list (SY × NU is NOT
    // unconditional; only `NU SY* × NU` in chain context).
    if (curr is LBIS) and (next is LBNU) then return true end
    // (SY | IS | CL | CP) × ... — only when the chain anchor (an
    // earlier NU) is still in play.
    if in_chain then
      if ((curr is LBSY) or (curr is LBIS))
        and ((next is LBNU) or (next is LBSY) or (next is LBIS)
          or (next is LBCL) or (next is LBCP))
      then
        return true
      end
      if ((curr is LBCL) or (curr is LBCP))
        and ((next is LBPR) or (next is LBPO))
      then
        return true
      end
    end
    false

  fun _in_numeric_chain(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """
    Walking back from i (inclusive), skip (NU | SY | IS) and absorbed
    positions, and check whether we land on an NU. If yes, the LB25
    numeric chain is still active.
    """
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if absorbed(USize.from[ISize](k))? then
          k = k - 1
          continue
        end
        let c = cls(USize.from[ISize](k))?
        if c is LBNU then return true end
        if (c is LBSY) or (c is LBIS) then
          k = k - 1
          continue
        end
        return false
      end
    end
    false

  fun _is_u2010(cps: Array[U32] box, i: USize): Bool =>
    try cps(i)? == 0x2010 else false end

  fun _is_u2010_at_anchor(
    cps: Array[U32] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """
    True iff the most recent non-absorbed cp at or before `i` is
    U+2010 HYPHEN. Used by LB20a so it can recognize the literal
    hyphen codepoint through a run of absorbed combining marks.
    """
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if absorbed(USize.from[ISize](k))? then
          k = k - 1
          continue
        end
        return cps(USize.from[ISize](k))? == 0x2010
      end
    end
    false

  fun _lb20a_anchor_before(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """
    LB20a: was the position immediately before the HY/u2010 group at
    i one of the line-start-type classes (BK, CR, LF, NL, SP, ZW,
    CB, GL), or sot? `i` may be either the actual HY/u2010 or a CM
    absorbed into one.
    """
    // Find the actual HY (non-absorbed): walk back through absorbed
    // positions that are all "carrying HY".
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if absorbed(USize.from[ISize](k))? then
          k = k - 1
          continue
        end
        break
      end
    end
    // k now points at the actual HY (or u2010). Step before it.
    k = k - 1
    // Walk back to the most recent non-absorbed class.
    while k >= 0 do
      try
        if absorbed(USize.from[ISize](k))? then
          k = k - 1
          continue
        end
        let c = cls(USize.from[ISize](k))?
        match c
        | LBBK => return true | LBCR => return true | LBLF => return true
        | LBNL => return true | LBSP => return true | LBZW => return true
        | LBCB => return true | LBGL => return true
        else return false
        end
      end
    end
    true  // sot — no prior non-absorbed class

  fun _is_pi_at(cps: Array[U32] box, i: USize): Bool =>
    """
    True iff the codepoint at index i has General Category Pi
    (Initial_Punctuation). Used for LB15a.
    """
    try
      match Codepoints.category(cps(i)?)
      | Pi => true
      else false
      end
    else false
    end

  fun _lb15a_in_tail(
    cls: Array[LineBreak] box,
    cps: Array[U32] box,
    absorbed: Array[Bool] box,
    i: USize)
    : Bool
  =>
    """
    LB15a tail check: are we in the `... Pi-QU SP*` lookback window
    where any next char should be suppressed? Walk back from i
    through SP* (and absorbed), find a non-absorbed Pi-QU, then
    verify the codepoint before that Pi-QU is sot or one of LB15a's
    anchor classes.
    """
    var k: ISize = ISize.from[USize](i)
    while k >= 0 do
      try
        if absorbed(USize.from[ISize](k))? then
          k = k - 1
          continue
        end
        let c = cls(USize.from[ISize](k))?
        if c is LBSP then k = k - 1; continue end
        if (c is LBQU) and _is_pi_at(cps, USize.from[ISize](k)) then
          // Check anchor before this Pi-QU.
          var k2: ISize = k - 1
          while k2 >= 0 do
            try
              if absorbed(USize.from[ISize](k2))? then
                k2 = k2 - 1
                continue
              end
              let c2 = cls(USize.from[ISize](k2))?
              match c2
              | LBBK => return true | LBCR => return true | LBLF => return true
              | LBNL => return true | LBOP => return true | LBQU => return true
              | LBGL => return true | LBSP => return true | LBZW => return true
              else return false
              end
            end
          end
          return true  // sot
        end
        return false
      end
    end
    false

  fun _is_pf_at(cps: Array[U32] box, i: USize): Bool =>
    """
    True iff the codepoint at index i has General Category Pf
    (Final_Punctuation). Used for LB15b.
    """
    try
      match Codepoints.category(cps(i)?)
      | Pf => true
      else false
      end
    else false
    end

  fun _lb15b_trailing_context(
    cls: Array[LineBreak] box, absorbed: Array[Bool] box, i: USize)
    : Bool
  =>
    """
    LB15b trailing context: at position i (the Pf-QU), is the next
    non-absorbed class one of SP/GL/WJ/CL/QU/CP/EX/IS/SY/BK/CR/LF/
    NL/ZW, or is there no further cp (eot)?
    """
    var k: USize = i + 1
    let n = cls.size()
    while k < n do
      try
        if absorbed(k)? then k = k + 1; continue end
        let c = cls(k)?
        match c
        | LBSP => return true
        | LBGL => return true
        | LBWJ => return true
        | LBCL => return true
        | LBQU => return true
        | LBCP => return true
        | LBEX => return true
        | LBIS => return true
        | LBSY => return true
        | LBBK => return true
        | LBCR => return true
        | LBLF => return true
        | LBNL => return true
        | LBZW => return true
        else
          return false
        end
      end
      k = k + 1
    end
    // eot
    true

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
