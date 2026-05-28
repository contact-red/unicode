# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Fixed


### Added

- `WordBreak` closed union (20 values) + auto-generated `_UcdWordBreak` lookup from `WordBreakProperty.txt` and emoji-data
- `_WordBreakCursor` UAX #29 word boundary state machine — implements WB1..WB16 including the lookahead-dependent rules (WB6, WB7b, WB12)
- `Words` topical primitive: `count`, `ranges`, `iter` over `String box`
- `make conform-word`: UAX #29 WordBreakTest.txt conformance (1,826 cases — 100% pass on Unicode 16.0.0)

- Grapheme cursor now implements UAX #29 GB9c (Indic_Conjunct_Break, Unicode 15.1). Sequences like Devanagari KA + VIRAMA + TA are now correctly treated as a single cluster. Caught by the new GraphemeBreakTest.txt conformance runner.


### Added

- Package skeleton (corral.json, Makefile, VERSION, CHANGELOG, README, source/test dirs)
- `unicode-build` codegen tool: separate Pony package that reads UCD source files and emits per-property tables into `unicode/_ucd_*.pony`
- `make ucd-download` — fetches authoritative UCD files from unicode.org
- `make ucd-generate` — runs codegen against `./ucd/`
- `make conform` — runs the UAX #15 NormalizationTest.txt suite; all 18,992 test cases pass (100% conformance for canonical/compatibility normalization)
- Shared `_UcdHex` decoder (ASCII hex-pair encoding for all UCD tables — avoids ponyc's slow Array[U8] typecheck on large literals)
- Generated UCD tables: `_UcdCategory`, `_UcdCombiningClass`, `_UcdCanonicalDecomp`, `_UcdCompatDecomp`, `_UcdCompositionExclusion`, `_UcdCanonicalCompose`, `_UcdGraphemeBreak`
- Generated case tables: `_UcdSimpleUpper`, `_UcdSimpleLower`, `_UcdSimpleTitle`, `_UcdFullUpper`, `_UcdFullLower`, `_UcdFullTitle`, `_UcdSimpleCaseFold`, `_UcdFullCaseFold`
- Auto-generated `Script` closed union (163 scripts) + `_UcdScript` cp-range table
- Auto-generated `BinaryProperty` closed union (~58 properties from PropList, DerivedCoreProperties, emoji-data) + `_UcdBinaryProps` per-property tables
- `_UcdName` — Unicode names table (~30k entries, forward and linear-scan reverse lookup)
- `Bytes` topical primitive — RFC 3629 UTF-8 validator (overlong, surrogate, truncated, above-max rejection)
- `Text` class (default cap val) — validated-UTF-8 wrapper with constructors `create`, `from_string`, `from_array`, `from_iso_string`, `from_iso_array`
- Optional grapheme bitmap index via `from_*(indexed=true)` for O(1) `size_graphemes` / `size_codepoints`; `with_index()` / `without_index()` flip methods
- Phantom-typed indices `ByteIndex`, `CodepointIndex`, `GraphemeIndex` via generic `Index[Kind]`
- `Codepoint` class val + `Codepoints` topical primitive (factories, U32-form predicates, string-level ops, full UCD accessors including `name`, `from_name`, `script`, `has_binary_property`)
- `GraphemeBreak` closed union + `Graphemes` topical primitive — UAX #29 cluster iteration with reusable `_GraphemeCursor` state machine
- `Normalize` primitive — `nfd`, `nfc`, `nfkd`, `nfkc` (UAX #15; 100% NormalizationTest.txt pass)
- `Case` primitive — `upper`, `lower`, `title`, `fold` with full → simple → identity fallback per codepoint
- `Compares` primitive — `bytes`, `equal_bytes`, `equal_canonical`, `equal_compat`, `equal_caseless`, `equal_caseless_canonical` (UAX #21 D146)
- `Search` primitive — `contains`, `starts_with`, `ends_with`, `index_of`, `last_index_of`, `count`
- `Split` primitive — `on(sep)`, `lines` (handles `\n`, `\r`, `\r\n`)
- `Trim` primitive — `trim`, `trim_start`, `trim_end` over the White_Space property
- `Replace` primitive — `all`, `first`
- Error types: `InvalidUtf8(offset)`, `OutOfRange(index, size)`, `InvalidScalar(value)`
- `IndicConjunctBreak` closed union (`InCBNone` / `InCBConsonant` / `InCBLinker` / `InCBExtend`) and `_UcdIndicConjunctBreak` lookup table; surfaced via `Codepoints.indic_conjunct_break`
- `make conform`: NormalizationTest.txt Part 2 — for every assigned cp not in @Part1 of the test file, verify X == NFC(X) == NFD(X) == NFKC(X) == NFKD(X)
- `make conform-grapheme`: UAX #29 GraphemeBreakTest.txt conformance (1,093 cases including GB9c)
- 146 PonyCheck unit tests
- GitHub Actions CI: pr workflow with lint, changelog verify, and full normalization + grapheme conformance

### Changed

