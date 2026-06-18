// Value type wrapping a set of `Script` values. Used both as the
// return type for `Text.scripts()` / `Scripts.of` / `Scripts.dominant`
// and as the input to `Scripts.restrict_to` (an identifier
// allowlist).
//
// Internally we store a sorted, deduplicated `Array[U8] val` of
// script bytes (the same encoding `_ScriptCodec.to_byte` produces).
// Sorted-deduped means equal sets have equal byte arrays, which keeps
// `contains` simple and makes `resolved` a one-pass filter.

class val ScriptSet
  let _bytes: Array[U8] val

  new val create(scripts: Array[Script] val) =>
    """
    Build a set from a (possibly-unsorted, possibly-duplicate) list
    of scripts.
    """
    _bytes = _ScriptSetUtils.sort_dedup(scripts)

  new val empty() =>
    """The empty set — useful as a starting point for unions."""
    _bytes = recover val Array[U8] end

  new val _from_bytes(sorted_bytes: Array[U8] val) =>
    """
    Package-private constructor. `sorted_bytes` MUST already be
    sorted and deduplicated; callers in the unicode package use this
    when they already have a valid byte array (e.g., `resolved`,
    `_ScriptCodec.from_byte` chains) and want to skip the sort.
    """
    _bytes = sorted_bytes

  fun size(): USize => _bytes.size()

  fun contains(s: Script): Bool =>
    """True iff `s` is in this set."""
    let target = _ScriptCodec.to_byte(s)
    for b in _bytes.values() do
      if b == target then return true end
    end
    false

  fun to_array(): Array[Script] val =>
    """
    Return the scripts in this set as an `Array[Script] val`, in the
    same byte-sorted order the set stores internally.
    """
    let out = recover trn Array[Script](_bytes.size()) end
    for b in _bytes.values() do
      out.push(_ScriptCodec.from_byte(b))
    end
    consume out

  fun resolved(): ScriptSet val =>
    """
    The set with `Common` and `Inherited` removed. Useful for the
    "which actual scripts does this text use?" question — those two
    fit anything and rarely belong in the answer.
    """
    let common = _ScriptCodec.to_byte(ScriptCommon)
    let inherited = _ScriptCodec.to_byte(ScriptInherited)
    let filtered = recover trn Array[U8] end
    for b in _bytes.values() do
      if (b != common) and (b != inherited) then
        filtered.push(b)
      end
    end
    ScriptSet._from_bytes(consume filtered)

  fun bytes(): Array[U8] val =>
    """
    Package-private view of the underlying sorted byte array. Used by
    `Scripts.restrict_to` to avoid re-encoding scripts on every cp.
    """
    _bytes

primitive _ScriptSetUtils
  fun sort_dedup(scripts: Array[Script] val): Array[U8] val =>
    let raw = recover trn Array[U8](scripts.size()) end
    for s in scripts.values() do
      raw.push(_ScriptCodec.to_byte(s))
    end
    let n = raw.size()
    var i: USize = 1
    while i < n do
      try
        var j = i
        let cur = raw(j)?
        while (j > 0) and (raw(j - 1)? > cur) do
          raw(j)? = raw(j - 1)?
          j = j - 1
        end
        raw(j)? = cur
      end
      i = i + 1
    end
    let out = recover trn Array[U8](n) end
    var prev: U8 = 0
    var first: Bool = true
    for b in raw.values() do
      if first or (b != prev) then out.push(b); first = false end
      prev = b
    end
    consume out
