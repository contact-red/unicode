# Testability Evaluation — Unicode Package Candidate v1

## Findings (impact-ordered)

### Structural

**S1. Indexed-Text correctness is observable only via output-equivalence against an algorithm-sharing reference.**

`is_indexed(): Bool` is exposed but the bitmap is not. The only viable cross-check is "every `t.indexed().grapheme_at(GraphemeIndex(k))` equals the k-th yield from `t.unindexed().graphemes()`." This is weaker than it looks: the design explicitly says iteration "internally builds a local grapheme-start bitmap once during iteration construction and walks it" — so the indexed and unindexed paths share the bitmap-construction algorithm. A bug in that algorithm passes both. Tests need a way to assert the bitmap against UCD's *byte-offset answer key* (`GraphemeBreakTest.txt` gives explicit positions). Add either a package-private `_gr_starts_for_test()` accessor or a package-private `_TextIndex.from_explicit_breaks(starts: Array[USize] val)` factory that builds an index from a known answer key, sidestepping the state machine.

**S2. Conformance tests need a low-level "is-break-at-byte-offset" primitive that the design doesn't expose.**

`GraphemeBreakTest.txt` and friends speak in byte/codepoint offsets with explicit breaks. Verifying conformance through the public API forces tests through `grapheme_at(GraphemeIndex(k))` and `byte_index_of_grapheme(g)` — which means the algorithm under test is on the path to the assertion. A package-private `Graphemes._is_break_at(s: String box, byte_offset: USize): Bool` is exactly what the conformance suite would consume.

**S3. Closed-union enumeration for tests is not addressed.**

`Script`, `Category`, `Property`, `NormalForm`, `CaseLocale`, `_DecodeKind`, `DecodePolicy`, `EncodePolicy` are all closed unions. Production code gets exhaustive-match safety. Tests that want "for every variant V, assert P(V)" must hand-maintain enumerations that silently drift when `unicode-build` adds a new variant. The candidate's own §10 #4 boasts that Unicode bumps cause compile errors in exhaustive matches — but only in production matches; test-side enumerations fall behind invisibly. Recommend `unicode-build` also emit package-private `Script._all: Array[Script] val`, `Category._all`, etc.

**S4. The validating boundary needs invalid-input generators that the design does not supply.**

`Text.from_string(garbage)?` is a load-bearing test target. To follow the pony-pbt-patterns valid/invalid/mixed triad, the test surface needs generators for every distinct UTF-8 failure mode of RFC 3629: overlong 2/3/4-byte, encoded surrogates, lead-without-continuation, continuation-without-lead, codepoints > 0x10FFFF, truncation, illegal start bytes (0xC0/0xC1/0xF5..0xFF). And specifically a `_BadUtf8.at(offset, kind)` factory that produces a `String` whose UTF-8 is good through byte N and breaks at byte N+1 — so a test can assert `_InvalidUtf8At(offset = N+1)` exactly. Either add a test-helper subpackage with `_BadUtf8` factories, or accept that the offset field on `_InvalidUtf8At` is only loosely tested.

**S5. `Text._form` is type-private; tests outside `Text` cannot observe the normal-form tag without a method.**

Per Pony's rules (pony-ref gotcha #6), `_field` is *type-private* (not package-private). So an in-package test in a different type cannot read `t._form` directly. The candidate references `is_normalized(form)` (which probes a single form) but the table lists no `normal_form(): NormalForm` accessor. Tests that want "after `t.normalize(NFCForm)` the form *is* `NFCForm`" must call `is_normalized` four times, which conflates "tag was set" with "is-normalized check works." Add `Text.normal_form(): NormalForm` as a public accessor.

**S6. The bitmap can be confirmed-exists but not confirmed-consistent.**

Restates S1 from a different angle. `is_indexed(): Bool` tells you the index field is non-`None`; it cannot tell you the index *matches the bytes*. Add a package-private `_TextIndex._validate(utf8: String val): (None | _CorruptIndex)` that recomputes and compares — O(n), used by tests only.

### Significant

**G1. `ScriptSet` exposes cardinality (`.resolved().size()`) but no test-friendly accessor for exact contents.**

§1 lists `ScriptSet` as `class val` with `.resolved()`. §8 H tests "size > 1" — but tests for "this text's scripts are exactly {Latin, Cyrillic}" need `contains(Script): Bool` or `to_array(): Array[Script] val`. Either expose `ScriptSet.contains(s: Script): Bool` or document that `ScriptSet` is opaque-by-design.

**G2. The `unicode-build` tool's own testability is unspecified.**

§7 defines `unicode-build` as a "separate small Pony package" generating `.pony` source. The main package's conformance tests cover lookup correctness on the codepoints they exercise — not table correctness in general. The build tool itself needs tests for parsing `UnicodeData.txt`, range-table compression, round-trip correctness, and `DerivedCoreProperties.txt` cross-checks. §7 is silent on this.

**G3. Per-public-method validation-gate testing is a process commitment, not a design feature.**

§2's "logic in primitives; both surfaces delegate" means every public topical-primitive method has a validation gate. Each gate is independently testable — but a test-author who only runs the happy path through `_X` will silently leave the gate uncovered. Recommend explicit valid/invalid/mixed-triad coverage for each public method.

**G4. Locale-specific case mapping has the same enumeration problem as S3.**

`CaseLocale is (DefaultLocale | TurkicLocale | LithuanianLocale | AzerbaijaniLocale)`. `SpecialCasing.txt` cross-locale tests want `for L in CaseLocale._all do ...`. Same `_all` recommendation as S3 applies.

**G5. Third-party codec testing responsibility is undocumented.**

`Encoding` is a trait (open). Third parties may implement it. The design should say so explicitly so downstream implementers know they own roundtrip + conformance coverage for their codec.

**G6. `Bytes.first_bad_utf8_offset(s)` contract on valid input is unspecified.**

Tests need to know: does it return `USize.max_value()`? Does it error? Pin this down.

### Minor

**M1.** Iterator one-shot semantics force collect-to-array in tests. Standard Pony pattern; not a design issue.

**M2.** v0.1 tests cannot use normalization to construct test inputs. `GraphemeBreakTest.txt` doesn't require normalization — its inputs are already explicit codepoint sequences. The phasing aligns.

**M3.** Zero-copy regression cannot be tested automatically. §11 T3. Recommendation: benchmark, don't unit-test.

**M4.** `Bytes.is_valid_utf8(s)` and `Bytes.first_bad_utf8_offset(s)` are test-friendly observation primitives.

**M5.** `_scalar`-suffixed predicates have the cleanest PBT shape in the design. One-line agreement property `is_letter_scalar(u) == Codepoint.from_u32(u)?.is_letter()`.

**M6.** `eq_caseless_normalized` is the strongest equality method and deserves the most coverage.

**M7.** Idempotence on `normalize` is one-line property-testable.

**M8.** `decode_total` factories are testable as total functions.

## Passes

- Errors-as-data with concrete primitives + `Stringable`.
- `Index[Kind]` phantom-typed indices.
- `utf8_bytes(): String val` as the canonical observation point.
- Package-private underscore methods are testable from same-package tests.
- `U32`-form predicates plug directly into PonyCheck.
- Closed unions make exhaustive-match tests compile-checked for production code.
- Strict/lossy factory split gives two well-defined behaviors.
- Build-time UCD tables are immutable `val` — no init-ordering hazard.
- `Codepoint` valid/invalid PBT generator triad is straightforward.

## Top recommendations

1. Add a package-private bitmap accessor or known-answer factory (S1).
2. Add `Graphemes._is_break_at(s, byte_offset): Bool` for conformance tests (S2).
3. Generate `_all`-style enumeration arrays for every closed union, in `unicode-build`'s output (S3, G4).
4. Ship `_BadUtf8.at(offset, kind)` test helpers (S4).
5. Add `Text.normal_form(): NormalForm` public accessor (S5).
6. Add `_TextIndex._validate(utf8): (None | _CorruptIndex)` (S6).
7. Expose `ScriptSet.contains(Script)` and/or `.to_array()` (G1).
8. Commit `unicode-build` to its own conformance test suite in §7 (G2).
9. Document third-party codec test responsibility (G5).
10. Specify `Bytes.first_bad_utf8_offset(s)` contract on valid input (G6).
