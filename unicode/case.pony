// Case operations: upper / lower / title / fold over `String box`.
//
// Per UAX #21, "full" case mappings can expand to multiple codepoints
// (e.g., ß → SS, ﬁ → FI). For each codepoint we prefer the full
// mapping from SpecialCasing.txt; if absent, we fall back to the
// single-codepoint Simple mapping from UnicodeData.txt.
//
// Casefolding ("fold") flattens case differences for caseless
// comparison. Default folding uses CaseFolding.txt's C+F entries
// (full folding). M5 normalization is NOT applied — for true caseless
// equality you'd typically normalize-then-fold or fold-then-normalize.
//
// Locale- and context-sensitive rules (Turkic I-dot, Greek final
// sigma, Lithuanian dot-above) are deferred — they need conditional
// SpecialCasing entries that M1.D explicitly skipped. The current
// implementation produces the "Default" case mappings.
//
// Titlecase here is the "simple word-start" form: a cp is titlecased
// if it's at the start of the string or follows a White_Space cp;
// otherwise it's lowercased. This isn't full UAX #21 (which uses UAX
// #29 word boundaries) but is the common-case useful behavior.

primitive Case
  fun upper(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Uppercase every cp via its full (multi-cp) or simple (single-cp)
    Uppercase mapping. Returns `InvalidUtf8` for ill-formed input.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _upper(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun lower(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Lowercase every cp via its full or simple Lowercase mapping.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _lower(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun title(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Titlecase using a "simple word-start" rule: cps at the start of
    the string or following a White_Space cp are titlecased; others
    are lowercased. See the file header for limitations.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _title(s)
    | let off: USize => InvalidUtf8(off)
    end

  fun fold(s: String box): (String iso^ | InvalidUtf8) =>
    """
    Default full case folding for caseless comparison. Each cp is
    replaced by its full casefold expansion if present, else its
    simple casefold, else itself.
    """
    match Bytes.first_bad_utf8_offset(s)
    | AllValid => _fold(s)
    | let off: USize => InvalidUtf8(off)
    end

  // ============================================================
  // Workhorses (assume valid UTF-8)
  // ============================================================

  fun _upper(utf8: String box): String iso^ =>
    let out = recover iso String(utf8.size()) end
    for cp in utf8.runes() do
      match Codepoints.full_upper(cp)
      | let a: Array[U32] val =>
        for u in a.values() do out.push_utf32(u) end
      | None =>
        out.push_utf32(Codepoints.simple_upper(cp))
      end
    end
    consume out

  fun _lower(utf8: String box): String iso^ =>
    let out = recover iso String(utf8.size()) end
    for cp in utf8.runes() do
      match Codepoints.full_lower(cp)
      | let a: Array[U32] val =>
        for u in a.values() do out.push_utf32(u) end
      | None =>
        out.push_utf32(Codepoints.simple_lower(cp))
      end
    end
    consume out

  fun _title(utf8: String box): String iso^ =>
    let out = recover iso String(utf8.size()) end
    var at_word_start: Bool = true
    for cp in utf8.runes() do
      if Codepoints.has_binary_property(cp, PropWhiteSpace) then
        out.push_utf32(cp)
        at_word_start = true
      elseif at_word_start then
        match Codepoints.full_title(cp)
        | let a: Array[U32] val =>
          for u in a.values() do out.push_utf32(u) end
        | None =>
          out.push_utf32(Codepoints.simple_title(cp))
        end
        at_word_start = false
      else
        match Codepoints.full_lower(cp)
        | let a: Array[U32] val =>
          for u in a.values() do out.push_utf32(u) end
        | None =>
          out.push_utf32(Codepoints.simple_lower(cp))
        end
      end
    end
    consume out

  fun _fold(utf8: String box): String iso^ =>
    let out = recover iso String(utf8.size()) end
    for cp in utf8.runes() do
      match Codepoints.full_casefold(cp)
      | let a: Array[U32] val =>
        for u in a.values() do out.push_utf32(u) end
      | None =>
        out.push_utf32(Codepoints.simple_casefold(cp))
      end
    end
    consume out
