// `Codepoint val` — typed wrapper around a validated Unicode scalar value.
//
// A `Codepoint` is constructed via `Codepoints.from_u32(u)` (validating) or
// `Codepoint._create(u)` (package-private, caller guarantees validity).
// The wrapped `U32` is always in the scalar-value range:
// 0x0000..0xD7FF or 0xE000..0x10FFFF — surrogates and out-of-range values
// can never appear in a `Codepoint`.
//
// For hot iteration (`Text.codepoints()`), users get bare `U32` instead —
// see design/candidate-v3.md §4.2 for the split-path rationale. `Codepoint`
// exists for the type-safe boundary case (constructing from external
// input, holding in a typed collection, etc.).

// Codepoint structurally satisfies Equatable[Codepoint], Comparable[Codepoint],
// Hashable, and Stringable via its methods below; no explicit `is` clause is
// needed (Pony interfaces are structural).
class val Codepoint
  let _scalar: U32

  new val _create(value: U32) =>
    """
    Package-private constructor. Caller must have proved that `value`
    is a Unicode scalar value (0x0000..0xD7FF or 0xE000..0x10FFFF).
    Calling this with a surrogate or out-of-range value is a package
    bug.
    """
    _scalar = value

  fun scalar(): U32 =>
    """
    The underlying U32 scalar value.
    """
    _scalar

  fun category(): Category =>
    """
    UAX #44 General Category of this codepoint.
    """
    _UcdCategory.of(_scalar)

  fun combining_class(): U8 =>
    """
    Canonical Combining Class. Most codepoints return 0 (Not_Reordered);
    only combining marks have non-zero values.
    """
    _UcdCombiningClass.of(_scalar)

  fun canonical_decomposition(): (Array[U32] val | None) =>
    """
    Canonical Decomposition_Mapping per UAX #44. Returns `None` for
    codepoints with no canonical decomposition (including Hangul
    syllables — their decomposition is algorithmic).
    """
    _UcdCanonicalDecomp.of(_scalar)

  fun is_letter(): Bool =>
    """
    True iff this codepoint's General Category is one of the Letter
    categories: Lu, Ll, Lt, Lm, Lo.
    """
    Codepoints._is_letter_category(category())

  fun is_digit(): Bool =>
    """
    True iff General Category is Decimal_Number (Nd). Letter-number
    (Nl, e.g., Roman numerals) and other-number (No) are NOT
    considered digits by this predicate.
    """
    Codepoints._is_digit_category(category())

  fun is_whitespace(): Bool =>
    """
    True iff this codepoint is whitespace per a category-based
    approximation: General Category in {Zs, Zl, Zp} plus a few
    specific ASCII / Latin-1 control codes (HT, LF, VT, FF, CR, NEL).

    NOTE: this is NOT the full UAX #44 `White_Space` property — the
    full version requires the PropList.txt-derived table (lands with
    M3b). For the common case of "is this an ASCII or Unicode space
    separator," the category-based answer matches.
    """
    Codepoints._is_whitespace_approx(_scalar, category())

  fun is_assigned(): Bool =>
    """
    True iff this codepoint is assigned in the bundled UCD — i.e.,
    its General Category is anything other than `Cn` (Unassigned).
    Use this to detect input that may contain codepoints from a
    newer Unicode version than this package was built against.
    """
    not (category() is Cn)

  fun script(): Script =>
    """
    The Script property of this codepoint per Scripts.txt. Returns
    `ScriptUnknown` for codepoints with no assigned script.
    """
    _UcdScript.of(_scalar)

  fun script_extensions(): Array[Script] val =>
    """
    The Script_Extensions property per UAX #24. Returns the set of
    scripts that use this codepoint; for codepoints not listed in
    ScriptExtensions.txt the result is `[script()]`.
    """
    Codepoints.script_extensions(_scalar)

  fun has_property(p: BinaryProperty): Bool =>
    """
    True iff this codepoint has the binary property `p` per
    PropList.txt, DerivedCoreProperties.txt, or emoji-data.txt.
    """
    _UcdBinaryProps.has(_scalar, p)

  fun east_asian_width(): EastAsianWidth =>
    """
    The East_Asian_Width property of this codepoint per UAX #11.
    Returns `EAWN` (Neutral) for codepoints with no explicit
    assignment.
    """
    _UcdEastAsianWidth.of(_scalar)

  fun eq(that: Codepoint box): Bool =>
    _scalar == that._scalar

  fun lt(that: Codepoint box): Bool =>
    _scalar < that._scalar

  fun hash(): USize =>
    _scalar.hash()

  fun string(): String iso^ =>
    """
    Hex representation in the form `U+XXXX` (with 4 or more hex digits
    as needed). Suitable for debug output and error messages.
    """
    let digits = "0123456789ABCDEF"
    let out = recover iso String(8) end
    out.append("U+")
    var n: U32 = _scalar
    let tmp = recover ref Array[U8](8) end
    if n == 0 then tmp.push('0') end
    while n > 0 do
      try tmp.push(digits(USize.from[U32](n and 0xF))?) end
      n = n >> 4
    end
    // Pad to at least 4 digits.
    while tmp.size() < 4 do tmp.push('0') end
    var i = tmp.size()
    while i > 0 do
      try out.push(tmp(i - 1)?) end
      i = i - 1
    end
    consume out
