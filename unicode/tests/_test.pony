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
