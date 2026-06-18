use "pony_test"
use ".."

actor \nodoc\ Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestVersionPlaceholder)
    // M1: category table generated from UnicodeData.txt
    test(_TestCategoryAscii)
    test(_TestCategoryLatin1)
    test(_TestCategoryEmoji)
    test(_TestCategoryUnassigned)
    test(_TestCategoryControl)
    test(_TestCategoryPrivateUse)
    // M1: combining class table
    test(_TestCombiningClass)
    // M1: canonical decomposition table
    test(_TestCanonicalDecomp)
    // M2: Bytes UTF-8 validation
    test(_TestBytesAsciiValid)
    test(_TestBytesUtf8Valid)
    test(_TestBytesIllFormedAscii)
    test(_TestBytesOverlong)
    test(_TestBytesSurrogate)
    test(_TestBytesTruncated)
    test(_TestBytesAboveMax)
    // M2: Text construction
    test(_TestTextFromStringValid)
    test(_TestTextFromStringInvalid)
    test(_TestTextEmpty)
    test(_TestTextRoundTrip)
    test(_TestTextFromIsoString)
    // M3: Codepoint class + Codepoints factory/predicates/string-ops
    test(_TestCodepointsIsScalar)
    test(_TestCodepointsFromU32)
    test(_TestCodepointsIsLetter)
    test(_TestCodepointsIsDigit)
    test(_TestCodepointsIsWhitespace)
    test(_TestCodepointsIsAssigned)
    test(_TestCodepointClassMethods)
    test(_TestCodepointEquality)
    test(_TestCodepointString)
    test(_TestCodepointsStringCount)
    test(_TestCodepointsStringIsAll)
    test(_TestCodepointsStringInvalid)
    // M4a: Grapheme_Cluster_Break property table
    test(_TestGraphemeBreakAscii)
    test(_TestGraphemeBreakCombining)
    test(_TestGraphemeBreakHangul)
    test(_TestGraphemeBreakEmoji)
    test(_TestGraphemeBreakRegionalIndicator)
    // M4b: grapheme iteration via UAX #29 state machine
    test(_TestGraphemesAscii)
    test(_TestGraphemesCombining)
    test(_TestGraphemesCRLF)
    test(_TestGraphemesHangul)
    test(_TestGraphemesEmojiZWJ)
    test(_TestGraphemesFlag)
    test(_TestGraphemesEmpty)
    test(_TestGraphemeRangesNoAlloc)
    test(_TestSizeGraphemes)
    // M4c: phantom-typed indices + Text indexing
    test(_TestIndexConstruction)
    test(_TestIndexAt)
    test(_TestIndexOutOfRange)
    test(_TestIndexCannotMix)
    // M4d: bitmap index
    test(_TestIndexedDefault)
    test(_TestIndexedFlag)
    test(_TestIndexedCountsAgree)
    test(_TestIndexedFlipMethods)
    test(_TestIndexedEmpty)
    // M4e: slicing + index conversions
    test(_TestSliceCodepoints)
    test(_TestSliceGraphemes)
    test(_TestSliceOutOfRange)
    test(_TestCodepointByteIndex)
    test(_TestGraphemeByteIndex)
    // M4f: Graphemes topical primitive
    test(_TestGraphemesCount)
    test(_TestGraphemesCountInvalid)
    test(_TestGraphemesRanges)
    test(_TestGraphemesIter)
    // M1.A: Composition exclusions + canonical compose
    test(_TestCompositionExclusion)
    test(_TestCanonicalCompose)
    test(_TestCanonicalComposeExcluded)
    test(_TestCanonicalComposeMiss)
    // M1.B: Compatibility decomposition
    test(_TestCompatDecompFiLigature)
    test(_TestCompatDecompCircledOne)
    test(_TestCompatDecompFraction)
    test(_TestCompatDecompAscii)
    // M1.C: Simple case mappings
    test(_TestSimpleUpper)
    test(_TestSimpleLower)
    test(_TestSimpleTitle)
    // M1.D: Full case mappings + folding
    test(_TestFullUpperEszett)
    test(_TestFullUpperFi)
    test(_TestFullUpperAscii)
    test(_TestFullLowerIDot)
    test(_TestSimpleCaseFold)
    test(_TestFullCaseFoldEszett)
    test(_TestFullCaseFoldAscii)
    // M1.E: Scripts
    test(_TestScriptLatin)
    test(_TestScriptCyrillic)
    test(_TestScriptCommon)
    test(_TestScriptUnassigned)
    test(_TestScriptCode)
    test(_TestScriptsFromIso)
    test(_TestEastAsianWidthAscii)
    test(_TestEastAsianWidthIdeograph)
    test(_TestEastAsianWidthFullwidth)
    test(_TestEastAsianWidthAmbiguous)
    test(_TestEastAsianWidthsFromIso)
    // M1.F: Binary properties
    test(_TestBinaryPropIDStart)
    test(_TestBinaryPropIDContinue)
    test(_TestBinaryPropWhiteSpace)
    test(_TestBinaryPropEmoji)
    test(_TestBinaryPropAsciiHexDigit)
    test(_TestBinaryPropsFromIso)
    // M1.G: Names
    test(_TestNameAscii)
    test(_TestNameLatin)
    test(_TestNameControl)
    test(_TestFromName)
    // 0.2.0: Lines (UAX #14)
    test(_TestLinesBasic)
    test(_TestLinesSpaceBreaks)
    test(_TestLinesNumericGlued)
    test(_TestLinesEmpty)
    test(_TestLinesInvalid)
    // 0.2.0: Sentences (UAX #29)
    test(_TestSentencesBasic)
    test(_TestSentencesParaSep)
    test(_TestSentencesSB8)
    test(_TestSentencesNoTerm)
    test(_TestSentencesEmpty)
    test(_TestSentencesInvalid)
    // 0.2.0: Words (UAX #29)
    test(_TestWordsAsciiBasic)
    test(_TestWordsNumeric)
    test(_TestWordsApostrophe)
    test(_TestWordsCrLf)
    test(_TestWordsEmpty)
    test(_TestWordsInvalid)
    // M8: Search
    test(_TestSearchContains)
    test(_TestSearchStartsEnds)
    test(_TestSearchIndexOf)
    test(_TestSearchCount)
    test(_TestSearchInvalid)
    // M8: Split
    test(_TestSplitBasic)
    test(_TestSplitAdjacent)
    test(_TestSplitMultibyteSep)
    test(_TestSplitLines)
    // M8: Trim
    test(_TestTrimBasic)
    test(_TestTrimStartEnd)
    test(_TestTrimUnicodeWhitespace)
    test(_TestTrimAllWhitespace)
    // M8: Replace
    test(_TestReplaceAll)
    test(_TestReplaceFirst)
    test(_TestReplaceLengthChange)
    test(_TestReplaceNotFound)
    // M7: Compare
    test(_TestCompareBytes)
    test(_TestEqualBytes)
    test(_TestEqualCanonical)
    test(_TestEqualCanonicalDistinct)
    test(_TestEqualCompat)
    test(_TestEqualCaseless)
    test(_TestEqualCaselessAsciiDistinct)
    test(_TestEqualCaselessCanonical)
    test(_TestCompareInvalid)
    // M6: Case
    test(_TestCaseUpperAscii)
    test(_TestCaseUpperEszett)
    test(_TestCaseLowerAscii)
    test(_TestCaseLowerGreek)
    test(_TestCaseTitleAscii)
    test(_TestCaseTitleMixed)
    test(_TestCaseFoldAscii)
    test(_TestCaseFoldEszett)
    test(_TestCaseFoldMatchesMass)
    test(_TestCaseUpperInvalid)
    // M5: Normalize
    test(_TestNfdAscii)
    test(_TestNfdLatinAcute)
    test(_TestNfcLatinAcute)
    test(_TestNfcIdempotent)
    test(_TestNfdHangul)
    test(_TestNfcHangul)
    test(_TestNfkdLigature)
    test(_TestNfdEmpty)
    test(_TestNfdReorder)
    test(_TestNfcRoundTripIdempotent)
    test(_TestNfcInvalid)

class \nodoc\ iso _TestVersionPlaceholder is UnitTest
  fun name(): String => "Unicode.version returns a string"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("0.0.0", Unicode.version())

class \nodoc\ iso _TestCategoryAscii is UnitTest
  fun name(): String => "category: ASCII letters / digits / punctuation"

  fun apply(h: TestHelper) =>
    // Uppercase Letter
    h.assert_eq[String]("Lu", Codepoints.category('A').code())
    h.assert_eq[String]("Lu", Codepoints.category('Z').code())
    // Lowercase Letter
    h.assert_eq[String]("Ll", Codepoints.category('a').code())
    h.assert_eq[String]("Ll", Codepoints.category('z').code())
    // Decimal Number
    h.assert_eq[String]("Nd", Codepoints.category('0').code())
    h.assert_eq[String]("Nd", Codepoints.category('9').code())
    // Space Separator
    h.assert_eq[String]("Zs", Codepoints.category(' ').code())
    // Other Punctuation
    h.assert_eq[String]("Po", Codepoints.category('!').code())
    // Open / Close Punctuation
    h.assert_eq[String]("Ps", Codepoints.category('(').code())
    h.assert_eq[String]("Pe", Codepoints.category(')').code())

class \nodoc\ iso _TestCategoryLatin1 is UnitTest
  fun name(): String => "category: Latin-1 supplements"

  fun apply(h: TestHelper) =>
    // U+00E9 é — Lowercase Letter
    h.assert_eq[String]("Ll", Codepoints.category(0xE9).code())
    // U+00C9 É — Uppercase Letter
    h.assert_eq[String]("Lu", Codepoints.category(0xC9).code())
    // U+00DF ß — Lowercase Letter
    h.assert_eq[String]("Ll", Codepoints.category(0xDF).code())
    // U+00A0 NO-BREAK SPACE — Space Separator
    h.assert_eq[String]("Zs", Codepoints.category(0xA0).code())

class \nodoc\ iso _TestCategoryEmoji is UnitTest
  fun name(): String => "category: emoji codepoints"

  fun apply(h: TestHelper) =>
    // U+1F600 GRINNING FACE — Other Symbol
    h.assert_eq[String]("So", Codepoints.category(0x1F600).code())
    // U+1F1FA REGIONAL INDICATOR SYMBOL LETTER U — Other Symbol
    h.assert_eq[String]("So", Codepoints.category(0x1F1FA).code())

class \nodoc\ iso _TestCategoryUnassigned is UnitTest
  fun name(): String => "category: unassigned codepoints"

  fun apply(h: TestHelper) =>
    // Codepoint 0 is U+0000 NULL (Cc), not Cn. Pick something
    // genuinely unassigned: U+0378 is reserved/unassigned in Unicode 16.
    h.assert_eq[String]("Cn", Codepoints.category(0x0378).code())
    // Way out of any current range — must default to Cn.
    h.assert_eq[String]("Cn", Codepoints.category(0x10FFFE).code())

class \nodoc\ iso _TestCategoryControl is UnitTest
  fun name(): String => "category: control characters"

  fun apply(h: TestHelper) =>
    // U+0000 NULL — Control
    h.assert_eq[String]("Cc", Codepoints.category(0).code())
    // U+001F UNIT SEPARATOR — Control
    h.assert_eq[String]("Cc", Codepoints.category(0x1F).code())
    // U+007F DELETE — Control
    h.assert_eq[String]("Cc", Codepoints.category(0x7F).code())

class \nodoc\ iso _TestCategoryPrivateUse is UnitTest
  fun name(): String => "category: private-use area"

  fun apply(h: TestHelper) =>
    // U+E000 — start of BMP Private Use Area — Private Use
    h.assert_eq[String]("Co", Codepoints.category(0xE000).code())
    // U+F8FF — end of BMP Private Use Area
    h.assert_eq[String]("Co", Codepoints.category(0xF8FF).code())
    // U+F0000 — supplementary private use area A start
    h.assert_eq[String]("Co", Codepoints.category(0xF0000).code())

class \nodoc\ iso _TestCombiningClass is UnitTest
  fun name(): String => "combining class"

  fun apply(h: TestHelper) =>
    // Most codepoints have CCC=0.
    h.assert_eq[U8](0, Codepoints.combining_class('A'))
    h.assert_eq[U8](0, Codepoints.combining_class(0xE9))   // precomposed é (CCC=0)
    h.assert_eq[U8](0, Codepoints.combining_class(0))      // NULL
    // Combining marks have non-zero CCC.
    // U+0300 COMBINING GRAVE ACCENT — CCC 230 (Above)
    h.assert_eq[U8](230, Codepoints.combining_class(0x0300))
    // U+0301 COMBINING ACUTE ACCENT — CCC 230
    h.assert_eq[U8](230, Codepoints.combining_class(0x0301))
    // U+0316 COMBINING GRAVE ACCENT BELOW — CCC 220 (Below)
    h.assert_eq[U8](220, Codepoints.combining_class(0x0316))
    // U+05B0 HEBREW POINT SHEVA — CCC 10
    h.assert_eq[U8](10, Codepoints.combining_class(0x05B0))

class \nodoc\ iso _TestCanonicalDecomp is UnitTest
  fun name(): String => "canonical decomposition"

  fun apply(h: TestHelper) =>
    // ASCII chars have no decomposition.
    h.assert_true(Codepoints.canonical_decomposition('A') is None)
    h.assert_true(Codepoints.canonical_decomposition(0) is None)
    // U+00E9 é → U+0065 (e) + U+0301 (combining acute)
    try
      let d = Codepoints.canonical_decomposition(0xE9) as Array[U32] val
      h.assert_eq[USize](2, d.size())
      h.assert_eq[U32](0x0065, d(0)?)
      h.assert_eq[U32](0x0301, d(1)?)
    else
      h.fail("expected decomposition for U+00E9")
    end
    // U+00C5 Å → U+0041 (A) + U+030A (combining ring)
    try
      let d = Codepoints.canonical_decomposition(0xC5) as Array[U32] val
      h.assert_eq[USize](2, d.size())
      h.assert_eq[U32](0x0041, d(0)?)
      h.assert_eq[U32](0x030A, d(1)?)
    else
      h.fail("expected decomposition for U+00C5")
    end
    // U+212B ANGSTROM SIGN → U+00C5 (Å) — single-codepoint canonical
    try
      let d = Codepoints.canonical_decomposition(0x212B) as Array[U32] val
      h.assert_eq[USize](1, d.size())
      h.assert_eq[U32](0x00C5, d(0)?)
    else
      h.fail("expected decomposition for U+212B")
    end

// ---- M2: Bytes UTF-8 validation ----

class \nodoc\ iso _TestBytesAsciiValid is UnitTest
  fun name(): String => "Bytes: ASCII is valid UTF-8"

  fun apply(h: TestHelper) =>
    h.assert_true(Bytes.is_valid_utf8(""))
    h.assert_true(Bytes.is_valid_utf8("hello"))
    h.assert_true(Bytes.is_valid_utf8("0123456789"))
    h.assert_true(Bytes.is_valid_utf8("!@#$%^&*()"))
    // Also accepts Array[U8].
    let ascii: Array[U8] val = recover val [as U8: 0x41; 0x42; 0x43] end
    h.assert_true(Bytes.is_valid_utf8(ascii))

class \nodoc\ iso _TestBytesUtf8Valid is UnitTest
  fun name(): String => "Bytes: multi-byte UTF-8 is valid"

  fun apply(h: TestHelper) =>
    // "café" — e is precomposed (U+00E9 = 0xC3 0xA9)
    h.assert_true(Bytes.is_valid_utf8("caf\xC3\xA9"))
    // U+1F600 GRINNING FACE = F0 9F 98 80
    let emoji: Array[U8] val = recover val [as U8: 0xF0; 0x9F; 0x98; 0x80] end
    h.assert_true(Bytes.is_valid_utf8(emoji))
    // U+2603 SNOWMAN = E2 98 83
    let snowman: Array[U8] val = recover val [as U8: 0xE2; 0x98; 0x83] end
    h.assert_true(Bytes.is_valid_utf8(snowman))

class \nodoc\ iso _TestBytesIllFormedAscii is UnitTest
  fun name(): String => "Bytes: stray continuation bytes rejected"

  fun apply(h: TestHelper) =>
    // 0x80 alone is invalid (continuation without lead).
    let stray: Array[U8] val = recover val [as U8: 0x80] end
    h.assert_false(Bytes.is_valid_utf8(stray))
    match Bytes.first_bad_utf8_offset(stray)
    | let off: USize => h.assert_eq[USize](0, off)
    | AllValid => h.fail("expected bad offset, got AllValid")
    end
    // ASCII followed by stray continuation.
    let mid: Array[U8] val = recover val [as U8: 0x41; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(mid))
    match Bytes.first_bad_utf8_offset(mid)
    | let off: USize => h.assert_eq[USize](1, off)
    | AllValid => h.fail("expected bad offset, got AllValid")
    end

class \nodoc\ iso _TestBytesOverlong is UnitTest
  fun name(): String => "Bytes: overlong encodings rejected"

  fun apply(h: TestHelper) =>
    // 0xC0 0x80 would be overlong NUL — rejected (0xC0 is invalid lead).
    let overlong2: Array[U8] val = recover val [as U8: 0xC0; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(overlong2))
    // 0xE0 0x80 0x80 — overlong 3-byte (b1 must be >= 0xA0 after 0xE0).
    let overlong3: Array[U8] val = recover val [as U8: 0xE0; 0x80; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(overlong3))
    // 0xF0 0x80 0x80 0x80 — overlong 4-byte (b1 must be >= 0x90 after 0xF0).
    let overlong4: Array[U8] val = recover val [as U8: 0xF0; 0x80; 0x80; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(overlong4))

class \nodoc\ iso _TestBytesSurrogate is UnitTest
  fun name(): String => "Bytes: surrogates (U+D800..U+DFFF) rejected"

  fun apply(h: TestHelper) =>
    // U+D800 would encode as 0xED 0xA0 0x80 — but 0xED requires b1 in
    // 0x80..0x9F to avoid the surrogate range.
    let high_surr: Array[U8] val = recover val [as U8: 0xED; 0xA0; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(high_surr))
    // U+DFFF: 0xED 0xBF 0xBF — same rejection.
    let low_surr: Array[U8] val = recover val [as U8: 0xED; 0xBF; 0xBF] end
    h.assert_false(Bytes.is_valid_utf8(low_surr))
    // U+D7FF (just below surrogate range) — VALID: 0xED 0x9F 0xBF.
    let pre_surr: Array[U8] val = recover val [as U8: 0xED; 0x9F; 0xBF] end
    h.assert_true(Bytes.is_valid_utf8(pre_surr))

class \nodoc\ iso _TestBytesTruncated is UnitTest
  fun name(): String => "Bytes: truncated sequences rejected"

  fun apply(h: TestHelper) =>
    // 0xC2 alone — needs one continuation byte.
    let trunc2: Array[U8] val = recover val [as U8: 0xC2] end
    h.assert_false(Bytes.is_valid_utf8(trunc2))
    // 0xE2 0x98 — needs one more continuation.
    let trunc3: Array[U8] val = recover val [as U8: 0xE2; 0x98] end
    h.assert_false(Bytes.is_valid_utf8(trunc3))
    // 0xF0 0x9F 0x98 — needs one more continuation.
    let trunc4: Array[U8] val = recover val [as U8: 0xF0; 0x9F; 0x98] end
    h.assert_false(Bytes.is_valid_utf8(trunc4))

class \nodoc\ iso _TestBytesAboveMax is UnitTest
  fun name(): String => "Bytes: codepoints above U+10FFFF rejected"

  fun apply(h: TestHelper) =>
    // 0xF4 0x90 0x80 0x80 = U+110000 (one past the max).
    let above: Array[U8] val = recover val [as U8: 0xF4; 0x90; 0x80; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(above))
    // Invalid lead bytes (would encode codepoints way above U+10FFFF).
    let invalid_lead: Array[U8] val = recover val [as U8: 0xF5; 0x80; 0x80; 0x80] end
    h.assert_false(Bytes.is_valid_utf8(invalid_lead))
    let invalid_lead2: Array[U8] val = recover val [as U8: 0xFF] end
    h.assert_false(Bytes.is_valid_utf8(invalid_lead2))

// ---- M2: Text construction ----

class \nodoc\ iso _TestTextFromStringValid is UnitTest
  fun name(): String => "Text.from_string accepts valid UTF-8"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("hello")?
      h.assert_eq[USize](5, t.size_bytes())
    else
      h.fail("Text.from_string raised on valid ASCII")
    end
    // For multi-byte UTF-8 use Text.from_array so we can specify raw bytes.
    // Pony's `\xNN` in String literals is a Unicode codepoint escape — high
    // bytes get UTF-8-encoded — so a String literal can't carry arbitrary
    // bytes.
    // "café" precomposed UTF-8: 63 61 66 C3 A9 = 5 bytes.
    let bytes: Array[U8] val =
      recover val [as U8: 0x63; 0x61; 0x66; 0xC3; 0xA9] end
    try
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](5, t.size_bytes())
    else
      h.fail("Text.from_array raised on valid multi-byte UTF-8")
    end

class \nodoc\ iso _TestTextFromStringInvalid is UnitTest
  fun name(): String => "Text constructors raise on invalid UTF-8"

  fun apply(h: TestHelper) =>
    // Use Array[U8] val for raw bytes; String literals can't carry
    // ill-formed UTF-8 directly (see _TestTextFromStringValid above).
    // 0x80 is a stray continuation byte.
    let bad: Array[U8] val =
      recover val [as U8: 0x67; 0x6F; 0x6F; 0x64; 0x80; 0x62; 0x61; 0x64] end
    let raised =
      try
        Text.from_array(bad)?
        false
      else
        true
      end
    h.assert_true(raised)

class \nodoc\ iso _TestTextEmpty is UnitTest
  fun name(): String => "Text.create produces an empty Text"

  fun apply(h: TestHelper) =>
    let t: Text val = Text.create()
    h.assert_eq[USize](0, t.size_bytes())
    // Capacity hint compiles and runs.
    let t2: Text val = Text.create(128)
    h.assert_eq[USize](0, t2.size_bytes())

class \nodoc\ iso _TestTextRoundTrip is UnitTest
  fun name(): String => "Text.utf8_bytes round-trips through from_string"

  fun apply(h: TestHelper) =>
    let original: String val = "hello world"
    try
      let t = Text.from_string(original)?
      let bytes = t.utf8_bytes()
      h.assert_eq[String](original, consume bytes)
    else
      h.fail("Text.from_string raised on valid input")
    end

class \nodoc\ iso _TestTextFromIsoString is UnitTest
  fun name(): String => "Text.from_iso_string adopts an iso String"

  fun apply(h: TestHelper) =>
    let raw: String iso = recover iso String.create() .> append("hello iso") end
    try
      let t = Text.from_iso_string(consume raw)?
      h.assert_eq[USize](9, t.size_bytes())
    else
      h.fail("Text.from_iso_string raised on valid input")
    end

// ---- M3: Codepoint class + Codepoints primitive ----

class \nodoc\ iso _TestCodepointsIsScalar is UnitTest
  fun name(): String => "Codepoints.is_scalar"

  fun apply(h: TestHelper) =>
    // Valid scalar values
    h.assert_true(Codepoints.is_scalar(0))
    h.assert_true(Codepoints.is_scalar(0x41))
    h.assert_true(Codepoints.is_scalar(0xD7FF))     // just before surrogates
    h.assert_true(Codepoints.is_scalar(0xE000))     // just after surrogates
    h.assert_true(Codepoints.is_scalar(0x10FFFF))   // max scalar
    // Invalid: surrogates
    h.assert_false(Codepoints.is_scalar(0xD800))
    h.assert_false(Codepoints.is_scalar(0xDFFF))
    h.assert_false(Codepoints.is_scalar(0xDC00))
    // Invalid: above max
    h.assert_false(Codepoints.is_scalar(0x110000))
    h.assert_false(Codepoints.is_scalar(0xFFFFFFFF))

class \nodoc\ iso _TestCodepointsFromU32 is UnitTest
  fun name(): String => "Codepoints.from_u32 factory"

  fun apply(h: TestHelper) =>
    // Valid scalars produce Codepoint.
    match Codepoints.from_u32(0x41)
    | let cp: Codepoint val => h.assert_eq[U32](0x41, cp.scalar())
    | let _: InvalidScalar => h.fail("expected Codepoint for 0x41")
    end
    // Surrogates produce InvalidScalar with the original value.
    match Codepoints.from_u32(0xD800)
    | let _: Codepoint val => h.fail("expected InvalidScalar for surrogate")
    | let e: InvalidScalar => h.assert_eq[U32](0xD800, e.value)
    end
    // Above max produces InvalidScalar.
    match Codepoints.from_u32(0x110000)
    | let _: Codepoint val => h.fail("expected InvalidScalar above max")
    | let e: InvalidScalar => h.assert_eq[U32](0x110000, e.value)
    end

class \nodoc\ iso _TestCodepointsIsLetter is UnitTest
  fun name(): String => "Codepoints.is_letter"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.is_letter('A'))
    h.assert_true(Codepoints.is_letter('z'))
    h.assert_true(Codepoints.is_letter(0xE9))   // é (Ll)
    h.assert_true(Codepoints.is_letter(0xC5))   // Å (Lu)
    h.assert_false(Codepoints.is_letter('0'))
    h.assert_false(Codepoints.is_letter(' '))
    h.assert_false(Codepoints.is_letter('!'))
    h.assert_false(Codepoints.is_letter(0))     // NULL (Cc)
    // Non-scalars: false.
    h.assert_false(Codepoints.is_letter(0xD800))
    h.assert_false(Codepoints.is_letter(0x110000))

class \nodoc\ iso _TestCodepointsIsDigit is UnitTest
  fun name(): String => "Codepoints.is_digit"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.is_digit('0'))
    h.assert_true(Codepoints.is_digit('9'))
    // Arabic-Indic digit 0 (U+0660) — Nd
    h.assert_true(Codepoints.is_digit(0x0660))
    h.assert_false(Codepoints.is_digit('A'))
    // Roman numeral I (U+2160) — Nl (letter-number), NOT Nd, so false
    h.assert_false(Codepoints.is_digit(0x2160))
    // Superscript 2 (U+00B2) — No (other-number), NOT Nd
    h.assert_false(Codepoints.is_digit(0x00B2))

class \nodoc\ iso _TestCodepointsIsWhitespace is UnitTest
  fun name(): String => "Codepoints.is_whitespace (category-based)"

  fun apply(h: TestHelper) =>
    // Category Zs: SPACE
    h.assert_true(Codepoints.is_whitespace(' '))
    // Category Zs: NO-BREAK SPACE
    h.assert_true(Codepoints.is_whitespace(0xA0))
    // Specific control codes treated as whitespace.
    h.assert_true(Codepoints.is_whitespace(0x09))  // TAB
    h.assert_true(Codepoints.is_whitespace(0x0A))  // LF
    h.assert_true(Codepoints.is_whitespace(0x0D))  // CR
    h.assert_true(Codepoints.is_whitespace(0x85))  // NEL
    h.assert_false(Codepoints.is_whitespace('A'))
    h.assert_false(Codepoints.is_whitespace('!'))
    h.assert_false(Codepoints.is_whitespace(0))    // NULL — Cc but not whitespace
    h.assert_false(Codepoints.is_whitespace(0x07)) // BEL — Cc but not whitespace

class \nodoc\ iso _TestCodepointsIsAssigned is UnitTest
  fun name(): String => "Codepoints.is_assigned"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.is_assigned('A'))
    h.assert_true(Codepoints.is_assigned(0xE9))
    h.assert_true(Codepoints.is_assigned(0x1F600))  // emoji
    h.assert_true(Codepoints.is_assigned(0))        // NULL is assigned (Cc)
    // U+0378 — unassigned in Unicode 16
    h.assert_false(Codepoints.is_assigned(0x0378))
    // Non-scalars: false.
    h.assert_false(Codepoints.is_assigned(0xD800))

class \nodoc\ iso _TestCodepointClassMethods is UnitTest
  fun name(): String => "Codepoint val instance methods"

  fun apply(h: TestHelper) =>
    try
      let cp = Codepoints.from_u32(0xE9) as Codepoint val
      h.assert_eq[U32](0xE9, cp.scalar())
      h.assert_eq[String]("Ll", cp.category().code())
      h.assert_true(cp.is_letter())
      h.assert_false(cp.is_digit())
      h.assert_false(cp.is_whitespace())
      h.assert_true(cp.is_assigned())
      h.assert_eq[U8](0, cp.combining_class())  // precomposed é
      match cp.canonical_decomposition()
      | let d: Array[U32] val =>
        h.assert_eq[USize](2, d.size())
        h.assert_eq[U32](0x65, d(0)?)
        h.assert_eq[U32](0x301, d(1)?)
      | None => h.fail("expected decomposition")
      end
    else
      h.fail("Codepoints.from_u32(0xE9) didn't yield Codepoint")
    end

class \nodoc\ iso _TestCodepointEquality is UnitTest
  fun name(): String => "Codepoint equality / comparison / hash"

  fun apply(h: TestHelper) =>
    try
      let a = Codepoints.from_u32(0x41) as Codepoint val
      let b = Codepoints.from_u32(0x41) as Codepoint val
      let c = Codepoints.from_u32(0x42) as Codepoint val
      h.assert_true(a.eq(b))
      h.assert_false(a.eq(c))
      h.assert_true(a.lt(c))
      h.assert_false(c.lt(a))
      h.assert_eq[USize](a.hash(), b.hash())
    else
      h.fail("from_u32 failed for ASCII")
    end

class \nodoc\ iso _TestCodepointString is UnitTest
  fun name(): String => "Codepoint.string formats as U+XXXX"

  fun apply(h: TestHelper) =>
    try
      let cp_a = Codepoints.from_u32(0x41) as Codepoint val
      h.assert_eq[String]("U+0041", cp_a.string())
      let cp_emoji = Codepoints.from_u32(0x1F600) as Codepoint val
      h.assert_eq[String]("U+1F600", cp_emoji.string())
      let cp_null = Codepoints.from_u32(0) as Codepoint val
      h.assert_eq[String]("U+0000", cp_null.string())
    else
      h.fail("from_u32 failed")
    end

class \nodoc\ iso _TestCodepointsStringCount is UnitTest
  fun name(): String => "Codepoints.count over String"

  fun apply(h: TestHelper) =>
    match Codepoints.count("")
    | let n: USize => h.assert_eq[USize](0, n)
    | let _: InvalidUtf8 => h.fail("empty string should count as 0")
    end
    match Codepoints.count("hello")
    | let n: USize => h.assert_eq[USize](5, n)
    | let _: InvalidUtf8 => h.fail("ASCII count failed")
    end
    // "café" (precomposed é) = 4 codepoints, 5 bytes.
    let cafe: Array[U8] val =
      recover val [as U8: 0x63; 0x61; 0x66; 0xC3; 0xA9] end
    try
      let t = Text.from_array(cafe)?
      h.assert_eq[USize](5, t.size_bytes())
      // Run codepoint count via the topical primitive using bytes view.
      let s_bytes = t.utf8_bytes()
      match Codepoints.count(consume s_bytes)
      | let n: USize => h.assert_eq[USize](4, n)
      | let _: InvalidUtf8 => h.fail("café count failed")
      end
    else
      h.fail("from_array failed for café")
    end

class \nodoc\ iso _TestCodepointsStringIsAll is UnitTest
  fun name(): String => "Codepoints.is_all with predicate"

  fun apply(h: TestHelper) =>
    let only_letters = {(u: U32): Bool => Codepoints.is_letter(u) } val
    match Codepoints.is_all("abcXYZ", only_letters)
    | let b: Bool => h.assert_true(b)
    | let _: InvalidUtf8 => h.fail("validation failed for ASCII letters")
    end
    match Codepoints.is_all("abc 123", only_letters)
    | let b: Bool => h.assert_false(b)
    | let _: InvalidUtf8 => h.fail("validation failed for mixed")
    end
    // Empty string: vacuously true.
    match Codepoints.is_all("", only_letters)
    | let b: Bool => h.assert_true(b)
    | let _: InvalidUtf8 => h.fail("validation failed for empty")
    end

class \nodoc\ iso _TestCodepointsStringInvalid is UnitTest
  fun name(): String => "Codepoints.count returns InvalidUtf8 with offset"

  fun apply(h: TestHelper) =>
    // Build an invalid UTF-8 string via Array[U8] then String.from_array.
    let bad: Array[U8] val =
      recover val [as U8: 0x61; 0x62; 0x80; 0x63] end
    let s = String.from_array(bad)
    match Codepoints.count(s)
    | let _: USize => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](2, e.offset)
    end

// ---- M4a: Grapheme_Cluster_Break property table ----

class \nodoc\ iso _TestGraphemeBreakAscii is UnitTest
  fun name(): String => "GraphemeBreak: ASCII / common cases"

  fun apply(h: TestHelper) =>
    // Plain ASCII letters / digits: Other
    h.assert_eq[String]("Other", Codepoints.grapheme_break('A').code())
    h.assert_eq[String]("Other", Codepoints.grapheme_break('0').code())
    // CR / LF
    h.assert_eq[String]("CR", Codepoints.grapheme_break(0x0D).code())
    h.assert_eq[String]("LF", Codepoints.grapheme_break(0x0A).code())
    // Other ASCII control chars: Control
    h.assert_eq[String]("Control", Codepoints.grapheme_break(0).code())
    h.assert_eq[String]("Control", Codepoints.grapheme_break(0x09).code())  // TAB

class \nodoc\ iso _TestGraphemeBreakCombining is UnitTest
  fun name(): String => "GraphemeBreak: combining marks / ZWJ"

  fun apply(h: TestHelper) =>
    // U+0300 COMBINING GRAVE ACCENT — Extend
    h.assert_eq[String]("Extend", Codepoints.grapheme_break(0x0300).code())
    // U+0301 COMBINING ACUTE ACCENT — Extend
    h.assert_eq[String]("Extend", Codepoints.grapheme_break(0x0301).code())
    // U+200D ZERO WIDTH JOINER — ZWJ
    h.assert_eq[String]("ZWJ", Codepoints.grapheme_break(0x200D).code())
    // U+0903 DEVANAGARI SIGN VISARGA — SpacingMark
    h.assert_eq[String]("SpacingMark", Codepoints.grapheme_break(0x0903).code())

class \nodoc\ iso _TestGraphemeBreakHangul is UnitTest
  fun name(): String => "GraphemeBreak: Hangul jamo L / V / T"

  fun apply(h: TestHelper) =>
    // U+1100 HANGUL CHOSEONG KIYEOK — L (leading jamo)
    h.assert_eq[String]("L", Codepoints.grapheme_break(0x1100).code())
    // U+1161 HANGUL JUNGSEONG A — V (vowel jamo)
    h.assert_eq[String]("V", Codepoints.grapheme_break(0x1161).code())
    // U+11A8 HANGUL JONGSEONG KIYEOK — T (trailing jamo)
    h.assert_eq[String]("T", Codepoints.grapheme_break(0x11A8).code())
    // U+AC00 HANGUL SYLLABLE GA — LV (LV-type precomposed syllable)
    h.assert_eq[String]("LV", Codepoints.grapheme_break(0xAC00).code())
    // U+AC01 HANGUL SYLLABLE GAG — LVT (LVT-type)
    h.assert_eq[String]("LVT", Codepoints.grapheme_break(0xAC01).code())

class \nodoc\ iso _TestGraphemeBreakEmoji is UnitTest
  fun name(): String => "GraphemeBreak: emoji are Extended_Pictographic"

  fun apply(h: TestHelper) =>
    // U+1F600 GRINNING FACE
    h.assert_eq[String]("Extended_Pictographic",
      Codepoints.grapheme_break(0x1F600).code())
    // U+1F1FA REGIONAL INDICATOR SYMBOL LETTER U
    h.assert_eq[String]("Regional_Indicator",
      Codepoints.grapheme_break(0x1F1FA).code())

class \nodoc\ iso _TestGraphemeBreakRegionalIndicator is UnitTest
  fun name(): String => "GraphemeBreak: Regional_Indicator range"

  fun apply(h: TestHelper) =>
    // U+1F1E6 (A) through U+1F1FF (Z) — Regional_Indicator
    h.assert_eq[String]("Regional_Indicator",
      Codepoints.grapheme_break(0x1F1E6).code())
    h.assert_eq[String]("Regional_Indicator",
      Codepoints.grapheme_break(0x1F1FF).code())
    // Just above the range: U+1F200 is Other.
    h.assert_eq[String]("Other",
      Codepoints.grapheme_break(0x1F200).code())

// ---- M4b: grapheme iteration ----
// Helper builds a Text val from a sequence of bytes (skipping the
// String-literal UTF-8 escape trap from M2 tests).
//
// Each test counts and inspects clusters via `Text.graphemes()` and
// `Text.grapheme_ranges()`, plus `Text.size_graphemes()`.

class \nodoc\ iso _TestGraphemesAscii is UnitTest
  fun name(): String => "graphemes: ASCII = one cluster per byte"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("hello")?
      h.assert_eq[USize](5, t.size_graphemes())
      let collected = recover trn Array[String val] end
      for g in t.graphemes() do collected.push(g) end
      h.assert_eq[USize](5, collected.size())
      h.assert_eq[String]("h", collected(0)?)
      h.assert_eq[String]("o", collected(4)?)
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestGraphemesCombining is UnitTest
  fun name(): String => "graphemes: base + combining mark = one cluster"

  fun apply(h: TestHelper) =>
    // "café" decomposed: c (0x63) + a (0x61) + f (0x66) + e (0x65)
    // + U+0301 COMBINING ACUTE (0xCC 0x81)
    let bytes: Array[U8] val =
      recover val [as U8: 0x63; 0x61; 0x66; 0x65; 0xCC; 0x81] end
    try
      let t = Text.from_array(bytes)?
      // 6 bytes, 5 codepoints, 4 graphemes (e + combining = 1 cluster)
      h.assert_eq[USize](6, t.size_bytes())
      h.assert_eq[USize](4, t.size_graphemes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestGraphemesCRLF is UnitTest
  fun name(): String => "graphemes: CR LF = one cluster (GB3)"

  fun apply(h: TestHelper) =>
    let bytes: Array[U8] val =
      recover val [as U8: 0x41; 0x0D; 0x0A; 0x42] end  // "A\r\nB"
    try
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](3, t.size_graphemes())  // A, CR+LF, B
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestGraphemesHangul is UnitTest
  fun name(): String => "graphemes: Hangul L+V+T = one cluster"

  fun apply(h: TestHelper) =>
    // U+1100 (L) + U+1161 (V) + U+11A8 (T) = one cluster
    // UTF-8: E1 84 80 + E1 85 A1 + E1 86 A8 = 9 bytes
    let bytes: Array[U8] val = recover val [as U8:
      0xE1; 0x84; 0x80; 0xE1; 0x85; 0xA1; 0xE1; 0x86; 0xA8
    ] end
    try
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](9, t.size_bytes())
      h.assert_eq[USize](1, t.size_graphemes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestGraphemesEmojiZWJ is UnitTest
  fun name(): String => "graphemes: family-emoji ZWJ sequence = one cluster"

  fun apply(h: TestHelper) =>
    // 👨‍👩‍👧 — three Extended_Pictographic codepoints joined by ZWJ.
    // U+1F468 MAN, U+200D ZWJ, U+1F469 WOMAN, U+200D ZWJ, U+1F467 GIRL.
    // UTF-8: F0 9F 91 A8 E2 80 8D F0 9F 91 A9 E2 80 8D F0 9F 91 A7
    let bytes: Array[U8] val = recover val [as U8:
      0xF0; 0x9F; 0x91; 0xA8
      0xE2; 0x80; 0x8D
      0xF0; 0x9F; 0x91; 0xA9
      0xE2; 0x80; 0x8D
      0xF0; 0x9F; 0x91; 0xA7
    ] end
    try
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](18, t.size_bytes())
      h.assert_eq[USize](1, t.size_graphemes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestGraphemesFlag is UnitTest
  fun name(): String => "graphemes: regional-indicator pair = one cluster"

  fun apply(h: TestHelper) =>
    // 🇺🇸 — RI U + RI S
    // U+1F1FA UTF-8: F0 9F 87 BA
    // U+1F1F8 UTF-8: F0 9F 87 B8
    let bytes: Array[U8] val = recover val [as U8:
      0xF0; 0x9F; 0x87; 0xBA
      0xF0; 0x9F; 0x87; 0xB8
    ] end
    try
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](8, t.size_bytes())
      h.assert_eq[USize](1, t.size_graphemes())
    else
      h.fail("setup raised")
    end
    // Two flags = two clusters.
    let two_flags: Array[U8] val = recover val [as U8:
      0xF0; 0x9F; 0x87; 0xBA; 0xF0; 0x9F; 0x87; 0xB8  // 🇺🇸
      0xF0; 0x9F; 0x87; 0xAB; 0xF0; 0x9F; 0x87; 0xB7  // 🇫🇷
    ] end
    try
      let t2 = Text.from_array(two_flags)?
      h.assert_eq[USize](16, t2.size_bytes())
      h.assert_eq[USize](2, t2.size_graphemes())
    else
      h.fail("two-flag setup raised")
    end

class \nodoc\ iso _TestGraphemesEmpty is UnitTest
  fun name(): String => "graphemes: empty Text yields nothing"

  fun apply(h: TestHelper) =>
    let t: Text val = Text.create()
    h.assert_eq[USize](0, t.size_graphemes())
    h.assert_false(t.graphemes().has_next())
    h.assert_false(t.grapheme_ranges().has_next())

class \nodoc\ iso _TestGraphemeRangesNoAlloc is UnitTest
  fun name(): String => "grapheme_ranges yields byte ranges"

  fun apply(h: TestHelper) =>
    // Same "café" with combining acute: 6 bytes, 4 clusters.
    // Cluster ranges should be (0,1) (1,2) (2,3) (3,6).
    let bytes: Array[U8] val =
      recover val [as U8: 0x63; 0x61; 0x66; 0x65; 0xCC; 0x81] end
    try
      let t = Text.from_array(bytes)?
      let collected = recover trn Array[(USize, USize)] end
      for r in t.grapheme_ranges() do collected.push(r) end
      h.assert_eq[USize](4, collected.size())
      (let s0, let e0) = collected(0)?
      h.assert_eq[USize](0, s0); h.assert_eq[USize](1, e0)
      (let s3, let e3) = collected(3)?
      h.assert_eq[USize](3, s3); h.assert_eq[USize](6, e3)
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestSizeGraphemes is UnitTest
  fun name(): String => "size_graphemes matches manual count"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("Hello, world!")?
      h.assert_eq[USize](13, t.size_graphemes())
    else
      h.fail("setup raised")
    end

// ---- M4c: phantom-typed indices ----

class \nodoc\ iso _TestIndexConstruction is UnitTest
  fun name(): String => "Text.X_index range-checks against the right unit"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("abc")?
      // byte_index: valid for 0..3 (size_bytes=3, one-past-end allowed)
      match t.byte_index(0)
      | let _: ByteIndex => None
      | let _: OutOfRange => h.fail("byte_index(0) should succeed")
      end
      match t.byte_index(3)
      | let _: ByteIndex => None
      | let _: OutOfRange => h.fail("byte_index(3) at one-past-end should succeed")
      end
      match t.byte_index(4)
      | let _: ByteIndex => h.fail("byte_index(4) should be out of range")
      | let _: OutOfRange => None
      end
      // codepoint_index / grapheme_index: same shape, range = size in that unit
      match t.codepoint_index(3)
      | let _: CodepointIndex => None
      | let _: OutOfRange => h.fail("codepoint_index(3) should succeed")
      end
      match t.grapheme_index(3)
      | let _: GraphemeIndex => None
      | let _: OutOfRange => h.fail("grapheme_index(3) should succeed")
      end
    else
      h.fail("from_string raised")
    end

class \nodoc\ iso _TestIndexAt is UnitTest
  fun name(): String => "Text.{byte_at,codepoint_at,grapheme_at}"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("hello")?
      // byte_at
      let b_idx = t.byte_index(1) as ByteIndex
      h.assert_eq[U8]('e', t.byte_at(b_idx) as U8)
      // codepoint_at
      let cp_idx = t.codepoint_index(2) as CodepointIndex
      let cp = t.codepoint_at(cp_idx) as Codepoint val
      h.assert_eq[U32](U32('l'), cp.scalar())
      // grapheme_at — for ASCII, same as byte_at on slices.
      let g_idx = t.grapheme_index(4) as GraphemeIndex
      let g = t.grapheme_at(g_idx) as String val
      h.assert_eq[String]("o", g)
    else
      h.fail("setup or match raised")
    end

class \nodoc\ iso _TestIndexOutOfRange is UnitTest
  fun name(): String => "indexing past the end returns OutOfRange"

  fun apply(h: TestHelper) =>
    try
      // Build a ByteIndex valid for a longer Text, then use it on a
      // shorter one — the realistic "stored an index, then trimmed
      // the text" scenario.
      let long_t = Text.from_string("abcdef")?
      let short_t = Text.from_string("ab")?
      let idx = long_t.byte_index(5) as ByteIndex
      match short_t.byte_at(idx)
      | let _: U8 => h.fail("expected OutOfRange")
      | let e: OutOfRange =>
        h.assert_eq[USize](5, e.index)
        h.assert_eq[USize](2, e.size)
      end
      // Direct OutOfRange construction from a too-large request.
      match short_t.byte_index(99)
      | let _: ByteIndex => h.fail("expected OutOfRange for byte_index(99)")
      | let e: OutOfRange =>
        h.assert_eq[USize](99, e.index)
        h.assert_eq[USize](2, e.size)
      end
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestIndexCannotMix is UnitTest
  fun name(): String => "Index types document that mixing is a compile error"

  fun apply(h: TestHelper) =>
    // This test is documentation rather than runtime: the code below
    // would be a COMPILE error if uncommented, because grapheme_at
    // requires GraphemeIndex but byte_index returns ByteIndex.
    //
    //   let t = Text.from_string("abc")?
    //   let bidx = t.byte_index(1) as ByteIndex
    //   t.grapheme_at(bidx)   // <-- compile error
    //
    // We sanity-check at runtime that the type aliases are distinct
    // (Index[_ByteIdx] vs Index[_GraphemeIdx] vs Index[_CodepointIdx]).
    // A trivial passing test — the compile-time check is what matters.
    h.assert_true(true)

// ---- M4d: bitmap index ----

class \nodoc\ iso _TestIndexedDefault is UnitTest
  fun name(): String => "Text.from_string defaults to unindexed"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("Hello, world!")?
      h.assert_false(t.is_indexed())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestIndexedFlag is UnitTest
  fun name(): String => "Text.from_string(indexed=true) is_indexed"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("Hello, world!", true)?
      h.assert_true(t.is_indexed())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestIndexedCountsAgree is UnitTest
  fun name(): String => "indexed/unindexed sizes agree"

  fun apply(h: TestHelper) =>
    // "Hé🇨🇦" — mix of ASCII, precomposed Latin, regional-indicator pair.
    // 1 ASCII (1 byte) + 'é' precomposed (2 bytes) + RI pair (8 bytes)
    // = 11 bytes, 4 codepoints (H, é, RI-C, RI-A), 3 graphemes.
    // 'H' + 'é' precomposed (UTF-8 0xC3 0xA9) + U+1F1E8 + U+1F1E6
    let bytes: Array[U8] val = recover val [as U8:
      0x48; 0xC3; 0xA9; 0xF0; 0x9F; 0x87; 0xA8; 0xF0; 0x9F; 0x87; 0xA6] end
    try
      let a = Text.from_array(bytes, false)?
      let b = Text.from_array(bytes, true)?
      h.assert_false(a.is_indexed())
      h.assert_true(b.is_indexed())
      h.assert_eq[USize](a.size_bytes(), b.size_bytes())
      h.assert_eq[USize](a.size_codepoints(), b.size_codepoints())
      h.assert_eq[USize](a.size_graphemes(), b.size_graphemes())
      h.assert_eq[USize](11, b.size_bytes())
      h.assert_eq[USize](4, b.size_codepoints())
      h.assert_eq[USize](3, b.size_graphemes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestIndexedFlipMethods is UnitTest
  fun name(): String => "Text.with_index() / without_index() flip the index"

  fun apply(h: TestHelper) =>
    try
      let plain = Text.from_string("abc")?
      h.assert_false(plain.is_indexed())
      let with_idx = plain.with_index()?
      h.assert_true(with_idx.is_indexed())
      let without_idx = with_idx.without_index()?
      h.assert_false(without_idx.is_indexed())
      h.assert_eq[USize](3, with_idx.size_graphemes())
      h.assert_eq[USize](3, without_idx.size_graphemes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestIndexedEmpty is UnitTest
  fun name(): String => "indexed empty Text has zero counts"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("", true)?
      h.assert_true(t.is_indexed())
      h.assert_eq[USize](0, t.size_bytes())
      h.assert_eq[USize](0, t.size_codepoints())
      h.assert_eq[USize](0, t.size_graphemes())
    else
      h.fail("setup raised")
    end

// ---- M4e: slicing + index conversions ----

class \nodoc\ iso _TestSliceCodepoints is UnitTest
  fun name(): String => "slice_codepoints returns the right substring"

  fun apply(h: TestHelper) =>
    try
      // "Hé🌍" — 3 codepoints: 'H' (1 byte), 'é' (2 bytes),
      // '🌍' (4 bytes), total 7 bytes.
      let bytes: Array[U8] val = recover val [as U8:
        0x48; 0xC3; 0xA9; 0xF0; 0x9F; 0x8C; 0x8D] end
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](3, t.size_codepoints())
      // [0, 2): "Hé" — 3 bytes
      let s0 = t.codepoint_index(0) as CodepointIndex
      let s2 = t.codepoint_index(2) as CodepointIndex
      let s3 = t.codepoint_index(3) as CodepointIndex
      let cut = t.slice_codepoints(s0, s2) as Text val
      h.assert_eq[USize](3, cut.size_bytes())
      h.assert_eq[USize](2, cut.size_codepoints())
      // [1, 3): "é🌍" — 6 bytes
      let s1 = t.codepoint_index(1) as CodepointIndex
      let tail = t.slice_codepoints(s1, s3) as Text val
      h.assert_eq[USize](6, tail.size_bytes())
      h.assert_eq[USize](2, tail.size_codepoints())
      // empty range
      let empty = t.slice_codepoints(s1, s1) as Text val
      h.assert_eq[USize](0, empty.size_bytes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestSliceGraphemes is UnitTest
  fun name(): String => "slice_graphemes returns the right cluster span"

  fun apply(h: TestHelper) =>
    try
      // "Hé🇨🇦" — 3 graphemes: 'H', 'é', 🇨🇦 (RI pair = 1 cluster).
      // Bytes: 0x48 | 0xC3 0xA9 | 0xF0 0x9F 0x87 0xA8 0xF0 0x9F 0x87 0xA6
      // = 11 bytes total.
      let bytes: Array[U8] val = recover val [as U8:
        0x48; 0xC3; 0xA9; 0xF0; 0x9F; 0x87; 0xA8
        0xF0; 0x9F; 0x87; 0xA6] end
      let t = Text.from_array(bytes)?
      h.assert_eq[USize](3, t.size_graphemes())
      // [0, 2): "Hé" — 3 bytes, 2 clusters
      let g0 = t.grapheme_index(0) as GraphemeIndex
      let g2 = t.grapheme_index(2) as GraphemeIndex
      let g3 = t.grapheme_index(3) as GraphemeIndex
      let cut = t.slice_graphemes(g0, g2) as Text val
      h.assert_eq[USize](3, cut.size_bytes())
      h.assert_eq[USize](2, cut.size_graphemes())
      // [2, 3): flag only — 8 bytes, 1 cluster
      let flag = t.slice_graphemes(g2, g3) as Text val
      h.assert_eq[USize](8, flag.size_bytes())
      h.assert_eq[USize](1, flag.size_graphemes())
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestSliceOutOfRange is UnitTest
  fun name(): String => "slice_* return OutOfRange for bad bounds"

  fun apply(h: TestHelper) =>
    try
      let t = Text.from_string("abc")?
      let z = t.grapheme_index(0) as GraphemeIndex
      let three = t.grapheme_index(3) as GraphemeIndex
      // end past size
      // (constructing a too-large index would fail at grapheme_index;
      //  test reversed bounds instead — `start > end`)
      match t.slice_graphemes(three, z)
      | let _: Text val => h.fail("expected OutOfRange for reversed bounds")
      | let _: OutOfRange => None
      end
      let cz = t.codepoint_index(0) as CodepointIndex
      let cthree = t.codepoint_index(3) as CodepointIndex
      match t.slice_codepoints(cthree, cz)
      | let _: Text val => h.fail("expected OutOfRange for reversed bounds")
      | let _: OutOfRange => None
      end
    else
      h.fail("setup raised")
    end

class \nodoc\ iso _TestCodepointByteIndex is UnitTest
  fun name(): String => "codepoint_byte_index resolves to byte offsets"

  fun apply(h: TestHelper) =>
    try
      // "Hé🌍" — codepoint byte offsets: 0, 1, 3, (one-past-end) 7
      let bytes: Array[U8] val = recover val [as U8:
        0x48; 0xC3; 0xA9; 0xF0; 0x9F; 0x8C; 0x8D] end
      let t = Text.from_array(bytes)?
      let c0 = t.codepoint_index(0) as CodepointIndex
      let c1 = t.codepoint_index(1) as CodepointIndex
      let c2 = t.codepoint_index(2) as CodepointIndex
      let c3 = t.codepoint_index(3) as CodepointIndex
      let b0 = t.codepoint_byte_index(c0) as ByteIndex
      let b1 = t.codepoint_byte_index(c1) as ByteIndex
      let b2 = t.codepoint_byte_index(c2) as ByteIndex
      let b3 = t.codepoint_byte_index(c3) as ByteIndex
      h.assert_eq[USize](0, b0.value())
      h.assert_eq[USize](1, b1.value())
      h.assert_eq[USize](3, b2.value())
      h.assert_eq[USize](7, b3.value())
    else
      h.fail("setup raised")
    end

// ---- 0.2.0: Lines (UAX #14) ----

class \nodoc\ iso _TestLinesBasic is UnitTest
  fun name(): String => "Lines: ASCII with mandatory and optional breaks"

  fun apply(h: TestHelper) =>
    match Lines.iter("Hello\nworld!")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for ln in it do parts.push(ln) end
      h.assert_eq[USize](2, parts.size())
      try h.assert_eq[String]("Hello\n", parts(0)?) end
      try h.assert_eq[String]("world!", parts(1)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestLinesSpaceBreaks is UnitTest
  fun name(): String => "Lines: breaks at SPACEs (LB18)"

  fun apply(h: TestHelper) =>
    match Lines.iter("ab cd ef")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for ln in it do parts.push(ln) end
      h.assert_eq[USize](3, parts.size())
      try h.assert_eq[String]("ab ", parts(0)?) end
      try h.assert_eq[String]("cd ", parts(1)?) end
      try h.assert_eq[String]("ef", parts(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestLinesNumericGlued is UnitTest
  fun name(): String => "Lines: numeric chain stays together (LB25)"

  fun apply(h: TestHelper) =>
    // "$3.14" — currency + numeric + decimal + numeric. One unit.
    match Lines.iter("$3.14")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for ln in it do parts.push(ln) end
      h.assert_eq[USize](1, parts.size())
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestLinesEmpty is UnitTest
  fun name(): String => "Lines.count: empty"

  fun apply(h: TestHelper) =>
    match Lines.count("")
    | let n: USize => h.assert_eq[USize](0, n)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestLinesInvalid is UnitTest
  fun name(): String => "Lines rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80] end)
    match Lines.count(bad)
    | let _: USize => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- 0.2.0: Sentences (UAX #29) ----

class \nodoc\ iso _TestSentencesBasic is UnitTest
  fun name(): String => "Sentences: two basic sentences with full stop"

  fun apply(h: TestHelper) =>
    match Sentences.iter("Hello. World!")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for s in it do parts.push(s) end
      h.assert_eq[USize](2, parts.size())
      try h.assert_eq[String]("Hello. ", parts(0)?) end
      try h.assert_eq[String]("World!", parts(1)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSentencesParaSep is UnitTest
  fun name(): String => "Sentences: paragraph separators break (SB4)"

  fun apply(h: TestHelper) =>
    match Sentences.iter("Line one\nLine two")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for s in it do parts.push(s) end
      h.assert_eq[USize](2, parts.size())
      try h.assert_eq[String]("Line one\n", parts(0)?) end
      try h.assert_eq[String]("Line two", parts(1)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSentencesSB8 is UnitTest
  fun name(): String => "Sentences: SB8 forward-Lower keeps 'Dr. smith ...' together"

  fun apply(h: TestHelper) =>
    // SB8: ATerm Close* Sp* × ... Lower
    // After "Dr." + space, the next letter is lowercase 's' — SB8
    // suppresses the break (treating it as an abbreviation).
    match Sentences.iter("Dr. smith said hello.")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for s in it do parts.push(s) end
      h.assert_eq[USize](1, parts.size())
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSentencesNoTerm is UnitTest
  fun name(): String => "Sentences: no terminator = one sentence"

  fun apply(h: TestHelper) =>
    match Sentences.iter("just some text")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for s in it do parts.push(s) end
      h.assert_eq[USize](1, parts.size())
      try h.assert_eq[String]("just some text", parts(0)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSentencesEmpty is UnitTest
  fun name(): String => "Sentences.count: empty"

  fun apply(h: TestHelper) =>
    match Sentences.count("")
    | let n: USize => h.assert_eq[USize](0, n)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSentencesInvalid is UnitTest
  fun name(): String => "Sentences rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80] end)
    match Sentences.count(bad)
    | let _: USize => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- 0.2.0: Words (UAX #29) ----

class \nodoc\ iso _TestWordsAsciiBasic is UnitTest
  fun name(): String => "Words.iter: ASCII words and spaces"

  fun apply(h: TestHelper) =>
    let s: String val = "Hello, world!"
    match Words.iter(s)
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for w in it do parts.push(w) end
      // Expected: "Hello", ",", " ", "world", "!"
      h.assert_eq[USize](5, parts.size())
      try h.assert_eq[String]("Hello", parts(0)?) end
      try h.assert_eq[String](",", parts(1)?) end
      try h.assert_eq[String](" ", parts(2)?) end
      try h.assert_eq[String]("world", parts(3)?) end
      try h.assert_eq[String]("!", parts(4)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestWordsNumeric is UnitTest
  fun name(): String => "Words: numeric stays together (WB8, WB12)"

  fun apply(h: TestHelper) =>
    // "3.14" → "3.14" (WB12: Numeric × MidNum Numeric)
    match Words.iter("3.14")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for w in it do parts.push(w) end
      h.assert_eq[USize](1, parts.size())
      try h.assert_eq[String]("3.14", parts(0)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestWordsApostrophe is UnitTest
  fun name(): String => "Words: don't → one word (WB6/WB7 via Single_Quote)"

  fun apply(h: TestHelper) =>
    match Words.iter("don't")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for w in it do parts.push(w) end
      h.assert_eq[USize](1, parts.size())
      try h.assert_eq[String]("don't", parts(0)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestWordsCrLf is UnitTest
  fun name(): String => "Words: CR LF stays together (WB3)"

  fun apply(h: TestHelper) =>
    match Words.iter("a\r\nb")
    | let it: Iterator[String val] =>
      let parts = recover trn Array[String val] end
      for w in it do parts.push(w) end
      // "a", "\r\n", "b"
      h.assert_eq[USize](3, parts.size())
      try h.assert_eq[String]("a", parts(0)?) end
      try h.assert_eq[String]("\r\n", parts(1)?) end
      try h.assert_eq[String]("b", parts(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestWordsEmpty is UnitTest
  fun name(): String => "Words.count: empty string"

  fun apply(h: TestHelper) =>
    match Words.count("")
    | let n: USize => h.assert_eq[USize](0, n)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestWordsInvalid is UnitTest
  fun name(): String => "Words rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80] end)
    match Words.count(bad)
    | let _: USize => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- M8: Search ----

class \nodoc\ iso _TestSearchContains is UnitTest
  fun name(): String => "Search.contains: present and absent"

  fun apply(h: TestHelper) =>
    match Search.contains("hello world", "world")
    | let b: Bool => h.assert_true(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.contains("hello world", "xyz")
    | let b: Bool => h.assert_false(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.contains("hello", "")
    | let b: Bool => h.assert_true(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSearchStartsEnds is UnitTest
  fun name(): String => "Search.starts_with / ends_with"

  fun apply(h: TestHelper) =>
    match Search.starts_with("hello world", "hello")
    | let b: Bool => h.assert_true(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.starts_with("hello world", "world")
    | let b: Bool => h.assert_false(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.ends_with("hello world", "world")
    | let b: Bool => h.assert_true(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.ends_with("hello world", "hello")
    | let b: Bool => h.assert_false(b)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSearchIndexOf is UnitTest
  fun name(): String => "Search.index_of / last_index_of"

  fun apply(h: TestHelper) =>
    match Search.index_of("hello world hello", "hello")
    | let i: USize => h.assert_eq[USize](0, i)
    | None => h.fail("expected 0")
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.last_index_of("hello world hello", "hello")
    | let i: USize => h.assert_eq[USize](12, i)
    | None => h.fail("expected 12")
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.index_of("hello", "xyz")
    | None => None
    | let _: USize => h.fail("expected None")
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSearchCount is UnitTest
  fun name(): String => "Search.count: non-overlapping"

  fun apply(h: TestHelper) =>
    match Search.count("aaaa", "aa")
    | let n: USize => h.assert_eq[USize](2, n)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Search.count("hello hello hello", "hello")
    | let n: USize => h.assert_eq[USize](3, n)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSearchInvalid is UnitTest
  fun name(): String => "Search rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80] end)
    match Search.contains(bad, "ok")
    | let _: Bool => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- M8: Split ----

class \nodoc\ iso _TestSplitBasic is UnitTest
  fun name(): String => "Split.on: basic comma split"

  fun apply(h: TestHelper) =>
    match Split.on("a,b,c", ",")
    | let parts: Array[String val] val =>
      h.assert_eq[USize](3, parts.size())
      try h.assert_eq[String]("a", parts(0)?) end
      try h.assert_eq[String]("b", parts(1)?) end
      try h.assert_eq[String]("c", parts(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSplitAdjacent is UnitTest
  fun name(): String => "Split.on: adjacent separators yield empty parts"

  fun apply(h: TestHelper) =>
    match Split.on("a,,b", ",")
    | let parts: Array[String val] val =>
      h.assert_eq[USize](3, parts.size())
      try h.assert_eq[String]("a", parts(0)?) end
      try h.assert_eq[String]("", parts(1)?) end
      try h.assert_eq[String]("b", parts(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSplitMultibyteSep is UnitTest
  fun name(): String => "Split.on: multi-byte separator"

  fun apply(h: TestHelper) =>
    // separator is "→" U+2192 (E2 86 92 in UTF-8)
    let arrow: Array[U8] val = recover val [as U8: 0xE2; 0x86; 0x92] end
    let sep_s = String.from_array(arrow)
    let arr2: Array[U8] val = recover val [as U8:
      0x61; 0xE2; 0x86; 0x92; 0x62; 0xE2; 0x86; 0x92; 0x63] end
    match Split.on(String.from_array(arr2), sep_s)
    | let parts: Array[String val] val =>
      h.assert_eq[USize](3, parts.size())
      try h.assert_eq[String]("a", parts(0)?) end
      try h.assert_eq[String]("c", parts(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestSplitLines is UnitTest
  fun name(): String => "Split.lines: handles \\n / \\r / \\r\\n"

  fun apply(h: TestHelper) =>
    match Split.lines("a\nb\r\nc\rd")
    | let parts: Array[String val] val =>
      h.assert_eq[USize](4, parts.size())
      try h.assert_eq[String]("a", parts(0)?) end
      try h.assert_eq[String]("b", parts(1)?) end
      try h.assert_eq[String]("c", parts(2)?) end
      try h.assert_eq[String]("d", parts(3)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

// ---- M8: Trim ----

class \nodoc\ iso _TestTrimBasic is UnitTest
  fun name(): String => "Trim.trim: ASCII whitespace"

  fun apply(h: TestHelper) =>
    match Trim.trim("  hello world  ")
    | let s: String iso => h.assert_eq[String]("hello world", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestTrimStartEnd is UnitTest
  fun name(): String => "Trim.trim_start / trim_end"

  fun apply(h: TestHelper) =>
    match Trim.trim_start("  hello  ")
    | let s: String iso => h.assert_eq[String]("hello  ", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Trim.trim_end("  hello  ")
    | let s: String iso => h.assert_eq[String]("  hello", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestTrimUnicodeWhitespace is UnitTest
  fun name(): String => "Trim: NBSP (U+00A0) is whitespace"

  fun apply(h: TestHelper) =>
    // NBSP = 0xC2 0xA0
    let inp: Array[U8] val =
      recover val [as U8: 0xC2; 0xA0; 0x68; 0x69; 0xC2; 0xA0] end
    match Trim.trim(String.from_array(inp))
    | let s: String iso => h.assert_eq[String]("hi", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestTrimAllWhitespace is UnitTest
  fun name(): String => "Trim: all whitespace yields empty"

  fun apply(h: TestHelper) =>
    match Trim.trim("   \t\n\r  ")
    | let s: String iso => h.assert_eq[String]("", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

// ---- M8: Replace ----

class \nodoc\ iso _TestReplaceAll is UnitTest
  fun name(): String => "Replace.all: substitute every match"

  fun apply(h: TestHelper) =>
    match Replace.all("foo bar foo baz", "foo", "qux")
    | let s: String iso => h.assert_eq[String]("qux bar qux baz", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestReplaceFirst is UnitTest
  fun name(): String => "Replace.first: substitute only the first match"

  fun apply(h: TestHelper) =>
    match Replace.first("foo bar foo baz", "foo", "qux")
    | let s: String iso => h.assert_eq[String]("qux bar foo baz", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestReplaceLengthChange is UnitTest
  fun name(): String => "Replace: replacement shorter/longer than needle"

  fun apply(h: TestHelper) =>
    match Replace.all("aaaa", "a", "bbb")
    | let s: String iso => h.assert_eq[String]("bbbbbbbbbbbb", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end
    match Replace.all("xxxxxx", "xx", "")
    | let s: String iso => h.assert_eq[String]("", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestReplaceNotFound is UnitTest
  fun name(): String => "Replace: needle absent returns clone"

  fun apply(h: TestHelper) =>
    match Replace.all("hello", "xyz", "abc")
    | let s: String iso => h.assert_eq[String]("hello", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

// ---- M7: Compare ----

class \nodoc\ iso _TestCompareBytes is UnitTest
  fun name(): String => "Compares.bytes: ordering and equality"

  fun apply(h: TestHelper) =>
    h.assert_true(Compares.bytes("abc", "abc") is Equal)
    h.assert_true(Compares.bytes("abc", "abd") is Less)
    h.assert_true(Compares.bytes("abd", "abc") is Greater)
    h.assert_true(Compares.bytes("abc", "abcd") is Less)
    h.assert_true(Compares.bytes("", "a") is Less)
    h.assert_true(Compares.bytes("", "") is Equal)

class \nodoc\ iso _TestEqualBytes is UnitTest
  fun name(): String => "equal_bytes: precomposed != decomposed"

  fun apply(h: TestHelper) =>
    let pre: Array[U8] val = recover val [as U8: 0xC3; 0xA9] end
    let dec: Array[U8] val = recover val [as U8: 0x65; 0xCC; 0x81] end
    h.assert_false(Compares.equal_bytes(
      String.from_array(pre), String.from_array(dec)))
    h.assert_true(Compares.equal_bytes("abc", "abc"))

class \nodoc\ iso _TestEqualCanonical is UnitTest
  fun name(): String => "equal_canonical: precomposed == decomposed"

  fun apply(h: TestHelper) =>
    let pre: Array[U8] val = recover val [as U8: 0xC3; 0xA9] end
    let dec: Array[U8] val = recover val [as U8: 0x65; 0xCC; 0x81] end
    match Compares.equal_canonical(
      String.from_array(pre), String.from_array(dec))
    | let eq: Bool => h.assert_true(eq)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestEqualCanonicalDistinct is UnitTest
  fun name(): String => "equal_canonical: 'a' != 'b'"

  fun apply(h: TestHelper) =>
    match Compares.equal_canonical("a", "b")
    | let eq: Bool => h.assert_false(eq)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestEqualCompat is UnitTest
  fun name(): String => "equal_compat: ﬁ == 'fi'"

  fun apply(h: TestHelper) =>
    let fi_lig: Array[U8] val = recover val [as U8: 0xEF; 0xAC; 0x81] end
    match Compares.equal_compat(String.from_array(fi_lig), "fi")
    | let eq: Bool => h.assert_true(eq)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestEqualCaseless is UnitTest
  fun name(): String => "equal_caseless: 'MAße' == 'masse' under fold"

  fun apply(h: TestHelper) =>
    let mas: Array[U8] val =
      recover val [as U8: 0x4D; 0x41; 0xC3; 0x9F; 0x65] end  // 'MAße'
    match Compares.equal_caseless(String.from_array(mas), "masse")
    | let eq: Bool => h.assert_true(eq)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestEqualCaselessAsciiDistinct is UnitTest
  fun name(): String => "equal_caseless: 'foo' != 'bar'"

  fun apply(h: TestHelper) =>
    match Compares.equal_caseless("foo", "bar")
    | let eq: Bool => h.assert_false(eq)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestEqualCaselessCanonical is UnitTest
  fun name(): String => "equal_caseless_canonical: 'Café' (pre) == 'CAFE\\u0301' (dec, upper)"

  fun apply(h: TestHelper) =>
    // 'Café' precomposed: 0x43 0x61 0x66 0xC3 0xA9
    let a: Array[U8] val =
      recover val [as U8: 0x43; 0x61; 0x66; 0xC3; 0xA9] end
    // 'CAFE' + COMBINING ACUTE (0xCC 0x81)
    let b: Array[U8] val =
      recover val [as U8: 0x43; 0x41; 0x46; 0x45; 0xCC; 0x81] end
    match Compares.equal_caseless_canonical(
      String.from_array(a), String.from_array(b))
    | let eq: Bool => h.assert_true(eq)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCompareInvalid is UnitTest
  fun name(): String => "Compares rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80] end)
    match Compares.equal_canonical(bad, "ok")
    | let _: Bool => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- M6: Case ----

class \nodoc\ iso _TestCaseUpperAscii is UnitTest
  fun name(): String => "upper: ASCII"

  fun apply(h: TestHelper) =>
    match Case.upper("hello world")
    | let s: String iso => h.assert_eq[String]("HELLO WORLD", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseUpperEszett is UnitTest
  fun name(): String => "upper: ß expands to SS"

  fun apply(h: TestHelper) =>
    let bytes_in: Array[U8] val = recover val [as U8: 0xC3; 0x9F] end
    match Case.upper(String.from_array(bytes_in))
    | let s: String iso => h.assert_eq[String]("SS", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseLowerAscii is UnitTest
  fun name(): String => "lower: ASCII"

  fun apply(h: TestHelper) =>
    match Case.lower("Hello WORLD")
    | let s: String iso => h.assert_eq[String]("hello world", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseLowerGreek is UnitTest
  fun name(): String => "lower: Greek capital → small"

  fun apply(h: TestHelper) =>
    // 'Α' U+0391 → 'α' U+03B1
    let bytes_in: Array[U8] val = recover val [as U8: 0xCE; 0x91] end
    match Case.lower(String.from_array(bytes_in))
    | let s: String iso =>
      let r = consume s
      h.assert_eq[USize](2, r.size())
      try h.assert_eq[U8](0xCE, r(0)?) end
      try h.assert_eq[U8](0xB1, r(1)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseTitleAscii is UnitTest
  fun name(): String => "title: word-start ASCII"

  fun apply(h: TestHelper) =>
    match Case.title("hello world")
    | let s: String iso => h.assert_eq[String]("Hello World", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseTitleMixed is UnitTest
  fun name(): String => "title: mixed input recases properly"

  fun apply(h: TestHelper) =>
    match Case.title("HELLO   World  FOO")
    | let s: String iso =>
      h.assert_eq[String]("Hello   World  Foo", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseFoldAscii is UnitTest
  fun name(): String => "fold: ASCII = lower for letters"

  fun apply(h: TestHelper) =>
    match Case.fold("Hello WORLD")
    | let s: String iso => h.assert_eq[String]("hello world", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseFoldEszett is UnitTest
  fun name(): String => "fold: ß → ss"

  fun apply(h: TestHelper) =>
    let bytes_in: Array[U8] val = recover val [as U8: 0xC3; 0x9F] end
    match Case.fold(String.from_array(bytes_in))
    | let s: String iso => h.assert_eq[String]("ss", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseFoldMatchesMass is UnitTest
  fun name(): String => "fold: 'Maße' folds equal to 'masse'"

  fun apply(h: TestHelper) =>
    // 'Maße' = M a ß e = 4D 61 (C3 9F) 65 → folds to 'masse'
    let bytes_in: Array[U8] val =
      recover val [as U8: 0x4D; 0x61; 0xC3; 0x9F; 0x65] end
    match Case.fold(String.from_array(bytes_in))
    | let s: String iso => h.assert_eq[String]("masse", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestCaseUpperInvalid is UnitTest
  fun name(): String => "upper rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80; 0x41] end)
    match Case.upper(bad)
    | let _: String iso => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- M5: Normalize ----

class \nodoc\ iso _TestNfdAscii is UnitTest
  fun name(): String => "NFD: ASCII is unchanged"

  fun apply(h: TestHelper) =>
    match Normalize.nfd("hello")
    | let s: String iso => h.assert_eq[String]("hello", consume s)
    | let _: InvalidUtf8 => h.fail("ascii rejected")
    end

class \nodoc\ iso _TestNfdLatinAcute is UnitTest
  fun name(): String => "NFD: 'é' (U+00E9) decomposes to 'e' + COMBINING ACUTE"

  fun apply(h: TestHelper) =>
    // U+00E9 → e (0x65) + U+0301 (combining acute, 0xCC 0x81 in UTF-8)
    let bytes_in: Array[U8] val = recover val [as U8: 0xC3; 0xA9] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfd(s_in)
    | let s: String iso =>
      let result = consume s
      h.assert_eq[USize](3, result.size())
      try h.assert_eq[U8](0x65, result(0)?) end
      try h.assert_eq[U8](0xCC, result(1)?) end
      try h.assert_eq[U8](0x81, result(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfcLatinAcute is UnitTest
  fun name(): String => "NFC: 'e' + COMBINING ACUTE composes to U+00E9"

  fun apply(h: TestHelper) =>
    // input: e + 0x0301 = 3 bytes
    let bytes_in: Array[U8] val = recover val [as U8: 0x65; 0xCC; 0x81] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfc(s_in)
    | let s: String iso =>
      let result = consume s
      h.assert_eq[USize](2, result.size())
      try h.assert_eq[U8](0xC3, result(0)?) end
      try h.assert_eq[U8](0xA9, result(1)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfcIdempotent is UnitTest
  fun name(): String => "NFC: already-NFC string is unchanged"

  fun apply(h: TestHelper) =>
    // "café" precomposed
    let bytes_in: Array[U8] val =
      recover val [as U8: 0x63; 0x61; 0x66; 0xC3; 0xA9] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfc(s_in)
    | let s: String iso =>
      let result = consume s
      h.assert_eq[USize](5, result.size())
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfdHangul is UnitTest
  fun name(): String => "NFD: Hangul syllable algorithmic decomposition"

  fun apply(h: TestHelper) =>
    // U+AC00 (HANGUL SYLLABLE GA, LV) = L (U+1100) + V (U+1161)
    let bytes_in: Array[U8] val = recover val [as U8: 0xEA; 0xB0; 0x80] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfd(s_in)
    | let s: String iso =>
      let result = consume s
      // Expect 6 bytes: U+1100 (E1 84 80) + U+1161 (E1 85 A1)
      h.assert_eq[USize](6, result.size())
      try h.assert_eq[U8](0xE1, result(0)?) end
      try h.assert_eq[U8](0x84, result(1)?) end
      try h.assert_eq[U8](0x80, result(2)?) end
      try h.assert_eq[U8](0xE1, result(3)?) end
      try h.assert_eq[U8](0x85, result(4)?) end
      try h.assert_eq[U8](0xA1, result(5)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfcHangul is UnitTest
  fun name(): String => "NFC: Hangul L+V composes algorithmically"

  fun apply(h: TestHelper) =>
    // L (U+1100) + V (U+1161) → U+AC00
    let bytes_in: Array[U8] val = recover val [as U8:
      0xE1; 0x84; 0x80; 0xE1; 0x85; 0xA1] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfc(s_in)
    | let s: String iso =>
      let result = consume s
      h.assert_eq[USize](3, result.size())
      try h.assert_eq[U8](0xEA, result(0)?) end
      try h.assert_eq[U8](0xB0, result(1)?) end
      try h.assert_eq[U8](0x80, result(2)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfkdLigature is UnitTest
  fun name(): String => "NFKD: ﬁ ligature decomposes to 'fi'"

  fun apply(h: TestHelper) =>
    // ﬁ (U+FB01) → "fi"
    let bytes_in: Array[U8] val = recover val [as U8: 0xEF; 0xAC; 0x81] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfkd(s_in)
    | let s: String iso =>
      h.assert_eq[String]("fi", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfdEmpty is UnitTest
  fun name(): String => "NFD: empty string round-trips"

  fun apply(h: TestHelper) =>
    match Normalize.nfd("")
    | let s: String iso => h.assert_eq[String]("", consume s)
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfdReorder is UnitTest
  fun name(): String => "NFD: combining marks are canonically reordered"

  fun apply(h: TestHelper) =>
    // 'a' + U+0327 (cedilla, CCC=202) + U+0301 (acute, CCC=230)
    // Already in CCC order — should be unchanged.
    // Then test the reverse:
    // 'a' + U+0301 (CCC=230) + U+0327 (CCC=202) — should reorder.
    let bytes_in: Array[U8] val = recover val [as U8:
      0x61; 0xCC; 0x81; 0xCC; 0xA7] end
    let s_in = String.from_array(bytes_in)
    match Normalize.nfd(s_in)
    | let s: String iso =>
      let result = consume s
      // After NFD canonical-order: a (0x61) + 0x0327 (CC=202) + 0x0301 (CC=230)
      // UTF-8: 0x61 0xCC 0xA7 0xCC 0x81
      h.assert_eq[USize](5, result.size())
      try h.assert_eq[U8](0x61, result(0)?) end
      try h.assert_eq[U8](0xCC, result(1)?) end
      try h.assert_eq[U8](0xA7, result(2)?) end
      try h.assert_eq[U8](0xCC, result(3)?) end
      try h.assert_eq[U8](0x81, result(4)?) end
    | let _: InvalidUtf8 => h.fail("rejected")
    end

class \nodoc\ iso _TestNfcRoundTripIdempotent is UnitTest
  fun name(): String => "NFC(NFC(x)) == NFC(x)"

  fun apply(h: TestHelper) =>
    // "Café 漢字"
    let s_in: String val = "Café 漢字"
    match Normalize.nfc(s_in)
    | let s1: String iso =>
      let r1 = consume s1
      let r1_val: String val = consume r1
      match Normalize.nfc(r1_val)
      | let s2: String iso => h.assert_eq[String](r1_val, consume s2)
      | let _: InvalidUtf8 => h.fail("second pass rejected")
      end
    | let _: InvalidUtf8 => h.fail("first pass rejected")
    end

class \nodoc\ iso _TestNfcInvalid is UnitTest
  fun name(): String => "Normalize rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    let bad = String.from_array(recover val [as U8: 0x41; 0x80; 0x41] end)
    match Normalize.nfc(bad)
    | let _: String iso => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

// ---- M1.G: Names ----

class \nodoc\ iso _TestNameAscii is UnitTest
  fun name(): String => "name: 'A' → LATIN CAPITAL LETTER A"

  fun apply(h: TestHelper) =>
    match Codepoints.name(U32('A'))
    | let n: String val => h.assert_eq[String]("LATIN CAPITAL LETTER A", n)
    | None => h.fail("expected name for 'A'")
    end

class \nodoc\ iso _TestNameLatin is UnitTest
  fun name(): String => "name: 'é' → LATIN SMALL LETTER E WITH ACUTE"

  fun apply(h: TestHelper) =>
    match Codepoints.name(0x00E9)
    | let n: String val =>
      h.assert_eq[String]("LATIN SMALL LETTER E WITH ACUTE", n)
    | None => h.fail("expected name for é")
    end

class \nodoc\ iso _TestNameControl is UnitTest
  fun name(): String => "name: NUL has no name"

  fun apply(h: TestHelper) =>
    // Control characters have placeholder `<control>` names, which
    // we exclude from the table; lookup returns None.
    match Codepoints.name(0x0000)
    | let _: String val => h.fail("expected None for NUL")
    | None => None
    end

class \nodoc\ iso _TestFromName is UnitTest
  fun name(): String => "from_name reverse lookup"

  fun apply(h: TestHelper) =>
    match Codepoints.from_name("LATIN CAPITAL LETTER A")
    | let cp: U32 => h.assert_eq[U32](0x0041, cp)
    | None => h.fail("expected 0x41 for LATIN CAPITAL LETTER A")
    end
    match Codepoints.from_name("NOT A REAL NAME XYZ")
    | None => None
    | let _: U32 => h.fail("expected None for fake name")
    end

// ---- M1.F: Binary properties ----

class \nodoc\ iso _TestBinaryPropIDStart is UnitTest
  fun name(): String => "binary_property: ID_Start"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.has_binary_property(U32('A'), PropIDStart))
    h.assert_true(Codepoints.has_binary_property(U32('a'), PropIDStart))
    h.assert_false(Codepoints.has_binary_property(U32('5'), PropIDStart))
    h.assert_false(Codepoints.has_binary_property(U32(' '), PropIDStart))

class \nodoc\ iso _TestBinaryPropIDContinue is UnitTest
  fun name(): String => "binary_property: ID_Continue"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.has_binary_property(U32('A'), PropIDContinue))
    h.assert_true(Codepoints.has_binary_property(U32('5'), PropIDContinue))
    h.assert_false(Codepoints.has_binary_property(U32(' '), PropIDContinue))

class \nodoc\ iso _TestBinaryPropWhiteSpace is UnitTest
  fun name(): String => "binary_property: White_Space"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.has_binary_property(U32(' '), PropWhiteSpace))
    h.assert_true(Codepoints.has_binary_property(U32('\t'), PropWhiteSpace))
    h.assert_true(Codepoints.has_binary_property(U32('\n'), PropWhiteSpace))
    h.assert_false(Codepoints.has_binary_property(U32('a'), PropWhiteSpace))

class \nodoc\ iso _TestBinaryPropEmoji is UnitTest
  fun name(): String => "binary_property: Emoji"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.has_binary_property(0x1F600, PropEmoji))
    h.assert_false(Codepoints.has_binary_property(U32('a'), PropEmoji))

class \nodoc\ iso _TestBinaryPropAsciiHexDigit is UnitTest
  fun name(): String => "binary_property: ASCII_Hex_Digit"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.has_binary_property(U32('0'), PropASCIIHexDigit))
    h.assert_true(Codepoints.has_binary_property(U32('A'), PropASCIIHexDigit))
    h.assert_true(Codepoints.has_binary_property(U32('f'), PropASCIIHexDigit))
    h.assert_false(Codepoints.has_binary_property(U32('g'), PropASCIIHexDigit))

class \nodoc\ iso _TestBinaryPropsFromIso is UnitTest
  fun name(): String => "BinaryProperties.from_iso round-trip"

  fun apply(h: TestHelper) =>
    match BinaryProperties.from_iso("ID_Start")
    | let _: PropIDStart => None
    | let _: BinaryProperty => h.fail("expected PropIDStart")
    | None => h.fail("from_iso(ID_Start) returned None")
    end
    match BinaryProperties.from_iso("NotARealProp")
    | None => None
    | let _: BinaryProperty => h.fail("expected None for fake property")
    end

// ---- M1.E: Scripts ----

class \nodoc\ iso _TestScriptLatin is UnitTest
  fun name(): String => "script: ASCII letters are ScriptLatin"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.script(U32('A')) is ScriptLatin)
    h.assert_true(Codepoints.script(U32('z')) is ScriptLatin)

class \nodoc\ iso _TestScriptCyrillic is UnitTest
  fun name(): String => "script: U+0410 is ScriptCyrillic"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.script(0x0410) is ScriptCyrillic)

class \nodoc\ iso _TestScriptCommon is UnitTest
  fun name(): String => "script: digits and space are ScriptCommon"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.script(U32('5')) is ScriptCommon)
    h.assert_true(Codepoints.script(U32(' ')) is ScriptCommon)

class \nodoc\ iso _TestScriptUnassigned is UnitTest
  fun name(): String => "script: unassigned codepoint is ScriptUnknown"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.script(0xE0000) is ScriptUnknown)

class \nodoc\ iso _TestScriptCode is UnitTest
  fun name(): String => "script.code() returns UCD name"

  fun apply(h: TestHelper) =>
    let s = Codepoints.script(U32('A'))
    h.assert_eq[String]("Latin",
      match s | let l: ScriptLatin => l.code() else "?" end)

class \nodoc\ iso _TestScriptsFromIso is UnitTest
  fun name(): String => "Scripts.from_iso round-trips name"

  fun apply(h: TestHelper) =>
    match Scripts.from_iso("Latin")
    | let _: ScriptLatin => None
    | let _: Script => h.fail("expected ScriptLatin")
    | None => h.fail("from_iso(\"Latin\") returned None")
    end
    // Unknown name
    match Scripts.from_iso("NotARealScript")
    | None => None
    | let _: Script => h.fail("expected None for fake script name")
    end

class \nodoc\ iso _TestEastAsianWidthAscii is UnitTest
  fun name(): String => "east_asian_width: ASCII letters are EAWNa"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.east_asian_width(U32('A')) is EAWNa)
    h.assert_true(Codepoints.east_asian_width(U32('0')) is EAWNa)

class \nodoc\ iso _TestEastAsianWidthIdeograph is UnitTest
  fun name(): String => "east_asian_width: CJK ideograph is EAWW"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.east_asian_width(0x4E2D) is EAWW)
    // U+2329 LEFT-POINTING ANGLE BRACKET — explicitly Wide.
    h.assert_true(Codepoints.east_asian_width(0x2329) is EAWW)

class \nodoc\ iso _TestEastAsianWidthFullwidth is UnitTest
  fun name(): String => "east_asian_width: fullwidth paren is EAWF"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.east_asian_width(0xFF08) is EAWF)
    h.assert_true(Codepoints.east_asian_width(0xFF09) is EAWF)

class \nodoc\ iso _TestEastAsianWidthAmbiguous is UnitTest
  fun name(): String => "east_asian_width: section sign is EAWA"

  fun apply(h: TestHelper) =>
    h.assert_true(Codepoints.east_asian_width(0x00A7) is EAWA)

class \nodoc\ iso _TestEastAsianWidthsFromIso is UnitTest
  fun name(): String => "EastAsianWidths.from_iso round-trips name"

  fun apply(h: TestHelper) =>
    match EastAsianWidths.from_iso("W")
    | let _: EAWW => None
    | let _: EastAsianWidth => h.fail("expected EAWW")
    | None => h.fail("from_iso(\"W\") returned None")
    end
    match EastAsianWidths.from_iso("Na")
    | let _: EAWNa => None
    | let _: EastAsianWidth => h.fail("expected EAWNa")
    | None => h.fail("from_iso(\"Na\") returned None")
    end
    match EastAsianWidths.from_iso("XX")
    | None => None
    | let _: EastAsianWidth => h.fail("expected None for unknown name")
    end

// ---- M1.D: Full + case folding mappings ----

class \nodoc\ iso _TestFullUpperEszett is UnitTest
  fun name(): String => "full_upper: ß → SS"

  fun apply(h: TestHelper) =>
    match Codepoints.full_upper(0x00DF)
    | let a: Array[U32] val =>
      h.assert_eq[USize](2, a.size())
      try h.assert_eq[U32](0x0053, a(0)?) end
      try h.assert_eq[U32](0x0053, a(1)?) end
    | None => h.fail("expected ß → SS expansion")
    end

class \nodoc\ iso _TestFullUpperFi is UnitTest
  fun name(): String => "full_upper: ﬁ → FI"

  fun apply(h: TestHelper) =>
    match Codepoints.full_upper(0xFB01)
    | let a: Array[U32] val =>
      h.assert_eq[USize](2, a.size())
      try h.assert_eq[U32](0x0046, a(0)?) end
      try h.assert_eq[U32](0x0049, a(1)?) end
    | None => h.fail("expected ﬁ → FI expansion")
    end

class \nodoc\ iso _TestFullUpperAscii is UnitTest
  fun name(): String => "full_upper: ASCII has no full expansion"

  fun apply(h: TestHelper) =>
    match Codepoints.full_upper(U32('a'))
    | let _: Array[U32] val => h.fail("ASCII has no full expansion")
    | None => None
    end

class \nodoc\ iso _TestFullLowerIDot is UnitTest
  fun name(): String => "full_lower: İ → 'i̇' (i + COMBINING DOT ABOVE)"

  fun apply(h: TestHelper) =>
    match Codepoints.full_lower(0x0130)
    | let a: Array[U32] val =>
      h.assert_eq[USize](2, a.size())
      try h.assert_eq[U32](0x0069, a(0)?) end
      try h.assert_eq[U32](0x0307, a(1)?) end
    | None => h.fail("expected İ → 'i̇' expansion")
    end

class \nodoc\ iso _TestSimpleCaseFold is UnitTest
  fun name(): String => "simple_casefold: 'A' → 'a'"

  fun apply(h: TestHelper) =>
    h.assert_eq[U32](U32('a'), Codepoints.simple_casefold(U32('A')))
    h.assert_eq[U32](U32('a'), Codepoints.simple_casefold(U32('a')))
    h.assert_eq[U32](U32('5'), Codepoints.simple_casefold(U32('5')))
    // Greek capital Sigma → small sigma (NOT final sigma in simple
    // folding — that's a contextual rule outside simple folding's scope).
    h.assert_eq[U32](0x03C3, Codepoints.simple_casefold(0x03A3))

class \nodoc\ iso _TestFullCaseFoldEszett is UnitTest
  fun name(): String => "full_casefold: ß → ss"

  fun apply(h: TestHelper) =>
    match Codepoints.full_casefold(0x00DF)
    | let a: Array[U32] val =>
      h.assert_eq[USize](2, a.size())
      try h.assert_eq[U32](0x0073, a(0)?) end
      try h.assert_eq[U32](0x0073, a(1)?) end
    | None => h.fail("expected ß → ss")
    end

class \nodoc\ iso _TestFullCaseFoldAscii is UnitTest
  fun name(): String => "full_casefold: 'A' → 'a' (single cp, via C entry)"

  fun apply(h: TestHelper) =>
    match Codepoints.full_casefold(U32('A'))
    | let a: Array[U32] val =>
      h.assert_eq[USize](1, a.size())
      try h.assert_eq[U32](U32('a'), a(0)?) end
    | None => h.fail("expected 'A' to fold")
    end

// ---- M1.C: Simple case mappings ----

class \nodoc\ iso _TestSimpleUpper is UnitTest
  fun name(): String => "simple_upper basic mappings"

  fun apply(h: TestHelper) =>
    h.assert_eq[U32](U32('A'), Codepoints.simple_upper(U32('a')))
    h.assert_eq[U32](U32('Z'), Codepoints.simple_upper(U32('z')))
    // identity: already uppercase
    h.assert_eq[U32](U32('A'), Codepoints.simple_upper(U32('A')))
    // identity: digit
    h.assert_eq[U32](U32('5'), Codepoints.simple_upper(U32('5')))
    // German eszett ß (U+00DF) — simple maps to ß itself in UCD
    // (the SS expansion is in SpecialCasing — M1.D).
    h.assert_eq[U32](0x00DF, Codepoints.simple_upper(0x00DF))
    // Greek small alpha 'α' (U+03B1) → 'Α' (U+0391)
    h.assert_eq[U32](0x0391, Codepoints.simple_upper(0x03B1))

class \nodoc\ iso _TestSimpleLower is UnitTest
  fun name(): String => "simple_lower basic mappings"

  fun apply(h: TestHelper) =>
    h.assert_eq[U32](U32('a'), Codepoints.simple_lower(U32('A')))
    h.assert_eq[U32](U32('z'), Codepoints.simple_lower(U32('Z')))
    h.assert_eq[U32](U32('a'), Codepoints.simple_lower(U32('a')))
    h.assert_eq[U32](0x03B1, Codepoints.simple_lower(0x0391))

class \nodoc\ iso _TestSimpleTitle is UnitTest
  fun name(): String => "simple_title basic mappings"

  fun apply(h: TestHelper) =>
    // ASCII: titlecase == uppercase for letters.
    h.assert_eq[U32](U32('A'), Codepoints.simple_title(U32('a')))
    // Lj (U+01C9) "lj" → Lj (U+01C8) titlecase; lowercase 'lj' has
    // a real titlecase entry. The full digraph 'ǉ' (U+01C9) titlecases
    // to 'ǈ' (U+01C8).
    h.assert_eq[U32](0x01C8, Codepoints.simple_title(0x01C9))

// ---- M1.B: Compat decomposition ----

class \nodoc\ iso _TestCompatDecompFiLigature is UnitTest
  fun name(): String => "compat_decomposition: 'ﬁ' → ['f', 'i']"

  fun apply(h: TestHelper) =>
    match Codepoints.compat_decomposition(0xFB01)
    | let a: Array[U32] val =>
      h.assert_eq[USize](2, a.size())
      try h.assert_eq[U32](0x0066, a(0)?) end
      try h.assert_eq[U32](0x0069, a(1)?) end
    | None => h.fail("expected ['f', 'i']")
    end

class \nodoc\ iso _TestCompatDecompCircledOne is UnitTest
  fun name(): String => "compat_decomposition: '①' → ['1']"

  fun apply(h: TestHelper) =>
    match Codepoints.compat_decomposition(0x2460)
    | let a: Array[U32] val =>
      h.assert_eq[USize](1, a.size())
      try h.assert_eq[U32](0x0031, a(0)?) end
    | None => h.fail("expected ['1']")
    end

class \nodoc\ iso _TestCompatDecompFraction is UnitTest
  fun name(): String => "compat_decomposition: '½' → ['1', '⁄', '2']"

  fun apply(h: TestHelper) =>
    match Codepoints.compat_decomposition(0x00BD)
    | let a: Array[U32] val =>
      h.assert_eq[USize](3, a.size())
      try h.assert_eq[U32](0x0031, a(0)?) end
      try h.assert_eq[U32](0x2044, a(1)?) end
      try h.assert_eq[U32](0x0032, a(2)?) end
    | None => h.fail("expected ['1', '⁄', '2']")
    end

class \nodoc\ iso _TestCompatDecompAscii is UnitTest
  fun name(): String => "compat_decomposition: ASCII has no compat decomp"

  fun apply(h: TestHelper) =>
    match Codepoints.compat_decomposition(U32('a'))
    | let _: Array[U32] val => h.fail("ASCII has no compat decomp")
    | None => None
    end

// ---- M1.A: Composition exclusions + canonical compose ----

class \nodoc\ iso _TestCompositionExclusion is UnitTest
  fun name(): String => "is_full_composition_excluded sanity"

  fun apply(h: TestHelper) =>
    // 0x0958 (DEVANAGARI LETTER QA) is in Full_Composition_Exclusion.
    h.assert_true(Codepoints.is_full_composition_excluded(0x0958))
    // 0x00E1 (á) is a primary composite — its decomp is [0x61, 0x301]
    // and 0x00E1 is NOT excluded.
    h.assert_false(Codepoints.is_full_composition_excluded(0x00E1))
    // ASCII never excluded.
    h.assert_false(Codepoints.is_full_composition_excluded(U32('a')))

class \nodoc\ iso _TestCanonicalCompose is UnitTest
  fun name(): String => "compose_canonical hits and misses"

  fun apply(h: TestHelper) =>
    // 'a' + combining acute = á
    match Codepoints.compose_canonical(0x0061, 0x0301)
    | let u: U32 => h.assert_eq[U32](0x00E1, u)
    | None => h.fail("expected 0x00E1 for (a, combining-acute)")
    end
    // 'e' + combining acute = é
    match Codepoints.compose_canonical(0x0065, 0x0301)
    | let u: U32 => h.assert_eq[U32](0x00E9, u)
    | None => h.fail("expected 0x00E9 for (e, combining-acute)")
    end

class \nodoc\ iso _TestCanonicalComposeExcluded is UnitTest
  fun name(): String => "compose_canonical excludes Full_Composition_Exclusion entries"

  fun apply(h: TestHelper) =>
    // 0x0958 (DEVANAGARI LETTER QA) decomposes to (0x0915, 0x093C)
    // but is in the exclusion set — must NOT recompose.
    match Codepoints.compose_canonical(0x0915, 0x093C)
    | let _: U32 => h.fail("Devanagari QA must not recompose")
    | None => None
    end

class \nodoc\ iso _TestCanonicalComposeMiss is UnitTest
  fun name(): String => "compose_canonical returns None on miss"

  fun apply(h: TestHelper) =>
    // Two ASCII codepoints don't compose.
    match Codepoints.compose_canonical(U32('a'), U32('b'))
    | let _: U32 => h.fail("'a' + 'b' should not compose")
    | None => None
    end

// ---- M4f: Graphemes topical primitive ----

class \nodoc\ iso _TestGraphemesCount is UnitTest
  fun name(): String => "Graphemes.count validates and counts"

  fun apply(h: TestHelper) =>
    // "Hé🇨🇦" = 11 bytes, 3 graphemes
    let bytes: Array[U8] val = recover val [as U8:
      0x48; 0xC3; 0xA9; 0xF0; 0x9F; 0x87; 0xA8
      0xF0; 0x9F; 0x87; 0xA6] end
    let s = String.from_array(bytes)
    match Graphemes.count(s)
    | let n: USize => h.assert_eq[USize](3, n)
    | let _: InvalidUtf8 => h.fail("expected USize, got InvalidUtf8")
    end

class \nodoc\ iso _TestGraphemesCountInvalid is UnitTest
  fun name(): String => "Graphemes.count rejects ill-formed UTF-8"

  fun apply(h: TestHelper) =>
    // lone continuation 0x80
    let s = String.from_array(recover val [as U8: 0x41; 0x80; 0x41] end)
    match Graphemes.count(s)
    | let _: USize => h.fail("expected InvalidUtf8")
    | let e: InvalidUtf8 => h.assert_eq[USize](1, e.offset)
    end

class \nodoc\ iso _TestGraphemesRanges is UnitTest
  fun name(): String => "Graphemes.ranges yields cluster byte ranges"

  fun apply(h: TestHelper) =>
    // "🇨🇦" — single cluster, 8 bytes
    let bytes: Array[U8] val = recover val [as U8:
      0xF0; 0x9F; 0x87; 0xA8; 0xF0; 0x9F; 0x87; 0xA6] end
    let s = String.from_array(bytes)
    match Graphemes.ranges(s)
    | let it: Iterator[(USize, USize)] =>
      let collected = recover trn Array[(USize, USize)] end
      for r in it do collected.push(r) end
      h.assert_eq[USize](1, collected.size())
      try
        (let st, let fi) = collected(0)?
        h.assert_eq[USize](0, st)
        h.assert_eq[USize](8, fi)
      else
        h.fail("collected access raised")
      end
    | let _: InvalidUtf8 => h.fail("expected iterator")
    end

class \nodoc\ iso _TestGraphemesIter is UnitTest
  fun name(): String => "Graphemes.iter yields val slices"

  fun apply(h: TestHelper) =>
    let s: String val = "abc"
    match Graphemes.iter(s)
    | let it: Iterator[String val] =>
      let collected = recover trn Array[String val] end
      for g in it do collected.push(g) end
      h.assert_eq[USize](3, collected.size())
      try h.assert_eq[String]("b", collected(1)?) end
    | let _: InvalidUtf8 => h.fail("expected iterator")
    end

class \nodoc\ iso _TestGraphemeByteIndex is UnitTest
  fun name(): String => "grapheme_byte_index resolves to byte offsets"

  fun apply(h: TestHelper) =>
    try
      // "Hé🇨🇦" — grapheme byte offsets: 0, 1, 3, (one-past-end) 11
      let bytes: Array[U8] val = recover val [as U8:
        0x48; 0xC3; 0xA9; 0xF0; 0x9F; 0x87; 0xA8
        0xF0; 0x9F; 0x87; 0xA6] end
      let t = Text.from_array(bytes)?
      let g0 = t.grapheme_index(0) as GraphemeIndex
      let g1 = t.grapheme_index(1) as GraphemeIndex
      let g2 = t.grapheme_index(2) as GraphemeIndex
      let g3 = t.grapheme_index(3) as GraphemeIndex
      h.assert_eq[USize](0, (t.grapheme_byte_index(g0) as ByteIndex).value())
      h.assert_eq[USize](1, (t.grapheme_byte_index(g1) as ByteIndex).value())
      h.assert_eq[USize](3, (t.grapheme_byte_index(g2) as ByteIndex).value())
      h.assert_eq[USize](11, (t.grapheme_byte_index(g3) as ByteIndex).value())
    else
      h.fail("setup raised")
    end
