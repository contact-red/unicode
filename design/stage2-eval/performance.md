# Performance Evaluation — Pony Unicode Candidate v1

**Method note on T3**: `String val.trim()` returns `String iso^` — Pony stdlib pattern. The String wrapper struct (ptr + size + alloc + cap) is **always** a new allocation, even when the underlying byte buffer is shared. pony-ref documents `Array[U8] val.trim()` zero-copy but does NOT make the same claim for `String val.trim()`. Findings below treat T3 as open.

## Findings (ordered by impact)

### 1. T3 is structural, not merely empirical — and the design buries it (Structural)

§4.3, §3.5, §10 #2, §11 T3 all rest on "graphemes are zero-copy `String val` slices, no per-element heap alloc." Pony stdlib `String.trim(from, to)` returns `String iso^`. Even in the best case the iterator costs one small struct alloc per yielded grapheme (~32 bytes). For a 1 MB grapheme walk: millions of small allocs. In the worst case (if `String.trim` on `val` actually copies bytes), each grapheme is an O(cluster_size) byte copy and the design is broken for any realistic text size.

Impact: inverts headline claims in §4.3 ("no allocation overhead per cluster") and §10 #2.

Suggested change:
- Drop "no per-element heap allocation" language; replace with "zero byte-copy; one small struct alloc per yielded slice."
- Promote T3 from "verify before v0.1 implementation" to **gating decision before v0.1 design freeze**. T2 RESOLVED ("graphemes are String val slices, no Grapheme class") is partly justified by "no allocation overhead per cluster." If T3 goes wrong, T2 needs re-opening.
- Spec the iterator to leave room for an additive `Text.grapheme_ranges()` returning `Iterator[(ByteIndex, ByteIndex)]` for callers that materialize on demand. Cost: one extra method per segmenter; benefit: the design survives T3 going the wrong way.

### 2. Index propagation default may multiply pipeline cost (Significant)

§3, §3.5. Operations returning a derived `Text` (`slice_graphemes`, `+`, `to_lower`, …) **inherit** the parent's index status — each derived `Text` rebuilds the bitmap during construction.

Pipeline `t.to_lower().to_upper().normalize(NFCForm)` on an indexed 1 MB Text pays 3 extra O(n) walks beyond the 3 the operations themselves do. Doubles the cost of the common pipeline.

Suggested change: invert the default — **derived ops do NOT inherit the index**. Caller calls `.indexed()` on the result if they want it. Aligns with principle 1 (explicit over implicit) and principle 13 (easier to give than take away).

### 3. `codepoints()` / `codepoint_scalars()` naming sets the slow path as default (Significant)

§4.2, T6. Auto-complete on `t.code` surfaces `codepoints()` first (alphabetical); `codepoints()` yields `Codepoint val` — one heap alloc per element. Users following auto-complete land on the slow path.

The candidate justifies the typed form as default on type-safety grounds. But: inside the package, both `Codepoint val` and `U32` carry the same invariant (they're scalars from a validated `Text`). The only real benefit of the typed form over `U32` is **method discoverability** (`cp.is_letter()` vs `Codepoint.is_letter_scalar(u)`) — that's auto-complete ergonomics, not safety. So the per-element-alloc default buys auto-complete on the dot, which is a poor trade.

Suggested change: swap names. `codepoints()` yields `U32` (cheap, default). `codepoints_typed()` (or `codepoint_values()`) yields `Codepoint val` (explicit "I want the typed form").

### 4. Bitmap index complexity is misleading in the type-surface table (Significant)

§3 lists `grapheme_at`: `indexed: O(n/64); else O(n)`. Both are O(n) — the `/64` is a 64× constant-factor speedup, same asymptotic class. Reading "O(n/64) vs O(n)" implies different complexity classes.

The candidate is honest in §3.5 prose ("not true O(1)") but the type-surface table hides it. For long indexed texts, callers will assume O(1) random access and write O(n²) algorithms over them.

Suggested change: restate complexity in the table as "O(n), 64× faster than unindexed" or commit to rank/select before v0.1 design freeze.

### 5. `from_string_lossy(s, indexed = true)` is two-pass, not single-pass (Significant)

§3.5 claims construction is "one O(n) walk." For `from_string_lossy`, the implementation must:
1. Walk bytes producing a well-formed buffer (substituting U+FFFD for ill-formed sequences) — O(n).
2. Index the well-formed buffer with UAX #29 — O(n).

These cannot be fused because step 2's UAX #29 state machine operates on codepoints, and the codepoint sequence is what step 1 is constructing. Strict-construction can be single-pass (validate-then-index fused).

Suggested change: §3.5 should distinguish: strict construction single-pass; lossy construction two-pass.

### 6. Local-bitmap iteration on non-indexed Text loses for short prefixes (Significant)

§3.5: "`text.graphemes()` internally builds a local grapheme-start bitmap once during iteration construction and walks it."

For full iteration of a long text: bitmap-build cost ≈ state-machine-iteration cost; bitmap then allocates n/8 extra bytes. For partial iteration (`t.graphemes().next()`): bitmap is O(n) (build cost); state machine is O(1).

Common pattern is "take the first few graphemes and stop" (truncation, prefix checks). Bitmap default penalizes this case.

Suggested change: state-machine by default for non-indexed Text; reserve local-bitmap behavior for `indexed()`-materialized Text. Or: lazy bitmap-build during iteration (only fill the part actually visited).

### 7. `has_property(p)` dispatch may pay match cost per call (Significant)

§4.1. If `cp.has_property(p)` is implemented as `match p | Property.alphabetic => alphabetic_table.lookup(u) | ...`, every call pays one match-arm comparison per property checked. For ~30 binary properties, in tight loops, this is non-trivial constant overhead.

Suggested change: store all binary properties in a single bitmap (one bit per tracked property) at the codepoint level. UCD table stage-2 entries hold the bitmap; `has_property(p)` becomes one bit-test on the looked-up value, no match dispatch.

### 8. "Zero-copy" terminology is too loose in §10 #9 (Minor)

§1, §10 #9. `Text.from_utf8_iso(consume bytes)` is "capability-aware adoption" — but the prose says "no copying." The String wrapper struct is allocated. Zero **byte-copy** is accurate; zero-copy is loose.

Suggested change: tighten language to "zero byte-copy; small allocation for the String/Text wrapper."

### 9. `is_normalized` prose suggests per-codepoint iteration (Minor)

§5: "Cheap via UAX #15 quick-check, early-terminates on ASCII." Could be read as "iterates codepoints, returns early once ASCII detected." The right thing is a SIMD byte scan for `b >= 0x80` first (rejects pure-ASCII immediately in O(n/16) with SSE2 or O(n/32) with AVX2), falling back to per-codepoint UAX #15 only if any non-ASCII byte exists.

### 10. UCD radix locality is fine, but stage sizes are unspecified (Minor)

§7 says "two-stage radix tables" without committing to stage split. Cache behavior depends on stage-1 fitting in L1.

Suggested change: commit to specific stage sizes (e.g., 8-bit / 13-bit split) in §7 so generated code is predictable.

### 11. Closed-union match dispatch on `Script` (~165 primitives) is fine — concern was misframed

`match cp.script() | Script.latin => ... | Script.cyrillic => ...` compiles to a series of type-descriptor pointer comparisons, one per arm. Cost is **O(arms checked)**, not O(union size). No structural perf concern here.

### 12. Iterator capability story is implicit (Minor)

§4.2 doesn't state iterator capabilities. Pony `Iterator[T]` is typically `ref` over the parent's data. For `Text val` shared across actors, each actor's iterator instance is independent. No coordination needed.

Suggested change: one sentence in §4.2 confirming "iterators are `ref`; multiple actors holding the same `Text val` iterate independently with no shared state."

## Passes

1. UTF-8 internal storage. Zero byte-copy adoption from `String val`, zero re-encoding on `utf8_bytes()` out. Correct default.
2. Split codepoint iteration (U32 + Codepoint val). Hot paths avoid per-element alloc (modulo finding #3's name swap).
3. Storage of codepoint sequences as `U32`. §4.3 prevents the worst footgun.
4. Graphemes as `String val` slices, no Grapheme class. Right structural choice modulo T3.
5. Opt-in bitmap index, not always-on. Pass-through workloads pay nothing.
6. Build-time UCD generation, compiled-in `val` tables. No runtime parse cost; tables sit in `.rodata`, shareable across actors with no GC overhead.
7. Closed unions instead of stringy enums. Avoids hash/string-compare for Category/Script/Property dispatch.
8. `Text` skips re-validation. Logic-in-primitives pattern (§2) lets typed-path methods skip the validation gate.
9. `Text.from_utf8_iso(consume bytes)`. Zero byte-copy adoption via Pony iso/val conversion.
10. No global state for collation/normalization/locale. No cache invalidation, no synchronization, no hidden costs.
11. `U32`-suffixed predicates in `Codepoint` primitive. Allows hot loops to bypass wrapper alloc.
12. Actor-shareable design. `Text val` and `val` UCD tables shareable across actors with zero coordination.

## Uncertainties

1. `String val.trim` actual behavior — finding #1 is gated on this; T3 should be resolved before v0.1 design freeze.
2. ponyc's match-on-primitive-union emission strategy — described as "linear in arms checked" based on Pony semantics; not verified from compiler source.
3. LLVM inlining through the `Text → Topical → _Cursor` call chain — asserted based on monomorphic primitive dispatch; verify via LLVM IR during implementation.
4. `String.from_iso_array` zero-byte-copy — confirmed idiomatically; wrapper allocation cost is "small constant."
5. UCD radix stage sizes — candidate says "compressed several hundred KB to ~5 MB" without specific stage split.
6. Bitmap-build vs state-machine iteration tradeoff — finding #6's break-even analysis is approximate.
