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
// Scope: covers LB2..LB31 of UAX #14 (Unicode 16), including the
// East-Asian-Width-dependent tailoring in LB19/19a, LB21a, and LB30
// (excluded set $EastAsian = ea ∈ {F, W, H}), plus the Brahmic LB28a
// orthographic-syllable rules including the dotted-circle (U+25CC)
// placeholder, and LB30b's extended-pictographic ∩ Cn × EM clause.

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
    // LB19 (Unicode 16): × [QU-Pi], [QU-Pf] ×
    // Plus LB19a: unless surrounded by East Asian, do not break either
    // side of any QU. East-Asian set = ea ∈ {F, W, H}.
    if next is LBQU then
      // LB19 .01 — × [QU-Pi]: suppress break before any QU that is
      // NOT Initial-Punctuation.
      if not _is_pi_at(cps, i + 1) then return false end
      // LB19a (Pi-QU branch). Suppress when prev cp is non-EA OR when
      // the cp after QU is non-EA / eot.
      if not _is_east_asian_eff_at(cps, absorbed, i) then return false end
      if not _is_east_asian_eff_after(cps, absorbed, i + 2) then
        return false
      end
      // Surrounded by East Asian — allow break (LB31 default).
    end
    if curr is LBQU then
      // LB19 .02 — [QU-Pf] ×: suppress break after any QU that is
      // NOT Final-Punctuation.
      if not _is_pf_at(cps, i) then return false end
      // LB19a (Pf-QU branch). Suppress when next cp is non-EA OR when
      // the cp before QU is sot / non-EA.
      if not _is_east_asian_eff_at(cps, absorbed, i + 1) then
        return false
      end
      if (i == 0) or
        not _is_east_asian_eff_before(cps, absorbed, i)
      then
        return false
      end
    end
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
    // LB21a (Unicode 16): HL (HY | [BA-$EastAsian]) × [^HL]
    // No break after HL followed by HY or non-East-Asian BA. East
    // Asian BA chars (e.g. CJK middle dot U+00B7 — wait, classified
    // as AI) — we exclude them by EAW lookup on curr cp.
    let curr_is_hy_or_baw =
      (curr is LBHY) or
      ((curr is LBBA)
        and not _is_east_asian_eff_at(cps, absorbed, i))
    if curr_is_hy_or_baw and (not (next is LBHL)) then
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
    // LB25 (Unicode 16): do not break numbers. Full pair list:
    //   NU (SY|IS)* CL × PO
    //   NU (SY|IS)* CP × PO
    //   NU (SY|IS)* CL × PR
    //   NU (SY|IS)* CP × PR
    //   NU (SY|IS)*    × PO
    //   NU (SY|IS)*    × PR
    //   PO × OP NU
    //   PO × OP IS NU
    //   PO × NU
    //   PR × OP NU
    //   PR × OP IS NU
    //   PR × NU
    //   HY × NU
    //   IS × NU
    //   NU (SY|IS)*    × NU
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
    // The Indic placeholder ◌ is U+25CC DOTTED CIRCLE. We detect it
    // by codepoint and treat it as equivalent to AK for these rules.
    let curr_is_ak_or_dc =
      (curr is LBAK) or _is_dotted_circle_at(cps, absorbed, i)
    let curr_is_aksas =
      curr_is_ak_or_dc or (curr is LBAS)
    let next_is_ak_or_dc =
      (next is LBAK) or _is_dotted_circle_at(cps, absorbed, i + 1)
    let next_is_aksas =
      next_is_ak_or_dc or (next is LBAS)
    if (curr is LBAP) and next_is_aksas then return false end
    if curr_is_aksas
      and ((next is LBVF) or (next is LBVI))
    then
      return false
    end
    // Rule 3: ((AK|◌|AS) VI) × (AK|◌)
    // curr is VI; need prev anchor class ∈ AK/AS/◌; next ∈ AK/◌.
    if (curr is LBVI) and next_is_ak_or_dc then
      if _lb28a_prev_is_aksas(cls, cps, absorbed, i) then
        return false
      end
    end
    // Rule 4: ((AK|◌|AS) × (AK|◌|AS) VF) — when curr and next are
    // both AK/AS/◌ and the next-after-next is VF.
    if curr_is_aksas and next_is_aksas then
      if _lb28a_next_after_is_vf(cls, absorbed, i + 1) then
        return false
      end
    end
    // LB29: IS × (AL | HL)
    if (curr is LBIS) and ((next is LBAL) or (next is LBHL)) then
      return false
    end
    // LB30 (Unicode 16):
    //   (AL | HL | NU) × [OP - $EastAsian]
    //   [CP - $EastAsian] × (AL | HL | NU)
    // The excluded set ($EastAsian = ea ∈ {F, W, H}) refines the
    // rule to allow a break before an East Asian OP or after an East
    // Asian CP — e.g. between a Latin letter and a wide corner
    // bracket.
    if ((curr is LBAL) or (curr is LBHL) or (curr is LBNU))
      and (next is LBOP)
      and not _is_east_asian_eff_at(cps, absorbed, i + 1)
    then
      return false
    end
    if (curr is LBCP)
      and ((next is LBAL) or (next is LBHL) or (next is LBNU))
      and not _is_east_asian_eff_at(cps, absorbed, i)
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
    // LB30b: EB × EM, [\p{Extended_Pictographic}&\p{Cn}] × EM
    if (curr is LBEB) and (next is LBEM) then return false end
    if (next is LBEM) and _is_extpict_cn_eff_at(cps, absorbed, i) then
      return false
    end
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
    LB25 pair-table dispatch. Returns true to suppress break.
    See the rule list in `_break_between`.
    """
    let curr = try cls(i)? else return false end
    let next = try cls(i + 1)? else return false end

    // Direct pairs that don't require chain tracking:
    //   (PR|PO) × NU
    //   HY × NU
    //   IS × NU
    if ((curr is LBPR) or (curr is LBPO) or (curr is LBHY)
      or (curr is LBIS)) and (next is LBNU)
    then
      return true
    end

    // (PR|PO) × OP NU,  (PR|PO) × OP IS NU
    if ((curr is LBPR) or (curr is LBPO)) and (next is LBOP) then
      let j = _next_eff_index(absorbed, i + 2)
      if j < absorbed.size() then
        try
          let after_op = cls(j)?
          if after_op is LBNU then return true end
          if after_op is LBIS then
            let k = _next_eff_index(absorbed, j + 1)
            if k < absorbed.size() then
              if cls(k)? is LBNU then return true end
            end
          end
        end
      end
    end

    // NU (SY|IS)* × {NU, PO, PR}
    // — chain anchored on a prior NU; (SY|IS)* skip.
    // Same chain helper also covers NU × NU, NU × PO, NU × PR
    // (because curr=NU IS in the chain).
    let in_chain = _in_numeric_chain(cls, absorbed, i)
    if in_chain
      and ((next is LBNU) or (next is LBPO) or (next is LBPR))
    then
      return true
    end

    // NU (SY|IS)* (CL|CP) × (PO|PR)
    // — when curr is CL/CP and the preceding chain (skipping
    //   SY|IS) ends in NU.
    if ((curr is LBCL) or (curr is LBCP))
      and ((next is LBPO) or (next is LBPR))
    then
      if i > 0 then
        let p = _prev_eff_index(absorbed, i - 1)
        if p >= 0 then
          if _in_numeric_chain(cls, absorbed, USize.from[ISize](p))
          then
            return true
          end
        end
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

  fun _next_eff_index(
    absorbed: Array[Bool] box, start: USize): USize
  =>
    """
    First non-absorbed index at or after `start`, or `absorbed.size()`
    (eot sentinel) if none.
    """
    var k: USize = start
    let n = absorbed.size()
    while k < n do
      try if not absorbed(k)? then return k end end
      k = k + 1
    end
    n

  fun _prev_eff_index(
    absorbed: Array[Bool] box, start: USize): ISize
  =>
    """
    Most recent non-absorbed index at or before `start`, or -1 (sot
    sentinel).
    """
    var k: ISize = ISize.from[USize](start)
    while k >= 0 do
      try
        if not absorbed(USize.from[ISize](k))? then return k end
      end
      k = k - 1
    end
    -1

  fun _is_east_asian_cp(cp: U32): Bool =>
    """East Asian if EAW ∈ {F, W, H} per UAX #11."""
    match _UcdEastAsianWidth.of(cp)
    | EAWF => true
    | EAWW => true
    | EAWH => true
    else false
    end

  fun _is_east_asian_eff_at(
    cps: Array[U32] box, absorbed: Array[Bool] box, i: USize): Bool
  =>
    """
    East-Asian-Width of the anchor cp at position i (walks back
    through absorbed CM/ZWJ to find the anchor). Returns false at
    eot or sot.
    """
    let n = absorbed.size()
    if i >= n then return false end
    let idx = _prev_eff_index(absorbed, i)
    if idx < 0 then return false end
    try _is_east_asian_cp(cps(USize.from[ISize](idx))?) else false end

  fun _is_east_asian_eff_after(
    cps: Array[U32] box, absorbed: Array[Bool] box, start: USize): Bool
  =>
    """
    East-Asian-Width of the next anchor cp at or after `start`.
    Returns false at eot.
    """
    let n = absorbed.size()
    let idx = _next_eff_index(absorbed, start)
    if idx >= n then return false end
    try _is_east_asian_cp(cps(idx)?) else false end

  fun _is_east_asian_eff_before(
    cps: Array[U32] box, absorbed: Array[Bool] box, i: USize): Bool
  =>
    """
    East-Asian-Width of the anchor cp strictly before position i.
    Returns false at sot.
    """
    if i == 0 then return false end
    let idx = _prev_eff_index(absorbed, i - 1)
    if idx < 0 then return false end
    try _is_east_asian_cp(cps(USize.from[ISize](idx))?) else false end

  fun _is_dotted_circle_at(
    cps: Array[U32] box, absorbed: Array[Bool] box, i: USize): Bool
  =>
    """
    True iff the cp at position i (after walking through absorbed CMs
    to the anchor) is U+25CC DOTTED CIRCLE.
    """
    let n = absorbed.size()
    if i >= n then return false end
    let idx = _prev_eff_index(absorbed, i)
    if idx < 0 then return false end
    try cps(USize.from[ISize](idx))? == 0x25CC else false end

  fun _lb28a_prev_is_aksas(
    cls: Array[LineBreak] box,
    cps: Array[U32] box,
    absorbed: Array[Bool] box,
    i: USize): Bool
  =>
    """
    LB28a rule 3 lookback. Walks back to the VI anchor at or before
    position i (curr may be an absorbed CM/ZWJ tagged with VI's
    class), then verifies the next non-absorbed position before that
    anchor is AK, AS, or U+25CC.
    """
    let vi_idx = _prev_eff_index(absorbed, i)
    if vi_idx < 1 then return false end
    let vi_anchor = USize.from[ISize](vi_idx)
    let p = _prev_eff_index(absorbed, vi_anchor - 1)
    if p < 0 then return false end
    try
      let c = cls(USize.from[ISize](p))?
      if (c is LBAK) or (c is LBAS) then return true end
      cps(USize.from[ISize](p))? == 0x25CC
    else false
    end

  fun _lb28a_next_after_is_vf(
    cls: Array[LineBreak] box,
    absorbed: Array[Bool] box,
    start: USize): Bool
  =>
    """
    LB28a rule 4 lookahead: the next anchor class after `start` is VF.
    """
    let j = _next_eff_index(absorbed, start + 1)
    if j >= absorbed.size() then return false end
    try cls(j)? is LBVF else false end

  fun _is_extpict_cn_eff_at(
    cps: Array[U32] box, absorbed: Array[Bool] box, i: USize): Bool
  =>
    """
    True iff the anchor cp at position i has both
    Extended_Pictographic = Yes and General_Category = Cn (unassigned).
    Used for LB30b's second form.
    """
    let n = absorbed.size()
    if i >= n then return false end
    let idx = _prev_eff_index(absorbed, i)
    if idx < 0 then return false end
    let cp = try cps(USize.from[ISize](idx))? else return false end
    if not Codepoints.has_binary_property(cp, PropExtendedPictographic) then
      return false
    end
    match Codepoints.category(cp)
    | Cn => true
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
