# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Added

- Package skeleton (corral.json, Makefile, VERSION, CHANGELOG, README, source/test dirs)
- `unicode-build` codegen tool: separate Pony package (`unicode_build/` + `unicode_build_main/`) that reads UCD source files and emits per-property tables into `unicode/_ucd_*.pony`
- `make ucd-download` target — fetches authoritative UCD files from unicode.org into `./ucd/`
- `make ucd-generate` target — runs codegen against `./ucd/` and emits generated tables
- `Category` closed union and `Categories` primitive (`from_iso` lookup) — runtime types for UAX #44 General Category
- Generated `_UcdCategory` lookup table from UnicodeData.txt with binary-search-over-coalesced-ranges
- `Codepoints` topical primitive — currently exposes `category(u)`, `combining_class(u)`, `canonical_decomposition(u)`; full surface lands in M3
- Generated `_UcdCombiningClass` and `_UcdCanonicalDecomp` lookups (foundation for M5 NFC/NFD)
- Shared `_UcdHex` decoder (ASCII hex-pair encoding for all UCD tables — avoids ponyc's slow `Array[U8]` typecheck on large literals)
- M2 foundation: `Bytes` topical primitive (`is_valid_utf8`, `first_bad_utf8_offset`) covering RFC 3629
- `Text` class (default cap val) with constructors: `create(len)`, `from_string(s)?`, `from_array(a)?`, `from_iso_string(consume s)?`, `from_iso_array(consume a)?`
- `Text.size_bytes()` and `Text.utf8_bytes()` (clones, returns `String iso^` per H4)
- `AllValid` sentinel for `Bytes.first_bad_utf8_offset` when input is fully valid
- Package-private `_IsoUtf8` validator for iso constructor paths (substructural rules prevent reusing the public `box`-taking Bytes function)
- PonyCheck tests covering category lookups, combining-class, canonical-decomp, RFC 3629 conformance (overlong, surrogate, truncated, above-max rejections), Text construction (valid/invalid/empty/round-trip/iso-adopt)

### Changed


### Fixed

