// UAX #29 Grapheme_Cluster_Break property values.
//
// The 13 standard values from `auxiliary/GraphemeBreakProperty.txt` plus
// `Extended_Pictographic` (sourced from `emoji/emoji-data.txt`), plus
// `GBOther` for codepoints with no assigned value. The grapheme-break
// state machine in `_GraphemeCursor` (M4b) consumes these to decide
// where cluster boundaries fall.
//
// Naming: most UAX #29 break property names collide with other tokens
// in this package (`Control` could be confused with the `Cc` category
// alias, `Extend` is a verb, etc.). To keep the runtime values clear we
// prefix every primitive with `GB`. ISO codes returned by `code()`
// match the property names from UAX #29 verbatim so conformance-test
// strings line up.

primitive GBCR
  fun code(): String val => "CR"
  fun string(): String iso^ => "CR".clone()

primitive GBLF
  fun code(): String val => "LF"
  fun string(): String iso^ => "LF".clone()

primitive GBControl
  fun code(): String val => "Control"
  fun string(): String iso^ => "Control".clone()

primitive GBExtend
  fun code(): String val => "Extend"
  fun string(): String iso^ => "Extend".clone()

primitive GBZWJ
  fun code(): String val => "ZWJ"
  fun string(): String iso^ => "ZWJ".clone()

primitive GBRegionalIndicator
  fun code(): String val => "Regional_Indicator"
  fun string(): String iso^ => "Regional_Indicator".clone()

primitive GBPrepend
  fun code(): String val => "Prepend"
  fun string(): String iso^ => "Prepend".clone()

primitive GBSpacingMark
  fun code(): String val => "SpacingMark"
  fun string(): String iso^ => "SpacingMark".clone()

primitive GBL
  fun code(): String val => "L"
  fun string(): String iso^ => "L".clone()

primitive GBV
  fun code(): String val => "V"
  fun string(): String iso^ => "V".clone()

primitive GBT
  fun code(): String val => "T"
  fun string(): String iso^ => "T".clone()

primitive GBLV
  fun code(): String val => "LV"
  fun string(): String iso^ => "LV".clone()

primitive GBLVT
  fun code(): String val => "LVT"
  fun string(): String iso^ => "LVT".clone()

primitive GBExtendedPictographic
  fun code(): String val => "Extended_Pictographic"
  fun string(): String iso^ => "Extended_Pictographic".clone()

primitive GBOther
  fun code(): String val => "Other"
  fun string(): String iso^ => "Other".clone()

type GraphemeBreak is
  ( GBCR | GBLF | GBControl | GBExtend | GBZWJ
  | GBRegionalIndicator | GBPrepend | GBSpacingMark
  | GBL | GBV | GBT | GBLV | GBLVT
  | GBExtendedPictographic | GBOther
  )

primitive GraphemeBreaks
  fun from_iso(s: String box): (GraphemeBreak | None) =>
    """
    Look up a Grapheme_Cluster_Break value by its UAX #29 name
    (case-sensitive). Returns `None` for unknown names.
    """
    match s
    | "CR" => GBCR | "LF" => GBLF
    | "Control" => GBControl | "Extend" => GBExtend | "ZWJ" => GBZWJ
    | "Regional_Indicator" => GBRegionalIndicator
    | "Prepend" => GBPrepend | "SpacingMark" => GBSpacingMark
    | "L" => GBL | "V" => GBV | "T" => GBT
    | "LV" => GBLV | "LVT" => GBLVT
    | "Extended_Pictographic" => GBExtendedPictographic
    | "Other" => GBOther
    else None
    end

  fun _to_byte(g: GraphemeBreak): U8 =>
    """
    Stable byte encoding for the 15 Grapheme_Break variants. Mirrors
    the codegen-side mapping in `unicode_build/grapheme_break_codes.pony`.
    """
    match g
    | GBOther => 0
    | GBCR => 1  | GBLF => 2  | GBControl => 3
    | GBExtend => 4 | GBZWJ => 5
    | GBRegionalIndicator => 6
    | GBPrepend => 7 | GBSpacingMark => 8
    | GBL => 9 | GBV => 10 | GBT => 11
    | GBLV => 12 | GBLVT => 13
    | GBExtendedPictographic => 14
    end

  fun _from_byte(b: U8): GraphemeBreak =>
    """
    Inverse of `_to_byte`. Unknown bytes return `GBOther`.
    """
    match b
    | 0  => GBOther
    | 1  => GBCR | 2  => GBLF | 3  => GBControl
    | 4  => GBExtend | 5  => GBZWJ
    | 6  => GBRegionalIndicator
    | 7  => GBPrepend | 8 => GBSpacingMark
    | 9  => GBL | 10 => GBV | 11 => GBT
    | 12 => GBLV | 13 => GBLVT
    | 14 => GBExtendedPictographic
    else GBOther
    end
