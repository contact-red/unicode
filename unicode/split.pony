// `Split` — partition a UTF-8 string by separator.
//
// Public methods validate the haystack as UTF-8. Empty separator
// returns a single-element array with the original string (the most
// useful behavior — alternatives would be "split into codepoints" or
// "split into bytes" which have their own helpers in Codepoints /
// Bytes).

primitive Split
  fun on(s: String box, sep: String box)
    : (Array[String val] val | InvalidUtf8)
  =>
    """
    Split `s` on occurrences of `sep`. Adjacent separators produce
    empty-string entries. Returns a fresh val array of fresh val
    String slices (one per part).
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _on(s, sep)
    end

  fun lines(s: String box)
    : (Array[String val] val | InvalidUtf8)
  =>
    """
    Split on line terminators: any of "\\r\\n", "\\n", or "\\r".
    Terminators are removed from the parts. A trailing terminator
    does NOT produce a trailing empty entry (mirrors common
    line-reader semantics).
    """
    match Bytes.first_bad_utf8_offset(s)
    | let off: USize => InvalidUtf8(off)
    | AllValid => _lines(s)
    end

  // ============================================================
  // Workhorses
  // ============================================================

  fun _on(s: String box, sep: String box): Array[String val] val =>
    let out = recover trn Array[String val] end
    if sep.size() == 0 then
      out.push(s.clone())
      return consume out
    end
    var pos: USize = 0
    while true do
      match Search._index_of(s, sep, pos)
      | let off: USize =>
        out.push(s.substring(
          ISize.from[USize](pos), ISize.from[USize](off)))
        pos = off + sep.size()
      | None =>
        out.push(s.substring(
          ISize.from[USize](pos), ISize.from[USize](s.size())))
        break
      end
    end
    consume out

  fun _lines(s: String box): Array[String val] val =>
    let out = recover trn Array[String val] end
    var pos: USize = 0
    let n = s.size()
    while pos < n do
      var i: USize = pos
      var end_byte: USize = n
      var next_pos: USize = n
      while i < n do
        try
          let c = s(i)?
          if c == 0x0A then
            end_byte = i
            next_pos = i + 1
            break
          elseif c == 0x0D then
            end_byte = i
            // Consume "\r\n" as a single terminator.
            next_pos =
              if ((i + 1) < n) and (try s(i + 1)? == 0x0A else false end)
              then i + 2
              else i + 1
              end
            break
          end
        end
        i = i + 1
      end
      out.push(s.substring(
        ISize.from[USize](pos), ISize.from[USize](end_byte)))
      pos = next_pos
    end
    consume out
