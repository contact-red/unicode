// `Indic_Conjunct_Break` property values (UAX #44, added Unicode 15.1).
//
// Used by UAX #29 rule GB9c to suppress cluster breaks within Indic
// conjuncts of the form:
//
//   Consonant [Extend|Linker]* Linker [Extend|Linker]* × Consonant
//
// The four values match DerivedCoreProperties.txt's `InCB` property:
//
//   None       — default; codepoint isn't involved in Indic conjunct
//                linking.
//   Consonant  — a Linking Consonant (Devanagari KA, Bengali KA, ...).
//   Linker     — a Conjunct Linker (DEVANAGARI SIGN VIRAMA, etc.).
//   Extend     — Extend-class cp valid inside a conjunct (NUKTA, ZWJ).
//
// Like the other closed unions in this package, exhaustive `match`
// over `IndicConjunctBreak` is compile-checked.

primitive InCBNone
  fun code(): String val => "None"
  fun string(): String val => "None"

primitive InCBConsonant
  fun code(): String val => "Consonant"
  fun string(): String val => "Consonant"

primitive InCBLinker
  fun code(): String val => "Linker"
  fun string(): String val => "Linker"

primitive InCBExtend
  fun code(): String val => "Extend"
  fun string(): String val => "Extend"

type IndicConjunctBreak is (InCBNone | InCBConsonant | InCBLinker | InCBExtend)

primitive IndicConjunctBreaks
  fun from_iso(s: String box): (IndicConjunctBreak | None) =>
    match s
    | "None" => InCBNone
    | "Consonant" => InCBConsonant
    | "Linker" => InCBLinker
    | "Extend" => InCBExtend
    else None
    end

  fun _to_byte(b: IndicConjunctBreak): U8 =>
    match b
    | InCBNone      => 0
    | InCBConsonant => 1
    | InCBLinker    => 2
    | InCBExtend    => 3
    end

  fun _from_byte(b: U8): IndicConjunctBreak =>
    match b
    | 1 => InCBConsonant
    | 2 => InCBLinker
    | 3 => InCBExtend
    else InCBNone
    end
