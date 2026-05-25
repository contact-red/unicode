# Stage 2 Synthesis

Five evaluators (security, performance, adversarial, testability, wildcard) reviewed the candidate at `candidate-v1.md`. This synthesis categorizes each finding as **Rejection** (invalidates the design direction), **Adjustment** (concrete fix within the direction), or **Tension** (requires human judgment).

**Headline**: No rejections. ~30 adjustments. ~6 tensions including one premise-level question.

## Convergence check

- Same concern appearing across iterations: no — Stage 2 is the first evaluation pass.
- Rejections contradicting adjustments: no rejections.
- Design growing more complex: yes, somewhat — wildcard S7 calls this out (bitmap + `_form` + UTF-8 invariant on the wrapper is heavy in combination). Treated as Tension below.

## Tensions (require human judgment)

### TN-A. Premise: "general text processing" vs "Unicode correctness"  
**Source**: Wildcard S1, S11.  
**The question**: User asked for "general text processing." The design built Unicode-correctness machinery (typed wrappers, NormalForm tags, phantom indices, dual surfaces, bitmap indices, 6 error vocabularies, 10 release tiers). Only ~5/11 §8 consumer scenarios actually work in v0.1. The everyday text-mutation surface (`split`, `contains`, `startsWith`, `indexOf`, `trim`, builders/editors) is missing or deferred.  
**The fork**:
- (a) Treat current design as the right answer for "Unicode-correct inspection of immutable text" — but be honest that's not "general text processing"; rename framing; ship v0.1 as a foundation/preview release.
- (b) Reshape the package toward general text processing — expand v0.1 to include the everyday-mutation surface (with naive UTF-8 implementations that get refined later), defer the heaviest correctness machinery (Index[Kind] generic, bitmap index) to opt-in advanced surface.
- (c) Split: ship two packages — `text` (general processing, ergonomic) and `unicode` (correctness primitives, opt-in for `text` users who need them).

### TN-B. Wrapper vs no-wrapper, revisited  
**Source**: Wildcard S7.  
**The question**: The `Text val` wrapper now carries 3 independent pieces of state (validated UTF-8, `NormalForm` tag, optional bitmap index). The skeptic's Stage 1 argument was strong; the bitmap addition makes it stronger. An alternative: fold everything into the topical primitives (`Graphemes`, `Codepoints`, etc.) operating on `String box` + optional `_TextIndex box`. `Text` goes away; the dual surface collapses to one.  
**The fork**:
- (a) Keep `Text` (current). Accept the combinatorial state space.
- (b) Drop `Text`. Topical primitives + free `_TextIndex val` carry everything.
- (c) Keep `Text` but make it dumber — just validated UTF-8 + index. Drop the `_form` tag (see TN-D).

### TN-C. v0.1 ships? Five of eleven §8 scenarios work in v0.1.  
**Source**: Wildcard S11; reinforced by Adversarial S1 (v0.1 ships `eq_codepoints` which encourages unsafe username comparison).  
**The fork**:
- (a) Expand v0.1 to include normalization + case-fold + `eq_caseless_normalized`. Effectively merges v0.1+v0.2. v0.1 takes longer but is shippable.
- (b) Rename v0.1 → "tech preview"; document that v0.2 is the first user-meaningful release.
- (c) Keep current staging; tighten the framing so the staged primitives carry warning labels for security-relevant uses (compose with TN-D).

### TN-D. Identifier matching primitive is unsafe with current framing  
**Source**: Security F1 (Structural); Adversarial S1; Security F4.  
**The question**: `eq_caseless_normalized` is described as "the identifier-matching default." But it defaults to NFC (UTS #39 / RFC 8264 require **NFKC**) and lacks confusables (deferred to v0.7). Anyone following the design's own recommendation through v0.1–v0.6 ships a vulnerable system. This is a documented Unicode security pitfall.  
**The fork**:
- (a) Stop calling it "the identifier-matching default." Reframe as "display equality" (case+normalize aware, but not identifier-safe).
- (b) Add `eq_identifier(other, profile: IdentifierProfile)` gated on v0.7 — fail-closed before that. Force callers to confront the choice.
- (c) Default to NFKC for `eq_caseless_normalized` (still not safe without confusables, but closer to what users want).

The user's earlier guidance ("compare two usernames case-insensitively after normalization") makes this directly load-bearing.

### TN-E. Dual-surface advice is internally contradictory for chained operations  
**Source**: Wildcard S6.  
**The question**: T6 says hot loops should use `_scalar`-suffixed predicates (free-function path). T7 says free-function results drop the `_form` tag. So a "normalize → case-fold → compare" chain in a hot loop: typed path = alloc per Text; free-function path = lose invariant, re-validate every step. The two pieces of advice point opposite ways.  
**The fork**:
- (a) Provide a mid-level tuple form `(String box, NormalForm)` so the tag survives free-function chains.
- (b) Accept that nontrivial chains belong in `Text`; stop selling free functions as a perf optimization.
- (c) Resolved naturally if TN-B picks "drop Text" (one surface, problem dissolves).

### TN-F. T3: `String val.trim` zero-copy assumption  
**Source**: Stage 1 T3; reinforced by Performance #1 and Adversarial G6.  
**The question**: The grapheme/word/sentence/line iteration story depends on `String val.trim` being zero-copy or near-zero-copy. If `String.trim` always allocates a new wrapper struct (~32 bytes), iterators pay one small alloc per yielded slice — millions of allocs on a 1 MB text. If `String.trim` copies bytes on `val`, the design is broken for any realistic text size.  
**Promoted from "verify before implementation" to "gating decision before design freeze."**  
**The fork**:
- (a) Verify empirically; design stands if zero-byte-copy.
- (b) Define fallback now: iterators yield `_GraphemeSpan val { start: USize; end: USize }` pairs; callers materialize on demand. Decouples design from stdlib assumption.

### TN-G. Other questions surfaced but lower-stakes
- **TN-G1** Package name `unicode` vs `text` (Wildcard S4)  
- **TN-G2** Editing/building text scope (Wildcard S2)  
- **TN-G3** Position-as-units / `Cursor` abstraction (Wildcard S8)  
- **TN-G4** Newer-Unicode-input meets older-package silent-corruption (Wildcard S5)  
- **TN-G5** Closed `Script` union vs Unicode version bumps (Stage 1 T5)  

## Adjustments (apply within current direction)

### Adj-1: Fix `primitive` → `class val` for stateful error types (Wildcard S17, Structural)
**Concrete code-correctness bug.** `primitive _InvalidUtf8At { let offset: USize }`, `primitive _Surrogate { let value: U32 }`, `primitive _OutOfRange { let value: U32 }` — Pony primitives are stateless singletons; these will not compile. Change to `class val`. Trivial fix.

### Adj-2: Index[Kind] needs a non-bypassable constructor (Adversarial S4, Structural)
Bare `USize` public constructor lets users write `GraphemeIndex(byte_offset)`, defeating the type-safety claim. Fix: make `Index[Kind].create(n: USize)` package-private; expose `t.byte_index(n)?`, `t.codepoint_index(n)?`, `t.grapheme_index(n)?` as the public construction route (each tied to a Text for range-check).

### Adj-3: Add `Text.normal_form(): NormalForm` public accessor (Testability S5)
`_form` is type-private in Pony; tests outside `Text` can't read it. Tests want this for asserting normalization correctness.

### Adj-4: `_form` may only be set to non-Unknown by `normalize()` (Adversarial S3)
Restructure: public constructors all set `_form = UnknownForm`; only `normalize(f)` produces a Text tagged `f`. Compile-enforceable via a package-private `_with_form` used only by `normalize`. Removes the "producer-claims, no validator" silent-equality-drift class of bug.

### Adj-5: Drop `from_u32_or_replacement` from public surface (Adversarial S2, Security F8)
Force explicit `match Codepoint.from_u32(u) | InvalidScalar => Codepoint.replacement end`. Substitution belongs in decoders, not unary U32 lifts.

### Adj-6: `from_string_lossy` surfaces substitution (Adversarial G1, Security F3)
Return `(Text val, USize)` with substitution count, OR add `t.substitution_count(): USize`, OR rename `from_string_with_replacement`. Either makes "did substitution happen" recoverable.

### Adj-7: Drop or isolate `IgnorePolicy` (Security F2)
Known anti-pattern. Drop entirely or rename `DropInvalidPolicy` and isolate behind a separate `decode_dropping(...)` factory.

### Adj-8: `EncodeError.codepoint` redaction (Security F5)
Currently leaks one codepoint of input on encode failure. Either replace with `offset: USize` (caller reads from input) or make `string()` redacted by default with explicit `unsafe_string_with_codepoint()`.

### Adj-9: Document resource-bound expansion (Security F6)
NFKD up to ~18×; case mapping expands; combining-mark storms unbounded. Add §11 tension; consider `normalize_bounded(form, max_output_bytes)` for v0.2.

### Adj-10: Index propagation default should be "do NOT inherit" (Performance #2)
Derived ops (`slice_graphemes`, `+`, `to_lower`, …) should NOT inherit the index by default. Caller calls `.indexed()` on the result. Inverts current default; saves index-rebuild cost in pipelines.

### Adj-11: Swap `codepoints()` / `codepoint_scalars()` naming (Performance #3)
Default name surfaces first in auto-complete and should be the cheap path. `codepoints()` → yields `U32` (cheap). `codepoints_typed()` → yields `Codepoint val` (explicit "I want the typed form").

### Adj-12: Fix complexity table to not imply different big-O classes (Performance #4)
"indexed: O(n/64); else O(n)" implies different complexity classes. They're both O(n) with constant-factor difference. Restate as "O(n), 64× faster than unindexed" or commit to rank/select.

### Adj-13: Single-pass-vs-two-pass note on `from_string_lossy(_, indexed = true)` (Performance #5)
Document that strict + indexed is one pass; lossy + indexed is two.

### Adj-14: State-machine default for non-indexed iteration; local-bitmap only on demand (Performance #6)
Local-bitmap-during-iteration penalizes short-prefix patterns (truncate-to-N). State-machine is O(1) per-element from the start.

### Adj-15: Combined bitmap for binary properties (Performance #7)
`has_property(p)` should not match-dispatch per call. Pack all binary properties into a single per-codepoint bitmap; `has_property(p)` is one bit-test.

### Adj-16: `_scalar` predicates are unsafe — rename or check (Wildcard S12)
`Codepoint.is_letter_scalar(u: U32)` accepts arbitrary U32 (no scalar check). Either rename `is_letter_unchecked` to flag the unsafe nature, or have them `is_scalar`-check first (cheap).

### Adj-17: `Scripts.restrict_to(t, allowed)` for v0.3 (Adversarial G4)
Single-script-confusable attacks (pure-Cyrillic spoofing Latin) pass the existing `scripts > 1` check. Add a positive-allowlist primitive in v0.3 alongside `Scripts.of`. Doesn't replace v0.7 confusables; covers the most common case earlier.

### Adj-18: Define `_form` propagation per operation (Adversarial G7)
Concrete table: `normalize(f)` → `f`; `slice_graphemes` preserves; `slice_codepoints` → Unknown; `+` → Unknown; `to_lower/upper/title` → Unknown.

### Adj-19: Truncation at grapheme N has unbounded byte-size output (Adversarial G2)
Add `truncate_to_byte_budget(t, max_bytes)`. Document that grapheme-count limits ≠ byte-budget limits.

### Adj-20: `slice_codepoints` should not inherit index (Adversarial G3)
Cuts may fall mid-grapheme; inherited index becomes wrong. `slice_codepoints` always returns `_index = None`; `slice_graphemes` may inherit (cuts are guaranteed grapheme-aligned).

### Adj-21: Bytes.first_bad_utf8_offset return for valid input (Security F13, Testability G6)
Spec as `(USize | AllValid)`.

### Adj-22: ScriptSet.contains(Script) accessor (Testability G1)
Tests need exact-contents assertions; current API only exposes `.size()`.

### Adj-23: Generate `_all` enumeration arrays for closed unions (Testability S3, G4)
`Script._all: Array[Script] val`, `Category._all`, `CaseLocale._all`, etc. — emitted by `unicode-build` alongside the variants. Eliminates test-side enumeration drift.

### Adj-24: Test-helper invalid-UTF-8 generators (Testability S4)
Add `_BadUtf8.at(offset, kind)` factories so tests can assert `_InvalidUtf8At(offset = N)` exactly.

### Adj-25: Package-private bitmap observability for tests (Testability S1, S6)
Add `_TextIndex._for_test_only(): _BitVec val` and/or `_TextIndex.from_explicit_breaks(starts)` factory so conformance tests can verify against UCD's answer key.

### Adj-26: Add `Graphemes._is_break_at(s, byte_offset): Bool` for conformance tests (Testability S2)
Conformance suite consumes byte-offset breaks; needs a primitive at that grain.

### Adj-27: Iterator capability statement in §4.2 (Performance #12)
One sentence: "Iterators are `ref`; multiple actors holding the same `Text val` iterate independently with no shared state."

### Adj-28: Expose `is_assigned()` and document newer-Unicode-input silent corruption (Wildcard S5)
A user processing input from a newer Unicode version than the package supports gets silent misclassification (new letters classified as non-letters; security heuristics fail). Add `cp.is_assigned()` and `Text.contains_unassigned_codepoint()`.

### Adj-29: `cp.name()` returns distinct values for "no name" vs "names package not loaded" (Wildcard S14)
Currently both → `NoName`. Should be distinct variants.

### Adj-30: Migration-from-`String` documentation (Wildcard S3)
Write a "Migrating from String" section. If too few v0.1 use-cases work without v0.2 (likely; see TN-C), label v0.1 a tech preview.

## Passes (cross-evaluator agreement that these design moves are right)

- Errors-as-data with closed-union primitives (compile-enforced exhaustive matching)
- Phantom-typed indices (correctness mechanism, subject to Adj-2)
- Strict-by-default factories
- Capability discipline (all public types val, no FFI, no actor smuggling, UCD tables val)
- Build-time UCD generation, version-pinned
- `_form: UnknownForm` default (no silent normalization)
- Closed unions instead of stringy enums for Script/Category/Property
- UTF-8 internal storage (zero byte-copy from/to Pony `String`)
- Storage of codepoint sequences as `U32`, never `Array[Codepoint val]`
- Opt-in bitmap index (pass-through workloads pay nothing)
- Split codepoint iteration (U32 + Codepoint val), modulo naming swap

## Recommendation

**Stop and surface to the human before iterating** — for these reasons:

1. **Premise question (TN-A)** can only be answered by the user. Determines v0.1 scope, possibly the entire package shape.
2. **Several tensions are scope/architecture forks** the user is best placed to call (TN-B, TN-C, TN-D, TN-E, TN-G1, TN-G2).
3. **Adjustments compound**: applying all 30 mechanical fixes is straightforward but ~30 changes is a substantial revision. Better to align on direction first.
4. **One concrete code-correctness bug** (Adj-1: primitive-with-fields) should be fixed regardless.

If the user steers on the tensions, the next loop iteration applies all adjustments in one pass with the chosen direction baked in.
