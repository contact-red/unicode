// Shared hex-pair decoder used by every UCD lookup table.
//
// The UCD tables are encoded as ASCII hex-digit pairs to sidestep ponyc's
// expensive `Array[U8]` typecheck (see unicode_build/category_table.pony
// for full rationale). Every table needs to decode "NN" -> U8, so this
// helper lives in one place rather than being duplicated into each
// generated `_ucd_*.pony`.

primitive _UcdHex
  fun byte(s: String val, offset: USize): U32 ? =>
    """
    Decode two ASCII hex digits at `offset` into a U32 (0..255).
    Raises on out-of-range or non-hex input.
    """
    (digit(s(offset)?)? << 4) or digit(s(offset + 1)?)?

  fun digit(c: U8): U32 ? =>
    """
    Decode a single ASCII hex digit ('0'..'9', 'A'..'F', 'a'..'f') to
    its numeric value. Raises on other input.
    """
    if (c >= '0') and (c <= '9') then U32.from[U8](c - '0')
    elseif (c >= 'A') and (c <= 'F') then U32.from[U8]((c - 'A') + 10)
    elseif (c >= 'a') and (c <= 'f') then U32.from[U8]((c - 'a') + 10)
    else error
    end
