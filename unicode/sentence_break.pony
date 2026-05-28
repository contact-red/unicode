// UAX #29 `Sentence_Break` property values.
//
// Closed union with one primitive per value in
// `SentenceBreakProperty.txt`, plus `SBOther` for codepoints with no
// assigned value (default — most codepoints).

primitive SBOther
  fun code(): String val => "Other"
  fun string(): String val => "Other"
primitive SBCR
  fun code(): String val => "CR"
  fun string(): String val => "CR"
primitive SBLF
  fun code(): String val => "LF"
  fun string(): String val => "LF"
primitive SBExtend
  fun code(): String val => "Extend"
  fun string(): String val => "Extend"
primitive SBSep
  fun code(): String val => "Sep"
  fun string(): String val => "Sep"
primitive SBFormat
  fun code(): String val => "Format"
  fun string(): String val => "Format"
primitive SBSp
  fun code(): String val => "Sp"
  fun string(): String val => "Sp"
primitive SBLower
  fun code(): String val => "Lower"
  fun string(): String val => "Lower"
primitive SBUpper
  fun code(): String val => "Upper"
  fun string(): String val => "Upper"
primitive SBOLetter
  fun code(): String val => "OLetter"
  fun string(): String val => "OLetter"
primitive SBNumeric
  fun code(): String val => "Numeric"
  fun string(): String val => "Numeric"
primitive SBATerm
  fun code(): String val => "ATerm"
  fun string(): String val => "ATerm"
primitive SBSTerm
  fun code(): String val => "STerm"
  fun string(): String val => "STerm"
primitive SBClose
  fun code(): String val => "Close"
  fun string(): String val => "Close"
primitive SBSContinue
  fun code(): String val => "SContinue"
  fun string(): String val => "SContinue"

type SentenceBreak is
  ( SBOther | SBCR | SBLF | SBExtend | SBSep | SBFormat | SBSp
  | SBLower | SBUpper | SBOLetter | SBNumeric | SBATerm | SBSTerm
  | SBClose | SBSContinue
  )

primitive SentenceBreaks
  fun from_iso(s: String box): (SentenceBreak | None) =>
    match s
    | "Other" => SBOther
    | "CR" => SBCR
    | "LF" => SBLF
    | "Extend" => SBExtend
    | "Sep" => SBSep
    | "Format" => SBFormat
    | "Sp" => SBSp
    | "Lower" => SBLower
    | "Upper" => SBUpper
    | "OLetter" => SBOLetter
    | "Numeric" => SBNumeric
    | "ATerm" => SBATerm
    | "STerm" => SBSTerm
    | "Close" => SBClose
    | "SContinue" => SBSContinue
    else None
    end

  fun _to_byte(s: SentenceBreak): U8 =>
    match s
    | SBOther     => 0
    | SBCR        => 1
    | SBLF        => 2
    | SBExtend    => 3
    | SBSep       => 4
    | SBFormat    => 5
    | SBSp        => 6
    | SBLower     => 7
    | SBUpper     => 8
    | SBOLetter   => 9
    | SBNumeric   => 10
    | SBATerm     => 11
    | SBSTerm     => 12
    | SBClose     => 13
    | SBSContinue => 14
    end

  fun _from_byte(b: U8): SentenceBreak =>
    match b
    | 1  => SBCR
    | 2  => SBLF
    | 3  => SBExtend
    | 4  => SBSep
    | 5  => SBFormat
    | 6  => SBSp
    | 7  => SBLower
    | 8  => SBUpper
    | 9  => SBOLetter
    | 10 => SBNumeric
    | 11 => SBATerm
    | 12 => SBSTerm
    | 13 => SBClose
    | 14 => SBSContinue
    else SBOther
    end
