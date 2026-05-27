// Error types used by Unicode operations that can fail at runtime.
//
// Partial constructors (`new from_string(s) ?`) raise via Pony's `?`
// and carry no data — callers that want offset/kind detail can call
// `Bytes.first_bad_utf8_offset(s)` first. Method-level errors (e.g.,
// `Codepoints.count(s): (USize | InvalidUtf8)`) carry context as
// fields on a `class val` instance.

class val InvalidUtf8 is Stringable
  """
  Returned by methods (not raised by `?` partial constructors) when
  the input bytes fail UTF-8 validation. The `offset` field points
  at the first ill-formed byte per RFC 3629.
  """
  let offset: USize

  new val create(offset': USize) =>
    offset = offset'

  fun string(): String iso^ =>
    let s = recover iso String(48) end
    s.append("InvalidUtf8 at byte offset ")
    s.append(offset.string())
    s

class val InvalidScalar is Stringable
  """
  Returned by `Codepoints.from_u32(u)` for U32 values that don't name
  a Unicode scalar value — surrogates (U+D800..U+DFFF) or values
  above U+10FFFF.
  """
  let value: U32

  new val create(value': U32) =>
    value = value'

  fun string(): String iso^ =>
    let s = recover iso String(48) end
    s.append("InvalidScalar 0x")
    s.append(_hex(value))
    s

  fun _hex(v: U32): String iso^ =>
    let digits = "0123456789ABCDEF"
    let out = recover iso String(8) end
    var n: U32 = v
    let tmp = recover ref Array[U8](8) end
    if n == 0 then tmp.push('0') end
    while n > 0 do
      try tmp.push(digits(USize.from[U32](n and 0xF))?) end
      n = n >> 4
    end
    var i = tmp.size()
    while i > 0 do
      try out.push(tmp(i - 1)?) end
      i = i - 1
    end
    consume out
