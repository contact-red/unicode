// `Bytes` topical primitive — byte-level pre-validation helpers.
//
// These are the operations a caller might run before deciding whether to
// wrap bytes in a `Text` (which validates at construction). They are also
// the validation entry points used internally by the topical primitives
// (`Graphemes.count(s)` etc.) before they delegate to their underscore
// implementations.
//
// Each public function takes the inline union `(String box | Array[U8] box)`
// rather than a `ByteSeq` alias — the name `ByteSeq` is already taken by
// Pony's builtin package for a more restrictive (val-only) union, and
// redeclaring it here would clash with the auto-imported builtin.

// `AllValid` sentinel returned by `Bytes.first_bad_utf8_offset` when the
// input is fully well-formed UTF-8.
primitive AllValid
  fun string(): String val => "AllValid"

primitive Bytes
  fun is_valid_utf8(b: (String box | Array[U8] box)): Bool =>
    """
    True iff `b` is well-formed UTF-8 per RFC 3629. Rejects:
      * overlong encodings
      * surrogates (U+D800..U+DFFF)
      * codepoints above U+10FFFF
      * truncated sequences
    """
    match first_bad_utf8_offset(b)
    | AllValid => true
    else false
    end

  fun first_bad_utf8_offset(b: (String box | Array[U8] box))
    : (USize | AllValid)
  =>
    """
    Return the byte offset of the first byte that breaks UTF-8
    well-formedness, or `AllValid` if every byte is fine. The offset
    points at the byte where validation failed — for a truncated
    sequence, that's the lead byte; for a bad continuation, the bad
    byte itself.
    """
    let size = match b
    | let s: String box => s.size()
    | let a: Array[U8] box => a.size()
    end
    var i: USize = 0
    while i < size do
      let b0 = try _at(b, i)? else return i end
      if b0 < 0x80 then
        // ASCII
        i = i + 1
      elseif b0 < 0xC2 then
        // 0x80-0xBF: stray continuation byte
        // 0xC0-0xC1: would be overlong 2-byte
        return i
      elseif b0 < 0xE0 then
        // 0xC2-0xDF: 2-byte sequence
        let b1 = try _at(b, i + 1)? else return i end
        if not _is_cont(b1) then return i + 1 end
        i = i + 2
      elseif b0 < 0xF0 then
        // 0xE0-0xEF: 3-byte sequence
        let b1 = try _at(b, i + 1)? else return i end
        let b2 = try _at(b, i + 2)? else return i end
        // First continuation byte has range constraints to forbid
        // overlong encodings and surrogates:
        //   0xE0: b1 in 0xA0..0xBF (forbid overlong)
        //   0xED: b1 in 0x80..0x9F (forbid surrogates U+D800..U+DFFF)
        //   else: b1 in 0x80..0xBF
        let b1_ok =
          if b0 == 0xE0 then (b1 >= 0xA0) and (b1 <= 0xBF)
          elseif b0 == 0xED then (b1 >= 0x80) and (b1 <= 0x9F)
          else _is_cont(b1)
          end
        if not b1_ok then return i + 1 end
        if not _is_cont(b2) then return i + 2 end
        i = i + 3
      elseif b0 < 0xF5 then
        // 0xF0-0xF4: 4-byte sequence (covers U+10000..U+10FFFF)
        let b1 = try _at(b, i + 1)? else return i end
        let b2 = try _at(b, i + 2)? else return i end
        let b3 = try _at(b, i + 3)? else return i end
        // First continuation byte has range constraints:
        //   0xF0: b1 in 0x90..0xBF (forbid overlong)
        //   0xF4: b1 in 0x80..0x8F (cap at U+10FFFF)
        //   else: b1 in 0x80..0xBF
        let b1_ok =
          if b0 == 0xF0 then (b1 >= 0x90) and (b1 <= 0xBF)
          elseif b0 == 0xF4 then (b1 >= 0x80) and (b1 <= 0x8F)
          else _is_cont(b1)
          end
        if not b1_ok then return i + 1 end
        if not _is_cont(b2) then return i + 2 end
        if not _is_cont(b3) then return i + 3 end
        i = i + 4
      else
        // 0xF5-0xFF: invalid lead byte (would encode codepoints above
        // U+10FFFF)
        return i
      end
    end
    AllValid

  fun _is_cont(b: U8): Bool =>
    (b >= 0x80) and (b <= 0xBF)

  fun _at(b: (String box | Array[U8] box), i: USize): U8 ? =>
    match b
    | let s: String box => s(i)?
    | let a: Array[U8] box => a(i)?
    end
