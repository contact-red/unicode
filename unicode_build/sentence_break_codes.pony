// Codegen-side byte mapping for UAX #29 Sentence_Break property
// values. MUST agree with `unicode/sentence_break.pony`
// `SentenceBreaks._to_byte` / `_from_byte`.

primitive SentenceBreakCodes
  fun to_byte(code: String box): (U8 | None) =>
    match code
    | "Other"     => U8(0)
    | "CR"        => U8(1)
    | "LF"        => U8(2)
    | "Extend"    => U8(3)
    | "Sep"       => U8(4)
    | "Format"    => U8(5)
    | "Sp"        => U8(6)
    | "Lower"     => U8(7)
    | "Upper"     => U8(8)
    | "OLetter"   => U8(9)
    | "Numeric"   => U8(10)
    | "ATerm"     => U8(11)
    | "STerm"     => U8(12)
    | "Close"     => U8(13)
    | "SContinue" => U8(14)
    else
      None
    end
