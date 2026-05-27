# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Added

#### Build & infrastructure

- Package skeleton (corral.json, Makefile, VERSION, CHANGELOG, README, source/test dirs)
- `unicode-build` codegen tool: separate Pony package that reads UCD source files and emits per-property tables into `unicode/_ucd_*.pony`
- `make ucd-download` — fetches authoritative UCD files from unicode.org
- `make ucd-generate` — runs codegen against `./ucd/`
- `make conform` — runs the UAX #15 NormalizationTest.txt suite (all 18,992 test cases pass — 100% conformance for canonical/compatibility normalization)
- Shared `_UcdHex` decoder (ASCII hex-pair encoding for all UCD tables — avoids ponyc's slow `Array[U8]` typecheck on large literals)

#### Generated UCD tables

- `_UcdCategory` — General Category (UAX #44)
- `_UcdCombiningClass` — Canonical Combining Class
- `_UcdCanonicalDecomp` — canonical decomposition (2 cps max)
- `_UcdCompatDecomp` — compatibility decomposition (variable length, two-table layout)
- `_UcdCompositionExclusion` — Full_Composition_Exclusion (NFC)
- `_UcdCanonicalCompose` — primary-composite (lhs, rhs) → result
- `_UcdGraphemeBreak` — UAX #29 Grapheme_Cluster_Break + Extended_Pictographic
- `_UcdSimpleUpper` / `_UcdSimpleLower` / `_UcdSimpleTitle` — simple case mappings
- `_UcdFullUpper` / `_UcdFullLower` / `_UcdFullTitle` — full (multi-cp) case mappings from SpecialCasing.txt
- `_UcdSimpleCaseFold` / `_UcdFullCaseFold` — case folding tables from CaseFolding.txt
- `_UcdScript` + auto-generated `Script` closed union (163 scripts)
- `_UcdBinaryProps` + auto-generated `BinaryProperty` closed union (~58 properties from PropList + DerivedCoreProperties + emoji-data)
- `_UcdName` — Unicode names (~30k entries, forward and linear-scan reverse lookup)

#### Runtime types and primitives

- `Bytes` — RFC 3629 UTF-8 validator (overlong, surrogate, truncated, above-max)
- `Text` (default cap `val`) — validated-UTF-8 wrapper; constructors `create`, `from_string`, `from_array`, `from_iso_string`, `from_iso_array`
- Optional bitmap index via `from_*(indexed=true)` for O(1) `size_graphemes` / `size_codepoints`; `with_index()` / `without_index()` flip methods
- Phantom-typed indices `ByteIndex`, `CodepointIndex`, `GraphemeIndex` (one `Index[Kind]` generic over `_IndexKind` markers)
- `Codepoint` class val + `Codepoints` primitive (factories, U32-form predicates, string-level ops, full UCD accessors)
- `GraphemeBreak` union + `Graphemes` primitive — UAX #29 cluster iteration (slices + ranges) with reusable `_GraphemeCursor` state machine
- `Normalize` — `nfd`, `nfc`, `nfkd`, `nfkc` (UAX #15; 100% NormalizationTest.txt pass)
- `Case` — `upper`, `lower`, `title`, `fold` with full → simple → identity fallback per codepoint
- `Compares` — `bytes`, `equal_bytes`, `equal_canonical`, `equal_compat`, `equal_caseless`, `equal_caseless_canonical` (UAX #21 D146)
- `Search` — `contains`, `starts_with`, `ends_with`, `index_of`, `last_index_of`, `count`
- `Split` — `on(sep)`, `lines` (handles `\n`, `\r`, `\r\n`)
- `Trim` — `trim`, `trim_start`, `trim_end` over the `White_Space` property
- `Replace` — `all`, `first`
- Error types: `InvalidUtf8(offset)`, `OutOfRange(index, size)`, `InvalidScalar(value)`

#### Tests

- 146 PonyCheck unit tests covering all of the above
- UAX #15 conformance: 18,992 test cases from NormalizationTest.txt — full pass

