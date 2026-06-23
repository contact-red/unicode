// `Scripts` topical primitive — string-level script analysis.
//
// Sits alongside `Words`, `Sentences`, `Lines` in shape: public
// methods take `String box` and act on whole strings; `Text` delegates
// to these. The closed-union `Script` type itself and the byte
// codecs live in the auto-generated `script.pony` / `_ucd_script.pony`
// (the private `_ScriptCodec` primitive).
//
// Two layers of "what scripts are in this text" are exposed:
//
//   `Scripts.of(s)` — plain set of `script(cp)` values seen in `s`.
//     Common/Inherited show up here; call `.resolved()` on the result
//     to drop them.
//
//   `Scripts.resolved_script_set(s)` — UAX #39 §5.1 intersection over
//     `Script_Extensions(cp)`. Constraining: a string only stays
//     single-script if every codepoint's extensions overlap a common
//     script. This is what `is_single_script` is built on.

primitive Scripts
  fun from_iso(name: String box): (Script | None) =>
    """
    Look up a `Script` by its long UCD name (`"Latin"`, `"Cyrillic"`,
    `"Han"`, …). Returns `None` for unknown names. Case- and
    underscore-sensitive (`"Anatolian_Hieroglyphs"`, not
    `"Anatolian Hieroglyphs"`).
    """
    _ScriptCodec.from_iso(name)

  fun of(s: String box): ScriptSet val =>
    """
    The set of `script(cp)` values for every codepoint in `s`. ASCII
    digits, punctuation, etc. contribute `ScriptCommon`; combining
    marks contribute `ScriptInherited`. Use `.resolved()` on the
    result to drop those.
    """
    let collected = recover trn Array[U8] end
    for cp in s.runes() do
      collected.push(_UcdScript.byte_of(cp))
    end
    ScriptSet._from_bytes(_ScriptSetUtils.sort_dedup_bytes(consume collected))

  fun dominant(s: String box): Script =>
    """
    The script that occurs most often in `s`, ignoring
    `ScriptCommon` and `ScriptInherited` codepoints (digits,
    punctuation, combining marks). Ties are broken by first-seen.
    Returns `ScriptCommon` if `s` is empty or contains only
    Common/Inherited codepoints.
    """
    let counts = Array[USize].init(0, 256)
    let first_seen = Array[USize].init(USize.max_value(), 256)
    var n_cps: USize = 0
    let common = _ScriptCodec.to_byte(ScriptCommon)
    let inherited = _ScriptCodec.to_byte(ScriptInherited)
    for cp in s.runes() do
      let b = _UcdScript.byte_of(cp)
      if (b == common) or (b == inherited) then continue end
      let idx = USize.from[U8](b)
      try
        counts(idx)? = counts(idx)? + 1
        if first_seen(idx)? == USize.max_value() then
          first_seen(idx)? = n_cps
        end
      end
      n_cps = n_cps + 1
    end
    var best_byte: U8 = common
    var best_count: USize = 0
    var best_seen: USize = USize.max_value()
    var i: USize = 0
    while i < 256 do
      try
        let c = counts(i)?
        if c > 0 then
          let seen = first_seen(i)?
          if (c > best_count)
            or ((c == best_count) and (seen < best_seen))
          then
            best_byte = U8.from[USize](i)
            best_count = c
            best_seen = seen
          end
        end
      end
      i = i + 1
    end
    _ScriptCodec.from_byte(best_byte)

  fun restrict_to(s: String box, allowed: ScriptSet val): Bool =>
    """
    True iff every codepoint in `s` either has a Common/Inherited
    script (which fits anywhere) or has at least one entry in its
    `Script_Extensions` that is also in `allowed`. This is the
    "identifier-allowlist" predicate from UAX #39 §5: pass it the
    scripts your application accepts (`ScriptSet.create([ScriptLatin
    ])` for a Latin-only identifier policy) and it tells you whether
    `s` stays inside that allowlist.
    """
    let common = _ScriptCodec.to_byte(ScriptCommon)
    let inherited = _ScriptCodec.to_byte(ScriptInherited)
    let allowed_bytes = allowed.bytes()
    for cp in s.runes() do
      let sc_byte = _UcdScript.byte_of(cp)
      if (sc_byte == common) or (sc_byte == inherited) then
        continue
      end
      let exts = Codepoints.script_extensions(cp)
      var fits: Bool = false
      for ext in exts.values() do
        let eb = _ScriptCodec.to_byte(ext)
        if _byte_in(allowed_bytes, eb) then fits = true; break end
      end
      if not fits then return false end
    end
    true

  fun is_single_script(s: String box): Bool =>
    """
    True iff there exists at least one script that every codepoint
    in `s` belongs to via `Script_Extensions` (UAX #39 §5.1). Empty
    strings and all-Common/all-Inherited strings are single-script.

    Stronger than checking `Scripts.of(s).resolved().size() == 1` —
    this honours Script_Extensions, so e.g. U+0640 ARABIC TATWEEL
    (extended to many Arabic-family scripts) doesn't force
    mixed-script just because its bare script is Arabic.
    """
    var narrowed: (Array[Script] val | None) = None
    for cp in s.runes() do
      let exts = Codepoints.script_extensions(cp)
      if _contains_common_or_inherited(exts) then continue end
      match narrowed
      | None => narrowed = exts
      | let cur: Array[Script] val =>
        let isect = _intersect(cur, exts)
        if isect.size() == 0 then return false end
        narrowed = isect
      end
    end
    true

  fun resolved_script_set(s: String box): ScriptSet val =>
    """
    UAX #39 §5.1 running intersection of `Script_Extensions` across
    all constraining codepoints (Common/Inherited are skipped).
    Empty result means either mixed-script or all-Common/Inherited;
    use `is_single_script` to disambiguate.
    """
    var narrowed: (Array[Script] val | None) = None
    for cp in s.runes() do
      let exts = Codepoints.script_extensions(cp)
      if _contains_common_or_inherited(exts) then continue end
      match narrowed
      | None => narrowed = exts
      | let cur: Array[Script] val =>
        let isect = _intersect(cur, exts)
        narrowed = isect
        if isect.size() == 0 then break end
      end
    end
    match narrowed
    | let a: Array[Script] val => ScriptSet.create(a)
    | None => ScriptSet.empty()
    end

  fun _contains_common_or_inherited(scripts: Array[Script] val): Bool =>
    for sc in scripts.values() do
      match sc
      | ScriptCommon => return true
      | ScriptInherited => return true
      end
    end
    false

  fun _intersect(
    a: Array[Script] val,
    b: Array[Script] val): Array[Script] val
  =>
    let out = recover trn Array[Script] end
    for x in a.values() do
      if _contains_script(b, x) then out.push(x) end
    end
    consume out

  fun _contains_script(scripts: Array[Script] val, s: Script): Bool =>
    let target = _ScriptCodec.to_byte(s)
    for x in scripts.values() do
      if _ScriptCodec.to_byte(x) == target then return true end
    end
    false

  fun _byte_in(bytes: Array[U8] val, target: U8): Bool =>
    for b in bytes.values() do
      if b == target then return true end
    end
    false
