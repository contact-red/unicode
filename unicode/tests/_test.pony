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
