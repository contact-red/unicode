// Codegen-side byte mapping for Grapheme_Cluster_Break property values.
// MUST agree with `unicode/grapheme_break.pony` `GraphemeBreaks._to_byte` /
// `_from_byte` — change both in the same commit.

primitive GraphemeBreakCodes
  fun to_byte(code: String box): (U8 | None) =>
    """
    Map a UAX #29 Grapheme_Cluster_Break property name to the byte used
    in generated tables. Returns `None` for unrecognized names. `Other`
    is byte 0; codepoints not covered by any range fall through to it
    automatically without needing an entry.
    """
    match code
    | "Other" => U8(0)
    | "CR" => U8(1)  | "LF" => U8(2)  | "Control" => U8(3)
    | "Extend" => U8(4) | "ZWJ" => U8(5)
    | "Regional_Indicator" => U8(6)
    | "Prepend" => U8(7) | "SpacingMark" => U8(8)
    | "L" => U8(9) | "V" => U8(10) | "T" => U8(11)
    | "LV" => U8(12) | "LVT" => U8(13)
    | "Extended_Pictographic" => U8(14)
    else
      None
    end
