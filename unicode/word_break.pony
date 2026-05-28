// UAX #29 `Word_Break` property values.
//
// The closed union has one primitive per value in
// `WordBreakProperty.txt`, plus `WBOther` for codepoints with no
// assigned value. Exhaustive `match` is compile-checked; bumping
// Unicode in a way that adds a value is semver-significant.

primitive WBOther
  fun code(): String val => "Other"
  fun string(): String val => "Other"
primitive WBCR
  fun code(): String val => "CR"
  fun string(): String val => "CR"
primitive WBLF
  fun code(): String val => "LF"
  fun string(): String val => "LF"
primitive WBNewline
  fun code(): String val => "Newline"
  fun string(): String val => "Newline"
primitive WBExtend
  fun code(): String val => "Extend"
  fun string(): String val => "Extend"
primitive WBZWJ
  fun code(): String val => "ZWJ"
  fun string(): String val => "ZWJ"
primitive WBRegionalIndicator
  fun code(): String val => "Regional_Indicator"
  fun string(): String val => "Regional_Indicator"
primitive WBFormat
  fun code(): String val => "Format"
  fun string(): String val => "Format"
primitive WBKatakana
  fun code(): String val => "Katakana"
  fun string(): String val => "Katakana"
primitive WBHebrewLetter
  fun code(): String val => "Hebrew_Letter"
  fun string(): String val => "Hebrew_Letter"
primitive WBALetter
  fun code(): String val => "ALetter"
  fun string(): String val => "ALetter"
primitive WBSingleQuote
  fun code(): String val => "Single_Quote"
  fun string(): String val => "Single_Quote"
primitive WBDoubleQuote
  fun code(): String val => "Double_Quote"
  fun string(): String val => "Double_Quote"
primitive WBMidLetter
  fun code(): String val => "MidLetter"
  fun string(): String val => "MidLetter"
primitive WBMidNum
  fun code(): String val => "MidNum"
  fun string(): String val => "MidNum"
primitive WBMidNumLet
  fun code(): String val => "MidNumLet"
  fun string(): String val => "MidNumLet"
primitive WBNumeric
  fun code(): String val => "Numeric"
  fun string(): String val => "Numeric"
primitive WBExtendNumLet
  fun code(): String val => "ExtendNumLet"
  fun string(): String val => "ExtendNumLet"
primitive WBWSegSpace
  fun code(): String val => "WSegSpace"
  fun string(): String val => "WSegSpace"
primitive WBExtendedPictographic
  fun code(): String val => "Extended_Pictographic"
  fun string(): String val => "Extended_Pictographic"

type WordBreak is
  ( WBOther | WBCR | WBLF | WBNewline | WBExtend | WBZWJ
  | WBRegionalIndicator | WBFormat | WBKatakana | WBHebrewLetter
  | WBALetter | WBSingleQuote | WBDoubleQuote | WBMidLetter | WBMidNum
  | WBMidNumLet | WBNumeric | WBExtendNumLet | WBWSegSpace
  | WBExtendedPictographic
  )

primitive WordBreaks
  fun from_iso(s: String box): (WordBreak | None) =>
    match s
    | "Other" => WBOther
    | "CR" => WBCR
    | "LF" => WBLF
    | "Newline" => WBNewline
    | "Extend" => WBExtend
    | "ZWJ" => WBZWJ
    | "Regional_Indicator" => WBRegionalIndicator
    | "Format" => WBFormat
    | "Katakana" => WBKatakana
    | "Hebrew_Letter" => WBHebrewLetter
    | "ALetter" => WBALetter
    | "Single_Quote" => WBSingleQuote
    | "Double_Quote" => WBDoubleQuote
    | "MidLetter" => WBMidLetter
    | "MidNum" => WBMidNum
    | "MidNumLet" => WBMidNumLet
    | "Numeric" => WBNumeric
    | "ExtendNumLet" => WBExtendNumLet
    | "WSegSpace" => WBWSegSpace
    | "Extended_Pictographic" => WBExtendedPictographic
    else None
    end

  fun _to_byte(w: WordBreak): U8 =>
    match w
    | WBOther              => 0
    | WBCR                 => 1
    | WBLF                 => 2
    | WBNewline            => 3
    | WBExtend             => 4
    | WBZWJ                => 5
    | WBRegionalIndicator  => 6
    | WBFormat             => 7
    | WBKatakana           => 8
    | WBHebrewLetter       => 9
    | WBALetter            => 10
    | WBSingleQuote        => 11
    | WBDoubleQuote        => 12
    | WBMidLetter          => 13
    | WBMidNum             => 14
    | WBMidNumLet          => 15
    | WBNumeric            => 16
    | WBExtendNumLet       => 17
    | WBWSegSpace          => 18
    | WBExtendedPictographic => 19
    end

  fun _from_byte(b: U8): WordBreak =>
    match b
    | 1  => WBCR
    | 2  => WBLF
    | 3  => WBNewline
    | 4  => WBExtend
    | 5  => WBZWJ
    | 6  => WBRegionalIndicator
    | 7  => WBFormat
    | 8  => WBKatakana
    | 9  => WBHebrewLetter
    | 10 => WBALetter
    | 11 => WBSingleQuote
    | 12 => WBDoubleQuote
    | 13 => WBMidLetter
    | 14 => WBMidNum
    | 15 => WBMidNumLet
    | 16 => WBNumeric
    | 17 => WBExtendNumLet
    | 18 => WBWSegSpace
    | 19 => WBExtendedPictographic
    else WBOther
    end
