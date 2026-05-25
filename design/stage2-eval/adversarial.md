# Adversarial Evaluation — Pony Unicode candidate v1

## Findings

### STRUCTURAL

**S1. Username uniqueness check reachable without normalization (v0.1 release window).**

```pony
let t = (Text.from_string(input) as Text val)?
for existing in stored.values() do
  if t.eq_codepoints(existing) then return false end
end
true
```

Input pair: stored `"café"` as NFD (e + U+0301), input `"café"` as NFC (U+00E9). Byte-distinct, codepoint-distinct, visually identical.

Expected: collision detected. Actual: silent acceptance (account spoofing).

Why legitimate: §9 release table puts `eq_codepoints` in v0.1, `eq_normalized` and `eq_caseless_normalized` in v0.2. v0.1 ships *with* `eq_codepoints` as its only equality. Any team that adopts v0.1 has no correct identifier-comparison primitive.

Impact: security; account spoofing on every pre-v0.2 deployment.

Suggested change: v0.1 ships `eq_normalized` (NFC normalization is the smaller v0.2 piece), or v0.1 ships no string-equality primitive at all. Shipping `eq_codepoints` without normalization is the worst of both worlds — looks usable, is wrong.

Evidence: §9 v0.1 vs v0.2 row; §8 sketch B uses v0.2-only primitive.

---

**S2. `Codepoint.from_u32_or_replacement` launders attacker-chosen invalid scalars.**

```pony
let cp = Codepoint.from_u32_or_replacement(raw_u32)
if cp.is_letter() then accept(raw_u32) else if cp.script() == Script.han then han_path() end end
```

Inputs: `raw_u32 = 0xD800` (surrogate), `raw_u32 = 0x11_0000` (out of range) — both substitute to U+FFFD; `is_letter()` false, `script()` Common. Downstream policy operates on U+FFFD's properties, not the attacker-chosen value.

Expected: a path the caller must acknowledge for invalid input. Actual: total constructor + property accessors lie about the original value.

Why legitimate: `from_u32_or_replacement` is named the way Pony names total variants (analogue of `from_string_lossy`). Callers reaching for it are following the package's naming convention.

Impact: confused-deputy; protocols that legitimately carry U+FFFD as content can't distinguish content from substitution.

Suggested change: drop `from_u32_or_replacement` from the public surface. Force the caller to write `match Codepoint.from_u32(u) | InvalidScalar => Codepoint.replacement end` so the substitution choice is explicit at the call site. Substitution belongs to *decoders* (where ill-formed UTF-8 produces FFFD per maximal-subpart), not to a unary U32 lift.

Evidence: §4.1 surface.

---

**S3. `Text._form` is a producer-set claim with no validation function.**

The design has multiple constructors (`from_string`, `from_string_lossy`, `from_utf8_bytes`, `from_utf8_iso`, `from_codepoint_scalars`, `from_codepoint`, `decode`). Each sets `_form`. `Text.from_string` sets `UnknownForm`; `normalize(f)` sets `f`. Any future maintainer who adds a constructor — e.g., `Text.from_normalized_source(s)` that trusts an upstream "already normalized" claim — sets `_form` to whatever the producer says. The same field is read by `Compare.eq_normalized` to short-circuit.

Concrete failure: an upstream service claims NFC but does NFKC. A new `Text.from_normalized_source` constructor stamps `_form = NFCForm`. Downstream `eq_normalized(a, b, NFCForm)` sees both tagged NFCForm, skips re-normalization (§5 idempotency: "`normalize(t._form)` short-circuits"). Strings that compare equal under NFKC but unequal under NFC are returned as equal.

Expected: type system distinguishes "validated NFC" from "claimed NFC." Actual: a single field; no validator.

Why legitimate: §2 itself says Text methods *skip re-validation* because the invariant "is already carried." That logic applies to UTF-8 well-formedness (exactly one entry point validates: `Bytes.is_valid_utf8`). It is presented identically for `_form` — but `_form` has no analogous validation function. The asymmetry is invisible from the surface.

Impact: silent breakage of every downstream equality check whenever a constructor mis-tags.

Suggested change: enforce structurally that `_form != UnknownForm` is producible only by `normalize(f)`. Either (a) `_form` is computed lazily by `is_normalized(form)` and never stored as a stamp, or (b) constructors are forbidden from setting `_form` to anything but `UnknownForm` (compile-enforceable by giving them a no-form constructor and reserving the with-form variant to a package-private `_with_form` used only by `normalize`).

Evidence: §1 type table, §5 strategy. The asymmetry with UTF-8 invariant is unstated.

---

**S4. `Index[Kind]` is type-safe at types but not at values — bare `USize` constructor lets the caller lie about the unit.**

Constructor in §3: `new val create(value: USize)` is public.

```pony
let s: Span[ByteIndex] = tokenizer.next()?
let cluster = t.grapheme_at(GraphemeIndex(s.start.value()))   // wrong unit, compiles, runs
```

A user reads a *byte* offset from a protocol message (tokenizer output, error report, regex match span), needs a grapheme there, and writes `GraphemeIndex(byte_offset)`. No compile error. The function returns the wrong cluster.

Expected per §10 #5: compile-time prevention of unit confusion. Actual: prevention only when the *caller has already tagged correctly* — exactly the case where there's nothing to confuse.

Why legitimate: §10 #5 advertises "compile-time index discrimination" as a Raku improvement. The §3.5 footgun example shows the *good* case (raw 7 rejected). The bad case (byte offset 7 stuffed into `GraphemeIndex(7)`) is not shown and not prevented.

Impact: the design's central correctness mechanism delivers less than advertised.

Suggested change:
1. Make the bare-USize constructor package-private.
2. Public construction goes through `t.byte_index(n)?`, `t.codepoint_index(n)?`, `t.grapheme_index(n)?` — each tied to a `Text` (which lets the constructor range-check) and each named with the unit it stamps. Conversion between kinds is already in §3 (`byte_index_of_grapheme`, etc.). The only missing piece is the *first* construction from a raw integer.

Evidence: §3 `Index` definition; §10 #5.

### SIGNIFICANT

**G1. `from_string_lossy` collapses ill-formed bytes and content-U+FFFD into the same byte sequence.**

```pony
let t1 = Text.from_string_lossy(line_A)
let t2 = Text.from_string_lossy(line_B)
if t1.eq_codepoints(t2) then merge(t1, t2) end
```

Input A: `"user logged in: \xC3\x28"` (ill-formed UTF-8: `\xC3` lead with `\x28` non-continuation). Lossy produces `"user logged in: �("`.
Input B: `"user logged in: \xEF\xBF\xBD("` (well-formed UTF-8 of literal U+FFFD followed by `(`). Lossy passes through unchanged.

Result: byte-identical. Different sources merged.

Security variation: attacker submits username bytes that decode lossy to an existing user's name + FFFD. Stored copy contains FFFD. Login uses same bytes, same lossy path, same identity. Authentication boundary crossed.

Suggested change: `from_string_lossy` returns `(Text val, USize)` where the second element is the substitution count, or `Text` exposes `t.substitution_count()`. Either makes "did substitution happen" recoverable.

---

**G2. `truncate(name, max_graphemes)` produces output whose byte size is unbounded.**

Code: §8 sketch C verbatim.
Input: `s = "👨‍👩‍👧‍👦 family update"`, `max = 1`. First grapheme is family ZWJ sequence — 4 codepoints, **25 UTF-8 bytes**.
Downstream: `cut.utf8_bytes().size() <= 20` rejects the "truncated" output; or a 20-byte database column truncates mid-grapheme on insert, breaking the cluster the grapheme-aware slice was designed to preserve.

Suggested change: provide `truncate_to_byte_budget(t, max_bytes): (Text val | OutOfRange)` that finds the largest grapheme-aligned prefix fitting `max_bytes`. Document that grapheme-count limits and byte-budget limits are different problems.

---

**G3. Slicing may inherit a parent index whose grapheme boundaries don't match the slice.**

§3.5 says "inherits the parent's index status … rebuilds the index for the new bytes." Both clauses can't be true: inheritance preserves the parent's bitmap; rebuilding is fresh UAX #29. If the implementation aliases the parent's bitmap clipped to the slice's byte range, then `slice_codepoints` (which can cut between graphemes) yields a Text whose `size_graphemes()` counts bits over a range whose endpoints aren't grapheme boundaries — wrong count, and `grapheme_at(0)` returns a parent grapheme that may extend behind the slice's start byte.

Suggested change: `slice_codepoints` returns `_index = None` regardless of input. Callers re-index explicitly. `slice_graphemes` may inherit because its cuts are guaranteed grapheme-aligned.

---

**G4. Mixed-script check passes for single-script attacks against a single-script context.**

§8 sketch H: `t.scripts().resolved().size() > 1`.
Input: `"раура"` (all Cyrillic). `scripts().resolved() == {Cyrillic}`, size == 1, not flagged. Visually identical to a Latin "paypa". A Western-Latin context expecting Latin-only identifiers accepts the Cyrillic-only spoof.

Suggested change: ship `Scripts.restrict_to(t, allowed: ScriptSet)` in v0.3 alongside `Scripts.of`. A Latin-context site checks `restrict_to(t, ScriptSet.latin_only())` and catches Cyrillic-only attacks without v0.7 confusables. Alternatively, clarify the doc: mixed-script ≠ confusable; single-script attacks defer to v0.7.

---

**G5. Composition trap: callers forced to pick an invalid-scalar policy in helper functions; "let it through, validation happens elsewhere" is a backdoor.**

```pony
fun is_letter_or_compatible(u: U32): Bool =>
  match Codepoint.from_u32(u)
  | let cp: Codepoint val => cp.is_letter() or cp.is_digit()
  | let _: InvalidScalar => true   // ← seemingly defensible
  end
```

The union *forces* a policy choice. A reasonable developer who thinks "the strict path validates upstream, this helper shouldn't double-reject" picks `true` and creates an injection point.

Chain is weaker than other findings: requires the developer to write that specific helper that specific way. But the type system *forces* the dichotomy; the wrong branch is reachable without code smell.

Suggested change: doc-level. The codepoint section needs a "predicate composition" caution with the worked example.

---

**G6. T3 zero-copy assumption is load-bearing for the iteration story but unverified.**

If stdlib `String val.trim` allocates, `t.graphemes()`, `t.words()`, etc. allocate per element. A 100 KB Text with 30 K graphemes that the design promises walks "with no per-element allocation" actually allocates 30 K times. The design's §3.5 "Iteration speedup even for non-indexed Text" claim is conditional on a fact the design admits is unverified.

Suggested change: per T3 action item; additionally, define a fallback in the design itself — if trim allocates, iterators yield `_GraphemeSpan val` (a `(start: USize, end: USize)` pair into the parent's `_utf8`) and callers materialize lazily. Decouples the design from a stdlib assumption.

---

**G7. `_form` propagation across operations is unspecified — slicing/concat/case-mapping can yield non-NFC bytes carrying an NFCForm tag.**

```pony
let t = (Text.from_string(input) as Text val).normalize(NFCForm)   // _form = NFCForm
let cut = t.slice_codepoints(CodepointIndex(1), CodepointIndex(t.size_codepoints())) as Text val
cut.eq_normalized(other, NFCForm)
```

If `t` starts with a multi-codepoint cluster (e.g., "é" = e + U+0301), slicing at codepoint 1 leaves U+0301 (a combining mark) as the leading character. NFC requires position 0 to be a starter — the slice's bytes are *not* NFC. If the design inherits `_form = NFCForm`, `eq_normalized` may short-circuit and return the wrong answer.

Suggested change: define a per-op form propagation contract:

| Op | `_form` after |
|---|---|
| `normalize(f)` | `f` |
| `slice_graphemes` | preserved (cuts are NFC-safe) |
| `slice_codepoints` | `UnknownForm` |
| `+` (concat) | `UnknownForm` |
| `to_lower`/`to_upper`/`to_title` | `UnknownForm` (full case mapping is not NFC-preserving) |

Add a PonyCheck regression: for each op, generate NFC inputs, run the op, verify the result's `_form` matches a post-hoc UAX #15 quick-check.

### MINOR

**M1.** `Script.from_iso(s)?` is partial — config-driven script matching loses the closed-union exhaustiveness benefit (§10 #4) for data-driven lookups.

**M2.** Naming inconsistency: `Codepoint.from_u32_or_replacement` vs `Text.from_string_lossy`. Both total, both substitute U+FFFD. A reader searches for `from_u32_lossy` and finds nothing. Pick one style.

**M3.** Single-codepoint Text construction: `Text.from_codepoint(cp)` exists for `Codepoint val`, but no `Text.from_u32(u): (Text val | InvalidScalar)` for the common "I have one u32" case. Callers fall through to `from_codepoint_scalars([u])` and pay extra allocation.

## Passes (tried, couldn't break)

- **P1.** No path from `Text val` to a mutable `String ref` view of its bytes. Pony cap system prevents `val → ref` aliasing; methods return `String val` or `String iso^`. Couldn't construct an escape.
- **P2.** Can't alias two `Text val`s onto the same buffer with different `_form` tags except via constructors. S3 is about constructors stamping wrong values, not about aliasing-after-construction.
- **P3.** `Text.from_utf8_iso(consume b)?` still validates UTF-8 (per §1 signature `(Text val | InvalidUtf8)`). No path adopts unchecked bytes.
- **P4.** No race on grapheme bitmap: `Text val` is immutable, bitmap is sealed at construction.

## Uncertainties

1. **S2 vs G1 bucketing.** Both are substitution-laundering. S2 structural (no legitimate use case for the codepoint-level lossy variant) and G1 significant (string lossy *does* have a legitimate use, just not the one §10 names). A reader could swap.
2. **G3 depends on resolving the §3.5 ambiguity.** "Inherits status … rebuilds the index" — both can't be true. The worse reading is assumed. If the implementer picks "always rebuild," G3 dissolves to a doc clarification.
3. **S1 sensitivity to release shape.** If v0.1 and v0.2 ship as one release, S1's window closes. The design explicitly separates them in §9.
4. **G7 form-propagation table.** Full case mapping is not NFC-preserving for many code points; not universal. A "simple case mapping" mode (not currently in the design) could preserve NFC.
