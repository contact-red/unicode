// Codegen-side byte mapping for UAX #29 Word_Break property values.
// MUST agree with `unicode/word_break.pony` `WordBreaks._to_byte` /
// `_from_byte` — change both in the same commit.

primitive WordBreakCodes
  fun to_byte(code: String box): (U8 | None) =>
    """
    Map a UAX #29 Word_Break property name to the byte used in
    generated tables. Returns `None` for unrecognized names. `Other`
    is byte 0; codepoints not covered by any range fall through to
    it automatically without needing an entry.
    """
    match code
    | "Other"                 => U8(0)
    | "CR"                    => U8(1)
    | "LF"                    => U8(2)
    | "Newline"               => U8(3)
    | "Extend"                => U8(4)
    | "ZWJ"                   => U8(5)
    | "Regional_Indicator"    => U8(6)
    | "Format"                => U8(7)
    | "Katakana"              => U8(8)
    | "Hebrew_Letter"         => U8(9)
    | "ALetter"               => U8(10)
    | "Single_Quote"          => U8(11)
    | "Double_Quote"          => U8(12)
    | "MidLetter"             => U8(13)
    | "MidNum"                => U8(14)
    | "MidNumLet"             => U8(15)
    | "Numeric"               => U8(16)
    | "ExtendNumLet"          => U8(17)
    | "WSegSpace"             => U8(18)
    | "Extended_Pictographic" => U8(19)
    else
      None
    end
