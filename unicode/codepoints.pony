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
