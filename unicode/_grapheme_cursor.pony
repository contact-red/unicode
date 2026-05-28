// UAX #29 grapheme-cluster break state machine.
//
// Walks already-validated UTF-8 bytes and reports cluster boundaries.
// Each `next_range()` call returns the byte range `[start, finish)` of
// the next cluster, or `None` after the last cluster.
//
// Implemented rules (UAX #29 §3.1.1):
//
//   GB1, GB2  — sot/eot boundaries (handled by start state + None return)
//   GB3       — CR × LF
//   GB4, GB5  — break around (Control | CR | LF) except per GB3
//   GB6, GB7, GB8 — Hangul syllable runs
//   GB9       — × Extend, × ZWJ
//   GB9a      — × SpacingMark
//   GB9b      — Prepend ×
//   GB11      — emoji ZWJ sequence: Extended_Pictographic Extend* ZWJ ×
//               Extended_Pictographic
//   GB9c      — Indic_Conjunct_Break (Unicode 15.1):
//                 InCB=Consonant [InCB=Extend InCB=Linker]* InCB=Linker
//                   [InCB=Extend InCB=Linker]* × InCB=Consonant
//               Suppresses the break before a Consonant when the
//               history since the last cluster start contains a
//               Consonant followed by at least one Linker, with only
//               Extend/Linker codepoints between.
//   GB12, GB13 — Regional_Indicator pairs
//   GB999     — otherwise: break

class ref _GraphemeCursor
  let _bytes: String box
  var _start: USize            // byte offset of current cluster's start
  var _pos:   USize            // decoder position (byte offset)
  var _prev_break: GraphemeBreak
  var _ri_run: USize           // count of consecutive RIs since last break
  var _in_emoji_seq: Bool      // tracking GB11: have we seen E_Pictographic
                               // (Extend|ZWJ)* on the current cluster?
  var _saw_zwj: Bool           // last codepoint in the cluster was ZWJ
                               // (set after E_Pict Extend*)
  var _incb_consonant_seen: Bool  // GB9c: seen InCB=Consonant in cluster
  var _incb_linker_seen: Bool     // GB9c: seen InCB=Linker after consonant
  var _emitted_first: Bool     // has the first cluster been emitted yet?

  new ref create(bytes: String box) =>
    _bytes = bytes
    _start = 0
    _pos = 0
    _prev_break = GBOther
    _ri_run = 0
    _in_emoji_seq = false
    _saw_zwj = false
    _incb_consonant_seen = false
    _incb_linker_seen = false
    _emitted_first = false

  fun ref next_range(): ((USize, USize) | None) =>
    """
    Return the byte range of the next grapheme cluster as
    `(start, finish_exclusive)`, or `None` when iteration is complete.
    """
    let size = _bytes.size()
    if _pos >= size then
      // Either we never started, or we've finished. The final cluster
      // is emitted once `_pos == size` reaches that point through a
      // normal iteration step below.
      return None
    end

    // Decode the first codepoint of this cluster.
    (let cp0, let cp0_len) =
      try _decode(_pos)? else (U32(0xFFFD), USize(1)) end
    _start = _pos
    _pos = _pos + cp0_len
    let g0 = _UcdGraphemeBreak.of(cp0)
    let incb0 = _UcdIndicConjunctBreak.of(cp0)
    _reset_state(g0)
    _reset_incb(incb0)

    // Extend the cluster as long as GB rules say "no break."
    while _pos < size do
      (let cp1, let cp1_len) =
        try _decode(_pos)? else (U32(0xFFFD), USize(1)) end
      let g1 = _UcdGraphemeBreak.of(cp1)
      let incb1 = _UcdIndicConjunctBreak.of(cp1)
      var should_break = _break_between(_prev_break, g1)
      // GB9c override: suppress an otherwise-required break when the
      // current cluster contains a Consonant + Linker history and the
      // next codepoint is also a Consonant.
      if should_break and _gb9c_applies(incb1) then
        should_break = false
      end
      if should_break then
        // Boundary before cp1 — leave it for the next call.
        let range = (_start, _pos)
        _prev_break = g1
        // Don't advance _pos here; next call decodes cp1 as the new
        // cluster's first codepoint.
        return range
      end
      // No break: extend the cluster.
      _advance_state(g1)
      _advance_incb(incb1)
      _pos = _pos + cp1_len
    end
    // Reached end of input — emit the final cluster.
    (_start, _pos)

  fun ref _reset_state(g: GraphemeBreak) =>
    """
    Called when a new cluster starts (its first codepoint is g).
    """
    _prev_break = g
    _saw_zwj = false
    _in_emoji_seq =
      match g
      | GBExtendedPictographic => true
      else false
      end
    _ri_run =
      match g
      | GBRegionalIndicator => 1
      else 0
      end

  fun ref _reset_incb(incb: IndicConjunctBreak) =>
    """
    Initialize InCB tracking when a new cluster's first codepoint is
    `incb`. Only a Consonant primes the GB9c state machine; any other
    starting value leaves both flags off.
    """
    match incb
    | InCBConsonant =>
      _incb_consonant_seen = true
      _incb_linker_seen = false
    else
      _incb_consonant_seen = false
      _incb_linker_seen = false
    end

  fun ref _advance_incb(incb: IndicConjunctBreak) =>
    """
    Update InCB tracking when a codepoint joins the current cluster.
    Transitions (state = (consonant_seen, linker_seen)):
      Consonant: → (true, false)   — a new Consonant restarts the search
      Linker   : if consonant_seen, → (true, true)
      Extend   : keep state
      None     : break the chain → (false, false)
    """
    match incb
    | InCBConsonant =>
      _incb_consonant_seen = true
      _incb_linker_seen = false
    | InCBLinker =>
      if _incb_consonant_seen then _incb_linker_seen = true end
    | InCBExtend =>
      None
    | InCBNone =>
      _incb_consonant_seen = false
      _incb_linker_seen = false
    end

  fun _gb9c_applies(next: IndicConjunctBreak): Bool =>
    """
    True iff GB9c says to suppress the break before `next`. Active
    only when next is Consonant and the current cluster's history
    includes Consonant + ... + Linker (Extends and additional
    Linkers allowed between).
    """
    match next
    | InCBConsonant => _incb_consonant_seen and _incb_linker_seen
    else false
    end

  fun ref _advance_state(g: GraphemeBreak) =>
    """
    Update tracking state after extending the current cluster with a
    codepoint of break-class g (called only when no break occurs).
    """
    // GB11 emoji-ZWJ: an Extended_Pictographic followed by
    // (Extend | ZWJ)* keeps `_in_emoji_seq` alive. ZWJ specifically
    // arms `_saw_zwj` so the next Extended_Pictographic continues the
    // cluster.
    match g
    | GBExtend => None  // keeps _in_emoji_seq, but doesn't arm _saw_zwj
    | GBZWJ =>
      if _in_emoji_seq then _saw_zwj = true end
    | GBExtendedPictographic =>
      // Reached via GB11 continuation: a new pictographic starts a
      // fresh emoji-seq tail.
      _in_emoji_seq = true
      _saw_zwj = false
    else
      _in_emoji_seq = false
      _saw_zwj = false
    end
    // Regional_Indicator run: tracked for GB12/13 break decisions.
    match g
    | GBRegionalIndicator => _ri_run = _ri_run + 1
    else _ri_run = 0
    end
    _prev_break = g

  fun _break_between(prev: GraphemeBreak, curr: GraphemeBreak): Bool =>
    """
    True iff UAX #29 requires a cluster break between a codepoint of
    class `prev` and the next codepoint of class `curr`. Implements
    GB3..GB13 in priority order; defaults to GB999 (break).
    """
    // GB3: CR × LF
    if (prev is GBCR) and (curr is GBLF) then return false end
    // GB4: (Control | CR | LF) ÷
    if (prev is GBControl) or (prev is GBCR) or (prev is GBLF) then
      return true
    end
    // GB5: ÷ (Control | CR | LF)
    if (curr is GBControl) or (curr is GBCR) or (curr is GBLF) then
      return true
    end
    // GB6: L × (L | V | LV | LVT)
    if prev is GBL then
      if (curr is GBL) or (curr is GBV) or (curr is GBLV)
        or (curr is GBLVT)
      then
        return false
      end
    end
    // GB7: (LV | V) × (V | T)
    if (prev is GBLV) or (prev is GBV) then
      if (curr is GBV) or (curr is GBT) then return false end
    end
    // GB8: (LVT | T) × T
    if (prev is GBLVT) or (prev is GBT) then
      if curr is GBT then return false end
    end
    // GB9: × (Extend | ZWJ)
    if (curr is GBExtend) or (curr is GBZWJ) then return false end
    // GB9a: × SpacingMark
    if curr is GBSpacingMark then return false end
    // GB9b: Prepend ×
    if prev is GBPrepend then return false end
    // GB11: Extended_Pictographic Extend* ZWJ × Extended_Pictographic
    if _saw_zwj and _in_emoji_seq and (curr is GBExtendedPictographic) then
      return false
    end
    // GB12 / GB13: pair Regional_Indicators. If we've seen an odd
    // number of RIs in the current run, don't break before the next
    // one (it completes the pair).
    if (prev is GBRegionalIndicator) and (curr is GBRegionalIndicator) then
      if (_ri_run % 2) == 1 then return false end
    end
    // GB999
    true

  fun _decode(offset: USize): (U32, USize) ? =>
    """
    Decode one codepoint at `offset`. Assumes valid UTF-8 (caller is
    the Text invariant). Returns (scalar, byte_length). Partial on
    out-of-bounds.
    """
    let b0 = _bytes(offset)?
    if b0 < 0x80 then
      (U32.from[U8](b0), USize(1))
    elseif b0 < 0xE0 then
      let b1 = _bytes(offset + 1)?
      let cp = ((U32.from[U8](b0) and 0x1F) << 6)
        or (U32.from[U8](b1) and 0x3F)
      (cp, USize(2))
    elseif b0 < 0xF0 then
      let b1 = _bytes(offset + 1)?
      let b2 = _bytes(offset + 2)?
      let cp = ((U32.from[U8](b0) and 0x0F) << 12)
        or ((U32.from[U8](b1) and 0x3F) << 6)
        or (U32.from[U8](b2) and 0x3F)
      (cp, USize(3))
    else
      let b1 = _bytes(offset + 1)?
      let b2 = _bytes(offset + 2)?
      let b3 = _bytes(offset + 3)?
      let cp = ((U32.from[U8](b0) and 0x07) << 18)
        or ((U32.from[U8](b1) and 0x3F) << 12)
        or ((U32.from[U8](b2) and 0x3F) << 6)
        or (U32.from[U8](b3) and 0x3F)
      (cp, USize(4))
    end
