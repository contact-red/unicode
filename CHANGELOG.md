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
- `Codepoints` topical primitive (M1 surface: just `category(u: U32)`); full surface lands in M3
- PonyCheck tests covering category lookups across ASCII, Latin-1, emoji, controls, private-use, and unassigned codepoints

### Changed


### Fixed

