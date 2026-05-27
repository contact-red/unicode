// `Replace` — substitute occurrences of a needle with a replacement.
//
// Empty needle is rejected (would either infinite-loop or insert the
// replacement between every byte). Operates at byte level on
// validated UTF-8; needle and replacement must themselves be
// well-formed UTF-8 for the output to be well-formed.

primitive Replace
  fun all(s: String box, needle: String box, replacement: String box)
    : (String iso^ | InvalidUtf8)
  =>
    """
    Replace every non-overlapping occurrence of `needle` in `s` with
    `replacement`. Returns the result as `String iso^`. Returns the
    input cloned when `needle` is empty (semantically a no-op).
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid =>
      if needle.size() == 0 then return s.clone() end
      _do_replace(s, needle, replacement, false)
    end

  fun first(s: String box, needle: String box, replacement: String box)
    : (String iso^ | InvalidUtf8)
  =>
    """
    Replace only the first occurrence of `needle`. Empty `needle`
    yields the input cloned.
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid =>
      if needle.size() == 0 then return s.clone() end
      _do_replace(s, needle, replacement, true)
    end

  // ============================================================
  // Workhorses
  // ============================================================

  fun _do_replace(
    s: String box,
    needle: String box,
    replacement: String box,
    only_first: Bool)
    : String iso^
  =>
    let out = recover iso String(s.size()) end
    var pos: USize = 0
    var first_done: Bool = false
    while pos < s.size() do
      let try_find = (not only_first) or (not first_done)
      let found: (USize | None) =
        if try_find then Search._index_of(s, needle, pos)
        else None
        end
      match found
      | let off: USize =>
        // Copy [pos, off), then the replacement.
        var i: USize = pos
        while i < off do
          try out.push(s(i)?) end
          i = i + 1
        end
        var j: USize = 0
        while j < replacement.size() do
          try out.push(replacement(j)?) end
          j = j + 1
        end
        pos = off + needle.size()
        first_done = true
      | None =>
        // Copy the rest.
        var i: USize = pos
        while i < s.size() do
          try out.push(s(i)?) end
          i = i + 1
        end
        pos = s.size()
      end
    end
    consume out
