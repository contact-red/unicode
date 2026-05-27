// UAX #15 Unicode Normalization Forms (NFD / NFC / NFKD / NFKC).
//
// Algorithm:
//   1. Decompose: replace each cp with its decomposition (canonical only
//      for NFD/NFC; canonical OR compat for NFKD/NFKC), recursively until
//      no further decompositions apply. Hangul syllables decompose
//      algorithmically.
//   2. Canonical Ordering: reorder runs of combining marks by CCC.
//   3. Compose (NFC/NFKC only): walk through, combining pairs that form
//      primary composites and aren't blocked. Hangul L+V and LV+T are
//      composed algorithmically.
//
// Public entry points validate UTF-8 first and return InvalidUtf8 on
// failure. Workhorses (`_nfd` etc.) assume the input is well-formed.

primitive Normalize
  fun nfd(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Canonical decomposition. Returns a new `String iso^` in NFD.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _nfd(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun nfc(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Canonical composition (decompose, reorder, recompose).
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _nfc(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun nfkd(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Compatibility decomposition (applies both canonical and
    compatibility decompositions recursively).
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _nfkd(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun nfkc(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Compatibility decomposition followed by canonical composition.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _nfkc(s)
    | let off: USize => InvalidUtf8(off)
    end

  // ============================================================
  // Workhorses (assume valid UTF-8)
  // ============================================================

  fun _nfd(utf8: String box): String iso^ =>
    let cps = _decompose_all(utf8, false)
    _canonical_order(cps)
    _to_utf8(cps)

  fun _nfc(utf8: String box): String iso^ =>
    let cps = _decompose_all(utf8, false)
    _canonical_order(cps)
    let composed = _compose(cps)
    _to_utf8(composed)

  fun _nfkd(utf8: String box): String iso^ =>
    let cps = _decompose_all(utf8, true)
    _canonical_order(cps)
    _to_utf8(cps)

  fun _nfkc(utf8: String box): String iso^ =>
    let cps = _decompose_all(utf8, true)
    _canonical_order(cps)
    let composed = _compose(cps)
    _to_utf8(composed)

  // ============================================================
  // Decomposition
  // ============================================================

  fun _decompose_all(utf8: String box, compat: Bool): Array[U32] ref =>
    let out = Array[U32](utf8.size())
    for cp in utf8.runes() do
      _decompose_one(cp, compat, out)
    end
    out

  fun _decompose_one(cp: U32, compat: Bool, out: Array[U32] ref) =>
    // Hangul algorithmic decomposition.
    let s_base: U32 = 0xAC00
    let s_count: U32 = 11172
    if (cp >= s_base) and (cp < (s_base + s_count)) then
      _decompose_hangul(cp, out)
      return
    end

    // Table lookup. Try canonical first; for compat normalize, fall
    // back to compatibility decomp.
    let decomp: (Array[U32] val | None) =
      match Codepoints.canonical_decomposition(cp)
      | let d: Array[U32] val => d
      | None =>
        if compat then Codepoints.compat_decomposition(cp)
        else None
        end
      end

    match decomp
    | let d: Array[U32] val =>
      for sub in d.values() do
        _decompose_one(sub, compat, out)
      end
    | None =>
      out.push(cp)
    end

  fun _decompose_hangul(cp: U32, out: Array[U32] ref) =>
    let s_base: U32 = 0xAC00
    let l_base: U32 = 0x1100
    let v_base: U32 = 0x1161
    let t_base: U32 = 0x11A7
    let t_count: U32 = 28
    let n_count: U32 = 588
    let s_index = cp - s_base
    let l_part = l_base + (s_index / n_count)
    let v_part = v_base + ((s_index % n_count) / t_count)
    let t_index = s_index % t_count
    out.push(l_part)
    out.push(v_part)
    if t_index != 0 then out.push(t_base + t_index) end

  // ============================================================
  // Canonical Ordering — sort runs of non-starters by CCC.
  // ============================================================

  fun _canonical_order(cps: Array[U32] ref) =>
    // Bubble-sort over adjacent (cp_prev, cp_cur) pairs where both
    // are non-starters and prev has higher CCC than cur. Repeat until
    // stable. O(n²) worst case but n is small in practice (runs of
    // combining marks are short).
    var changed: Bool = true
    while changed do
      changed = false
      var i: USize = 1
      while i < cps.size() do
        try
          let cur = cps(i)?
          let prev = cps(i - 1)?
          let cc_cur = Codepoints.combining_class(cur)
          let cc_prev = Codepoints.combining_class(prev)
          if (cc_cur > 0) and (cc_prev > 0) and (cc_prev > cc_cur) then
            cps(i)? = prev
            cps(i - 1)? = cur
            changed = true
          end
        end
        i = i + 1
      end
    end

  // ============================================================
  // Canonical Composition
  // ============================================================

  fun _compose(cps: Array[U32] ref): Array[U32] ref =>
    if cps.size() == 0 then return cps end
    let out = Array[U32](cps.size())
    // ISize is fine for sentinel; "no starter yet" = -1.
    var last_starter_idx: ISize = -1
    var max_ccc_since_starter: U8 = 0

    for cp in cps.values() do
      let ccc = Codepoints.combining_class(cp)
      var consumed: Bool = false

      if last_starter_idx >= 0 then
        let blocked: Bool =
          if ccc == 0 then max_ccc_since_starter > 0
          else max_ccc_since_starter >= ccc
          end
        if not blocked then
          try
            let starter = out(USize.from[ISize](last_starter_idx))?
            match _try_compose(starter, cp)
            | let c: U32 =>
              out(USize.from[ISize](last_starter_idx))? = c
              consumed = true
            end
          end
        end
      end

      if not consumed then
        out.push(cp)
        if ccc == 0 then
          last_starter_idx = ISize.from[USize](out.size() - 1)
          max_ccc_since_starter = 0
        else
          if ccc > max_ccc_since_starter then
            max_ccc_since_starter = ccc
          end
        end
      end
    end
    out

  fun _try_compose(lhs: U32, rhs: U32): (U32 | None) =>
    let l_base: U32 = 0x1100
    let v_base: U32 = 0x1161
    let t_base: U32 = 0x11A7
    let s_base: U32 = 0xAC00
    let l_count: U32 = 19
    let v_count: U32 = 21
    let t_count: U32 = 28
    let n_count: U32 = 588
    let s_count: U32 = 11172

    // Hangul L + V → LV syllable.
    if (lhs >= l_base) and (lhs < (l_base + l_count))
      and (rhs >= v_base) and (rhs < (v_base + v_count))
    then
      let l_index = lhs - l_base
      let v_index = rhs - v_base
      return s_base + (l_index * n_count) + (v_index * t_count)
    end

    // Hangul LV + T → LVT syllable (only on LV; never LVT + T).
    if (lhs >= s_base) and (lhs < (s_base + s_count))
      and (rhs > t_base) and (rhs < (t_base + t_count))
    then
      if ((lhs - s_base) % t_count) == 0 then
        return lhs + (rhs - t_base)
      end
    end

    // Table lookup (Full_Composition_Exclusion already applied at
    // codegen time).
    Codepoints.compose_canonical(lhs, rhs)

  // ============================================================
  // UTF-8 emit
  // ============================================================

  fun _to_utf8(cps: Array[U32] box): String iso^ =>
    let out = recover iso String(cps.size() * 4) end
    for cp in cps.values() do
      out.push_utf32(cp)
    end
    consume out
