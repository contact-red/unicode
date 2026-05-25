# Wildcard Evaluation — Pony Unicode Candidate v1

## Findings

### STRUCTURAL

**S1. The premise is "general text processing" — the design is Unicode correctness.**

User asked for general text processing. The design built typed-wrapper machinery (Index[Kind], NormalForm tags, bitmap indexes, dual surfaces, U32-vs-val split, six error vocabularies, ten release tiers). Of the 10 consumer scenarios in §8, only A, C, D, I, K (5) plus half of J are everyday. The §8.C truncate-at-grapheme-N example takes a `match`/`match`/`match` cascade with a marked-unreachable arm — that is heavy ceremony for the most common operation in any text library. Evidence: the v0.1 scenarios that "work" are inspection-heavy; the everyday text-mutation scenarios are either deferred (case-fold in v0.2, words in v0.3) or absent (split, contains, startsWith, indexOf, trim).

Suggested change: surface "is the goal Unicode-correct inspection of immutable text, or general text processing?" — answer changes v0.1 scope materially.

**S2. There is no concept for *building* text — only for inspecting it.**

The v0.1 surface is read-only: count, iterate, slice, query, segment, compare. Missing: streamed/chunked construction (HTTP body assembly, UTF-8 sequences split across packets), editing (insert/delete/replace at index), concatenation at scale (no `TextBuilder`; `t1 + t2 + t3` builds N intermediates), in-place modification (only `Text val` exists; no `Text trn` or `Text ref`). §9 v0.4 mentions "streaming Decoder objects" but only for non-UTF-8 encodings. The candidate frames `Text` as the canonical text type for the ecosystem but provides no write/build/edit primitives. Either narrow the framing or expand the surface.

**S3. Migration path from stdlib `String` is absent.**

A Pony codebase today uses `String`. Every stdlib API takes and returns `String`. The candidate's `Text` stores `_utf8: String val` internally — suggesting `String` remains canonical and `Text` is a wrapper. But the design markets `Text` as "the typed canonical." Round-tripping `Text -> String -> Text` loses the `_form` tag (§5). A library taking `String box` and migrating to `Text val` forces every caller to convert. The design doesn't engage with this.

Suggested change: write a "Migrating from String" section; if too many essentials require v0.2+ (case-insensitive equality), label v0.1 a tech preview.

**S4. "unicode" is the wrong package name.**

The package is `red/unicode`. The star type is `Text`. The user value is text processing; Unicode is the substrate. Compare Rust (`text`, `unicode-segmentation`), Java (`java.text`), Swift (text is `String`). Naming the package "unicode" pulls users who want UCD/confusables; naming it "text" pulls users who want to manipulate text. The name names the problem.

Surface this to the human if the name can still change.

**S5. Unicode-version coupling has a silent-corruption mode nobody mentioned.**

The package pins one Unicode version per release. What does it do with input containing characters from a *newer* Unicode version? UTF-8 doesn't carry a version. `cp.is_letter()`: the table doesn't know the new codepoint. Returns `false`? Then a spam filter classifies a new-Unicode letter as "not a letter." `cp.script()` returns `Script.unknown`? The §8.H mixed-script-attack heuristic fails on a Cyrillic codepoint added in a Unicode version later than the bundled UCD — security consequence. §11 T5 discusses the *package-upgrade* direction but not the *newer-input-meets-older-package* direction.

Suggested change: document the failure mode; consider exposing `cp.is_assigned()` / `Text.contains_unassigned_codepoint()` for security-conscious callers.

### SIGNIFICANT

**S6. T6 and T7 compound to make the "use free functions for hot paths" advice impractical.**

T6: hot loops should use `_scalar`-suffixed predicates. T7: `Normalize.to(s, NFCForm)` returns `String iso^` with no form tag. The compound case: a user chains "normalize, then case-fold, then compare" in a hot loop. Typed path = allocation per `Text`. Free-function path = lost invariant tag, forced re-validation on every step. The two pieces of guidance point in opposite directions. The "compile-enforced same-implementation" claim is true; the *cost calculus* of choosing one surface flips per chain depth.

Suggested change: at least document. Better: provide a mid-level `(String box, NormalForm)` tuple surface so the tag survives free-function chains. Or accept that nontrivial chains belong in `Text` and stop selling free functions as a perf optimization.

**S7. The bitmap index further weakens the case for the wrapper.**

The wrapper now carries three independent pieces of state: validated UTF-8 invariant, `NormalForm` tag, optional bitmap index. Each was justified separately; the combination is heavy. An alternative factoring exists: bitmap-aware grapheme operations live directly on the `Graphemes` primitive (taking `String box` + optional `_TextIndex box`), `Text` goes away, the dual surface collapses to one. The skeptic's stage-1 case was strong; with the index added it gets stronger. Worth a human checkpoint: is `Text` still earning its keep?

**S8. "Position-as-units" — the missing abstraction.**

`ByteIndex`/`CodepointIndex`/`GraphemeIndex` are independent typed offsets. A common need — "I'm at position 5 of 12 graphemes" — has no representation. No `(GraphemeIndex, total)` progress concept. No `TextPosition` that knows "byte 10 = cp 5 = grapheme 4." Conversion functions exist; an abstraction does not. The instinct: a `Cursor` type that lazily caches its byte/cp/grapheme forms would make the design feel coherent. May be gold-plating if editors/parsers are out of scope.

**S9. Pony-specific: where are the actors?**

The candidate is entirely synchronous primitives and value types. Long Unicode operations (normalize a megabyte, generate collation keys, IDNA-process a large registry) block the calling actor for their full duration. The design is silent on async/batch-and-yield/promise patterns. Either deliberate scope or a missed dimension worth a note.

**S11. v0.1 doesn't actually ship for the stated goal.**

Counting §8 consumer scenarios against the v0.1 surface: A (✓), B (v0.2 ✗), C (✓), D (✓), E (v0.3 ✗), F (v0.4 ✗), G (v0.6 ✗), H (v0.3/v0.7 ✗), I (✓), J (half ✓), K (✓). Roughly 5/11 work in v0.1. The design's own canonical user scenarios fail in the first release. The §9 claim "smallest coherent useful slice" is contradicted by the §8 examples.

Suggested change: either expand v0.1 to include case-fold and case-insensitive equality, or be honest that v0.1 is a foundation release and v0.2 is the first user-meaningful one.

**S12. `_scalar` predicates advertise safety they don't enforce.**

`Codepoint.is_letter_scalar(u: U32)` accepts arbitrary `U32`. The name "scalar" implies "valid Unicode scalar value" — that's what scalar means in Unicode. But the function doesn't check. A user doing arithmetic on codepoints (e.g., case-folding's `+0x20` trick) can pass invalid bit patterns. The function will index into the property table at an out-of-range offset. The API name lies.

Suggested change: rename to `is_letter_u32` or `is_letter_unchecked` to make the unsafe nature visible, or have them check `is_scalar(u)` first.

**S17. Pony-language correctness bug: errors-as-primitives can't carry fields.**

§6 declares `primitive _InvalidUtf8At` with `let offset: USize`, `primitive _Surrogate` with `let value: U32`, `primitive _OutOfRange` with `let value: U32`. **Pony primitives are stateless singletons. They cannot have instance fields.** These declarations will not compile. The error types that carry contextual data must be `class val`, not `primitive`. Several places in the candidate make this mistake (the §1 table calls them "all primitives or small class vals" but the §6 implementation has them as primitives with state).

Fix: change `primitive _InvalidUtf8At` (etc.) to `class val _InvalidUtf8At`. The `OutOfRange`, `DecodeError`, `EncodeError`, `LocaleError` declarations are correctly `class val` — only the smaller ones are mis-declared.

### MINOR

**S10.** `from_string_lossy` substitutes per W3C maximal-subpart but gives no caller-visible feedback (count of substitutions, locations). Users can detect-then-decode by combining `Bytes.is_valid_utf8` first. Documentation-only.

**S13.** `decode_total` is "convention, not separate trait." Polymorphic code can't dispatch on it. Fine for monomorphic call sites; weaker than it sounds.

**S14.** `cp.name()` returns `NoName` both when the codepoint is genuinely unnamed *and* when the names subpackage isn't imported — conflating two distinct conditions.

**S15.** `Codepoint.from_u32_or_replacement` returns U+FFFD on invalid input with no audit trail. A `Codepoint val` from this factory is indistinguishable from any other.

**S16.** `ScriptSet.resolved()` is the security-relevant form. Naive `t.scripts()` includes Common/Inherited and "abc123" gets flagged as multi-script. The API exposes the footgun; the default should arguably be the resolved form and unresolved should be explicit.

## Passes

- `Index[Kind]` is genuinely strong; couldn't break it.
- Errors-as-data with per-layer disjoint primitives is clean (modulo S17).
- `_form: UnknownForm` default beats fail-soft NFC assumption.
- Build-time UCD generation with version-pinning is right.
- Closed unions for `Script`/`Category`/`Property` — right call despite the T5 source-compat cost.
- The split-path codepoint resolution (U32 in hot loops, `Codepoint val` at boundaries) is the right shape; S12 is a naming issue, not a refutation.

## Uncertainties

**U1.** The "two surfaces, one implementation" cannot-drift claim is true at the *function-call* level but not at the *precondition* level. Pony has no way to express the underscore-method's precondition; if it has any precondition beyond "valid UTF-8," validating-caller and `Text`-caller could fall out of sync.

**U2.** The dual surface obscures benchmarking — for any operation, perf depends on call pattern.

**U3.** The "indexed=true is free if you do any grapheme op" claim from §3.5 is technically right but the *decision* is hard at construction time without knowing the downstream pipeline.

**U4.** The design mixes "make Unicode correct" and "make Pony stylish." When they disagree, the design picks Pony. Probably right but worth a checkpoint with the human.

**U5.** v1.0 "API freeze" misaligns with Unicode's annual rate of change. v1.0 is a *moving* stable surface — the closed-union breaks per T5 are part of the stable design. Worth flagging because "stable library" usually implies zero breaks.

## Hand-off note for synthesizer

If only three changes happen:
1. Decide: package is "Unicode" or "Text" — name + framing + v0.1 scope all shift.
2. Reconcile S6 — dual-surface advice contradicts itself for chained operations.
3. S17 — fix the `primitive` → `class val` declarations in §6 before the design becomes the basis for implementation.
