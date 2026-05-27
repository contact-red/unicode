// `Codepoints` topical primitive.
//
// Per design/candidate-v3.md §4.2, the plural primitive serves three
// roles via receiver type:
//
//   1. Codepoint factories (single-codepoint construction from `U32`)
//   2. U32-form predicates (operate on a single `U32`, validate scalar
//      then dispatch; suitable for hot iteration)
//   3. String-level operations (count, iter, is_all over `String box`,
//      validating UTF-8 first)
//
// Receiver type signals the scale: functions taking `U32` operate on a
// single codepoint; functions taking `String box` operate on a string
// of codepoints.

primitive Codepoints
  // ============================================================
  // Factories
  // ============================================================

  fun from_u32(u: U32): (Codepoint val | InvalidScalar) =>
    """
    Wrap a U32 as a `Codepoint val` after validating it as a Unicode
    scalar value (0x0000..0xD7FF or 0xE000..0x10FFFF). Returns
    `InvalidScalar` for surrogates or values above U+10FFFF.
    """
    if is_scalar(u) then Codepoint._create(u)
    else InvalidScalar(u)
    end

  // ============================================================
  // U32-form predicates
  // ============================================================

  fun is_scalar(u: U32): Bool =>
    """
    True iff `u` is a Unicode scalar value — the values that can appear
    in well-formed UTF-8. Equivalent to (u < 0xD800) or
    (0xE000 <= u <= 0x10FFFF).
    """
    (u < 0xD800) or ((u >= 0xE000) and (u <= 0x10FFFF))

  fun category(u: U32): Category =>
    """
    The Unicode General Category of `u`. For codepoints outside the
    assigned Unicode space (or above U+10FFFF), returns `Cn`.
    """
    _UcdCategory.of(u)

  fun combining_class(u: U32): U8 =>
    """
    Canonical Combining Class. Most codepoints return 0; only
    combining marks have non-zero values.
    """
    _UcdCombiningClass.of(u)

  fun canonical_decomposition(u: U32): (Array[U32] val | None) =>
    """
    Canonical Decomposition_Mapping. `None` if absent (including
    Hangul syllables — algorithmic).
    """
    _UcdCanonicalDecomp.of(u)

  fun grapheme_break(u: U32): GraphemeBreak =>
    """
    UAX #29 Grapheme_Cluster_Break property of `u`, including
    `Extended_Pictographic` for emoji per UTS #51. Used by the
    grapheme-break state machine to decide cluster boundaries.
    Codepoints with no assigned value default to `GBOther`.
    """
    _UcdGraphemeBreak.of(u)

  fun is_full_composition_excluded(u: U32): Bool =>
    """
    True iff `u` has the `Full_Composition_Exclusion` property per
    DerivedNormalizationProps.txt. Used by NFC composition (M5).
    """
    _UcdCompositionExclusion.of(u)

  fun compose_canonical(lhs: U32, rhs: U32): (U32 | None) =>
    """
    Canonical composition: `(lhs, rhs)` → `result` for primary
    composites (entries whose target is not in the
    Full_Composition_Exclusion set). Returns `None` if no composition
    exists. Used by NFC (M5).
    """
    _UcdCanonicalCompose.of(lhs, rhs)

  fun is_letter(u: U32): Bool =>
    """
    True iff `u` is a scalar AND its General Category is one of the
    Letter categories: Lu, Ll, Lt, Lm, Lo. Non-scalar U32 values
    return false.
    """
    if is_scalar(u) then _is_letter_category(_UcdCategory.of(u))
    else false
    end

  fun is_digit(u: U32): Bool =>
    """
    True iff `u` is a scalar AND its General Category is Decimal_Number
    (Nd). Non-scalar U32 values return false.
    """
    if is_scalar(u) then _is_digit_category(_UcdCategory.of(u))
    else false
    end

  fun is_whitespace(u: U32): Bool =>
    """
    True iff `u` is whitespace per a category-based approximation
    (see `Codepoint.is_whitespace`). Non-scalar U32 values return
    false.
    """
    if is_scalar(u) then _is_whitespace_approx(u, _UcdCategory.of(u))
    else false
    end

  fun is_assigned(u: U32): Bool =>
    """
    True iff `u` is a scalar AND its General Category is anything other
    than `Cn` (Unassigned). Non-scalar U32 values return false.
    """
    if is_scalar(u) then not (_UcdCategory.of(u) is Cn)
    else false
    end

  // ============================================================
  // String-level operations
  // ============================================================

  fun count(s: String box): (USize | InvalidUtf8) =>
    """
    Number of Unicode codepoints in `s`. Returns `InvalidUtf8` if `s`
    isn't well-formed UTF-8 — error carries the byte offset of the
    first ill-formed sequence.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _count(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun is_all(s: String box, p: {(U32): Bool} val)
    : (Bool | InvalidUtf8)
  =>
    """
    True iff every codepoint in `s` satisfies the predicate `p`. An
    empty string returns true (vacuously). Returns `InvalidUtf8` if
    `s` isn't well-formed UTF-8.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _is_all(s, p)
    | let off: USize => InvalidUtf8(off)
    end

  // ============================================================
  // Package-private workhorses (assume valid UTF-8)
  // ============================================================

  fun _count(utf8: String box): USize =>
    """
    Count codepoints in a String already known to be valid UTF-8.
    """
    var n: USize = 0
    for _ in utf8.runes() do n = n + 1 end
    n

  fun _is_all(utf8: String box, p: {(U32): Bool} val): Bool =>
    """
    Check predicate over every codepoint of valid-UTF-8 input.
    """
    for u in utf8.runes() do
      if not p(u) then return false end
    end
    true

  // ============================================================
  // Category-classification helpers (used by both Codepoint and
  // Codepoints; kept here so the rule lives in one place).
  // ============================================================

  fun _is_letter_category(c: Category): Bool =>
    match c
    | Lu => true | Ll => true | Lt => true | Lm => true | Lo => true
    else false
    end

  fun _is_digit_category(c: Category): Bool =>
    c is Nd

  fun _is_whitespace_approx(u: U32, c: Category): Bool =>
    """
    Category-based whitespace approximation. The full UAX #44
    `White_Space` property includes additional non-category-marked
    codepoints (e.g., TAB U+0009, LF U+000A, VT U+000B, FF U+000C,
    CR U+000D, NEL U+0085) and excludes a few category-Z codepoints
    that the property doesn't tag (none in practice as of Unicode 16).
    This approximation hand-lists the ASCII / Latin-1 control codes
    and otherwise uses the category.
    """
    // Specific ASCII / Latin-1 control codes tagged as White_Space.
    if (u == 0x09) or (u == 0x0A) or (u == 0x0B) or (u == 0x0C)
      or (u == 0x0D) or (u == 0x85)
    then
      return true
    end
    match c
    | Zs => true | Zl => true | Zp => true
    else false
    end
