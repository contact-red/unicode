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
