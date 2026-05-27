// `Codepoints` topical primitive.
//
// The plural primitive serves as both the codepoint factory layer and the
// U32-form predicate / property layer. Per design/candidate-v3.md §4.2,
// receiver type signals scale: functions taking `U32` operate on a single
// codepoint; functions taking `String box` operate on a string of
// codepoints.
//
// M1 ships only `category(u: U32)` so the generated UCD category table
// (`_UcdCategory`) has a public-facing entry point and the table can be
// tested. M3 fills out the rest of the primitive (factories, predicates,
// string-level ops).

primitive Codepoints
  fun category(u: U32): Category =>
    """
    The Unicode General Category of `u`. For codepoints outside the
    assigned Unicode space (or above U+10FFFF), returns `Cn` (Unassigned).

    Non-scalar U32 values (surrogates U+D800..U+DFFF, or values above
    U+10FFFF) are accepted — they have no valid Unicode interpretation,
    so the table answer is whatever the UCD assigned. Callers that need
    scalar-value validation should call `is_scalar(u)` first (M3+).
    """
    _UcdCategory.of(u)

  fun combining_class(u: U32): U8 =>
    """
    The Canonical Combining Class (CCC) of `u` per UAX #44. Most
    codepoints have CCC=0 (Not_Reordered); only combining marks have
    non-zero values. Used by the normalization algorithm to canonically
    order combining marks during NFD/NFKD.
    """
    _UcdCombiningClass.of(u)

  fun canonical_decomposition(u: U32): (Array[U32] val | None) =>
    """
    The canonical Decomposition_Mapping of `u`, if any. Returns `None`
    for codepoints with no canonical decomposition (including Hangul
    syllables, whose decomposition is algorithmic — see UAX #15 §10.1).
    Returns a `Some` array of 1 or 2 codepoints otherwise.

    Compatibility decompositions (used by NFKC/NFKD) are not returned
    here; they have a separate accessor (M5+).
    """
    _UcdCanonicalDecomp.of(u)
