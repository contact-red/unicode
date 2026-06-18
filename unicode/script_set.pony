// UAX #39 "resolved script set" operations.
//
// Given a string, compute the set of scripts that could be the
// "single script" of the string per UAX #39 §5.1. A string is
// "single-script" if there exists at least one script `S` such that
// every codepoint in the string belongs to `S` (using each cp's
// `Script_Extensions` rather than its bare `Script`).
//
// Codepoints whose Script_Extensions includes `Common` or `Inherited`
// do not constrain the choice — they fit any script. So a string of
// only ASCII punctuation is trivially single-script. A mix of
// Latin and Cyrillic letters is *not* single-script: the intersection
// of their Script_Extensions is empty.
//
// The "resolved" set is the running intersection of Script_Extensions
// across all *constraining* codepoints. `resolve` returns the final
// set; `is_single_script` returns `true` iff the resolved set is
// non-empty AND at least one constraining codepoint was seen — except
// for the all-Common/Inherited case (and the empty string), which we
// also call single-script.

primitive ScriptSet
  fun resolve(s: String box): Array[Script] val =>
    """
    Walk every codepoint in `s` and intersect their `Script_Extensions`,
    skipping codepoints whose extensions include `Common` or
    `Inherited`. Returns the final set.

    Result interpretations:
      * Non-empty array: the string is single-script and these are
        the candidate scripts.
      * Empty array: either the string is mixed-script (intersection
        collapsed to empty) or every codepoint was Common/Inherited
        (no narrowing happened). Use `is_single_script` to
        distinguish.
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
    | let a: Array[Script] val => a
    | None => recover val Array[Script] end
    end

  fun is_single_script(s: String box): Bool =>
    """
    True iff there exists at least one script that every codepoint
    in `s` belongs to (via `Script_Extensions`). Empty strings and
    all-Common / all-Inherited strings are single-script.
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
    """
    Order-preserving intersection: elements of `a` that also appear
    in `b`, in `a`'s order.
    """
    let out = recover trn Array[Script] end
    for x in a.values() do
      if _contains(b, x) then out.push(x) end
    end
    consume out

  fun _contains(scripts: Array[Script] val, s: Script): Bool =>
    let target = Scripts._to_byte(s)
    for x in scripts.values() do
      if Scripts._to_byte(x) == target then return true end
    end
    false
