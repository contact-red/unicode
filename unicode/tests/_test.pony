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
