# Pony Unicode Package — Synthesized Candidate (v1)

**Stage**: Stage 1 synthesis of three persona designs (consumer-first, skeptic, principle-checker).
**Purpose**: Single integrated candidate carrying forward the convergent decisions, the strongest unique findings, and explicit tensions for human judgment.

---

## 0. Approach (one paragraph)

The synthesized package is **dual-surface, single-truth**. The canonical, typed surface is `Text val` — a wrapper that guarantees well-formed UTF-8 and carries an honest `NormalForm` tag. Alongside it, a set of **topical primitives** (`Graphemes`, `Codepoints`, `Normalize`, `Case`, `Compare`, `Scripts`, `Bytes`, …) expose free-function forms over `String box`. Both surfaces delegate to the same package-private underscore methods on those primitives — the logic lives in the primitives, `Text` skips validation (its invariant holds), and the public free-function forms validate first. The relationship is compile-enforced; behavior cannot drift between the two surfaces.

Indices are **phantom-tagged** (`Index[_ByteIdx | _CodepointIdx | _GraphemeIdx]`) — the principle-checker's highest-value finding — so byte/codepoint/grapheme offsets cannot be mixed at compile time. Codepoint representation splits the perf/safety tension: **iterators yield `U32`** (no per-element heap allocation), and **`Codepoint val` exists as a validated wrapper for boundary use** where type safety is worth a single allocation. Closed unions replace stringy enums (`Script`, `Category`, `Property`, error types). UCD is build-time generated, compiled-in, version-pinned per release. Scope ramps from a coherent useful v0.1 (count graphemes, normalize, segment, basic predicates) through to security, collation, and confusables.

---

## 1. Type surface

| Type | Cap | Semantic guarantee | Construction |
|---|---|---|---|
| `Text` | `class val` | Well-formed UTF-8; honest `NormalForm` tag; optional bitmap index (§3.5) | `Text.from_string(s, indexed = false)`, `Text.from_string_lossy(s, indexed = false)`, `Text.from_utf8_bytes(b, indexed = false)`, `Text.from_utf8_iso(consume b, indexed = false)`, `Text.from_codepoint_scalars(scalars, indexed = false)`, `Text.from_codepoint(cp)`, `Text.decode(bytes, enc, policy, indexed = false)` — all return `(Text val \| <error union>)` per §6, no partial functions |
| `Codepoint` | `class val` (wraps `U32`) | Valid Unicode scalar (0..D7FF ∪ E000..10FFFF) | `Codepoint.from_u32(u)` returns `(Codepoint val \| InvalidScalar)`; `Codepoint.from_u32_or_replacement(u): Codepoint val` |
| Grapheme — _no class_; graphemes are `String val` slices yielded by `Text.graphemes()` and returned by `Text.grapheme_at(...)`. Grapheme-level queries are free functions on the `Graphemes` topical primitive (§4.3). | n/a | UAX #29 extended grapheme cluster | `Text.graphemes()`, `Text.grapheme_at(GraphemeIndex(n))`, `Graphemes.at(s, GraphemeIndex(n))` |
| `ByteIndex` | `val` (= `Index[_ByteIdx]`) | Byte offset into a `Text`'s UTF-8 | `ByteIndex(n)` |
| `CodepointIndex` | `val` (= `Index[_CodepointIdx]`) | Codepoint offset | `CodepointIndex(n)` |
| `GraphemeIndex` | `val` (= `Index[_GraphemeIdx]`) | Grapheme offset | `GraphemeIndex(n)` |
| `Script` | closed union of primitives | One of the ISO 15924 scripts in the loaded UCD | `Script.latin`, `Script.from_iso(s)?` |
| `Category` | closed union of primitives | One of the 30 general categories | `Category.uppercase_letter`, `Category.from_iso(s)?` |
| `Property` | closed union of primitives | One binary property tracked by the package | `Property.alphabetic`, … |
| `NormalForm` | closed union of primitives | `NFCForm \| NFDForm \| NFKCForm \| NFKDForm \| UnknownForm` | direct: `NFCForm`, etc. |
| `Encoding` | trait `val` | An encoding with `decode`/`encode` | implementations are primitives: `Utf8`, `Utf16Le`, `Utf16Be`, `Utf32Le`, `Utf32Be`, `Latin1`, `WindowsCp1252`, … |
| `DecodePolicy` | closed union | `StrictPolicy \| ReplacePolicy \| IgnorePolicy` | direct primitives |
| `EncodePolicy` | closed union | `StrictPolicy \| ReplacePolicy` | direct primitives |
| `CaseLocale` | closed union | `DefaultLocale \| TurkicLocale \| LithuanianLocale \| AzerbaijaniLocale` | direct primitives |
| `Collator` | `class val` | Locale-tailored ordering; `compare` + `sort_key` | `Collator.root()`, `Collator.locale(s)?`, `Collator.locale_or_root(s)` |
| `ScriptSet` | `class val` | Small set of `Script`; `.resolved()` drops Common/Inherited | `Text.scripts()` |
| `Graphemes`, `Codepoints`, `Normalize` (v0.2), `Case` (v0.2), `Compare` (v0.2), `Words`/`Sentences`/`Lines` (v0.3), `Scripts` (v0.3) | primitives | Topical free-function surfaces over `String box`; logic shared with `Text` methods (§2) | `Graphemes.count(s)`, `Normalize.to(s, NFCForm)`, etc. |
| `Bytes` | primitive | Pre-validation byte helpers (BOM, quick UTF-8 check) | `Bytes.starts_with_bom(b)`, `Bytes.is_valid_utf8(s)`, `Bytes.first_bad_utf8_offset(s)` |
| `Confusables` | primitive (v0.7+) | UTS #39 skeleton | `Confusables.skeleton(t)` |
| `UnicodeVersion` | `class val` | Major/minor/patch of the bundled UCD | `Unicode.version()` |

**Errors** (all primitives or small `class val`s, all implementing `Stringable`):

| Type | Context | Layer | When |
|---|---|---|---|
| `InvalidUtf8` (= `_InvalidUtf8At`) | `offset: USize` | construction | bytes/string not well-formed UTF-8 |
| `InvalidScalar` (= `_Surrogate \| _OutOfRange`) | `value: U32` | codepoint | surrogate or > U+10FFFF passed to `Codepoint.from_u32` |
| `OutOfRange` | `index: USize`, `size: USize` | indexing | `Index` past end |
| `DecodeError` | `offset: USize`, `kind: _DecodeKind`, `encoding_name: String val` | encoding | codec decode failed |
| `EncodeError` | `codepoint: Codepoint val`, `encoding_name: String val` | encoding | codec can't represent a codepoint |
| `LocaleError` | `tag: String val` | collation | `Collator.locale(s)?` unknown tag |

Each fallible operation returns `(T | <one or more error primitives in a closed union>)`. No exceptions; no marker traits (Pony gotcha #9).

---

## 2. Typed / utility relationship

The user explicitly requires both views. The synthesis answer is **logic-in-primitives; both surfaces delegate**:

- **The Unicode logic lives in topical primitives** named after the operation domain — `Graphemes`, `Codepoints`, `Normalize`, `Case`, `Compare`, `Scripts`, `Bytes`, … Each primitive has both a public (validating) form and a package-private underscore form (assumes valid).
- **`Text val` is the typed wrapper.** Its methods carry the validated UTF-8 invariant by construction, so they call the underscore form directly and skip re-validation.
- **The same topical primitive serves both surfaces**: a user calling `Graphemes.count(s)` directly hits the validating public form; a `t.size_graphemes()` call from `Text` hits the same logic via the underscore form. No `Strops`-style monolith; no lift-through-Text dance.

Concretely:

```pony
primitive Graphemes
  // Public, validates first
  fun count(s: String box): (USize | InvalidUtf8) =>
    if Bytes.is_valid_utf8(s) then _count(s)
    else _InvalidUtf8At(Bytes.first_bad_utf8_offset(s)) end

  // Package-private, the actual logic. Assumes valid UTF-8.
  fun _count(utf8: String box): USize =>
    var n: USize = 0
    let cursor = _GraphemeCursor.from_start(utf8)
    while cursor.advance() do n = n + 1 end
    n

class val Text
  let _utf8: String val
  let _form: NormalForm

  fun size_graphemes(): USize =>
    Graphemes._count(_utf8)   // no re-validation, no allocation
```

The same pattern applies to every topical primitive. `Normalize.to(s, form)` validates and calls `Normalize._to(s, form)`; `Text.normalize(form)` calls `Normalize._to(_utf8, form)`. `Case.lower(s, locale)` and `Text.to_lower(locale)` both delegate to `Case._lower(utf8, locale)`. And so on.

This is **the dependency direction**: topical primitives carry the logic; `Text` and the public free-function forms are both thin entry points. The relationship is compile-enforced — both surfaces call the same underscore method — so behavior cannot drift between them.

### Topical primitives in the core (v0.1 surface)

| Primitive | Concern | Public methods (examples) |
|---|---|---|
| `Graphemes` | UAX #29 cluster ops over `String` | `count(s)`, `iter(s)`, `slice(s, start, end)`, `offset(s, n)` |
| `Codepoints` | codepoint-level ops over `String` | `count(s)`, `iter(s)`, `iter_scalars(s)`, `is_all(s, p)`, `is_all_letters(s)`, `is_all_digits(s)` |
| `Codepoint` | single-codepoint factory + scalar predicates (no String) | `from_u32(u)`, `from_u32_or_replacement(u)`, `is_scalar(u)`, `is_letter_scalar(u)`, `is_digit_scalar(u)`, `category_of_scalar(u)`, `script_of_scalar(u)` |
| `Bytes` | byte-level pre-validation helpers | `is_valid_utf8(s)`, `starts_with_bom(b)`, `detect_bom(b)`, `first_bad_utf8_offset(s)` |

**v0.2 adds** `Normalize` (`to`, `is_normalized`), `Case` (`lower`, `upper`, `title`, `fold`), `Compare` (`eq_normalized`, `eq_caseless`, `eq_caseless_normalized`).

**v0.3 adds** `Words`, `Sentences`, `Lines` (UAX-29/14 break iterators), `Scripts` (`of`, `dominant`).

Each primitive's public methods take `String box` and return a union with `InvalidUtf8`. Each primitive's underscore methods take `String box` and assume valid UTF-8 — they are called from `Text` methods (which carry the invariant) and from each other.

### What this buys

- **No `Text` allocation on the free-function path.** `Graphemes.count(s)` validates `s` then calls a function — no `Text val` instance constructed.
- **No re-validation on the `Text` path.** A `Text` already carries the well-formed-UTF-8 invariant, so its methods skip validation.
- **One implementation, two surfaces.** Adding a new operation is one underscore method on the topical primitive plus two thin wrappers (one on the primitive as the public validating form, one on `Text`).
- **One test surface.** Test the underscore methods exhaustively; the wrappers are obviously-correct delegations.
- **Problem-domain names.** A reader hitting `Graphemes.count` or `Normalize.to` knows what the function is about from the name alone — no abbreviation to decode.

### When to use each

| You have | You want | Use |
|---|---|---|
| Already a `Text` | any Unicode op | methods on `Text` |
| `String box` you'll touch repeatedly | repeated Unicode ops | construct `Text` once |
| `String box` + one cheap question | a single answer | `Graphemes.X(s)` / `Codepoints.X(s)` / `Normalize.X(s, …)` / etc. |
| Raw bytes, known encoding | a `Text` | `Text.decode(b, enc, policy)?` or `Text.from_utf8_bytes(b)?` |
| `Array[U8] iso` you own (UTF-8) | a `Text`, zero-copy | `Text.from_utf8_iso(consume b)?` |
| `Text` to send out | bytes | `t.utf8_bytes()` or `Utf16Be.encode(t)?` |
| Need to check raw bytes pre-validation | a single boolean / scan | `Bytes.X(b)` |

### Conversion API

```pony
// String <-> Text (strict; substituting variant for lossy consumers)
match Text.from_string(s)
| let t: Text val => use(t)
| let e: InvalidUtf8 => log(e.string())
end

let t: Text val = Text.from_string_lossy(s)   // substitutes U+FFFD

let s: String val = t.utf8_bytes()            // canonical UTF-8 bytes as String

// Array[U8] iso (UTF-8) -> Text, zero-copy adoption
let t: Text val = Text.from_utf8_iso(consume bytes)?

// Codepoint <-> U32 (boundary)
let cp: Codepoint val = Codepoint.from_u32(u)?
let u: U32           = cp.scalar()

// Iterators yield U32 for codepoints (hot path)
for u in t.codepoint_scalars() do
  if Codepoint.is_letter_scalar(u) then ...
end

// ...and Codepoint val for users who want type safety at the cost of allocation
for cp in t.codepoints() do
  if cp.is_letter() then ...
end
```

### What we deliberately don't do

- **No structural `Stringy` interface** over `String` and `Text`. Their `size()` would mean different things (bytes vs graphemes). Distinct semantics → distinct representations (principle 12).
- **No `Text` arithmetic with `String`**. Concatenation across types is explicit (`t1 + Text.from_string(s)?`).
- **No silent normalization on construction.** A `Text` is born with `_form = UnknownForm` unless its source guarantees otherwise (e.g., the result of `t.normalize(NFCForm)` carries `NFCForm`). This is a deliberate departure from Raku's NFG/auto-NFC.

---

## 3. Index types — the central correctness mechanism

The principle-checker's `Index[Kind]` is the highest-value design move in the ensemble. None of the other personas considered it; both would have made byte-offset-passed-to-grapheme-function bugs latent.

```pony
primitive _ByteIdx
primitive _CodepointIdx
primitive _GraphemeIdx

class val Index[Kind: (_ByteIdx | _CodepointIdx | _GraphemeIdx)]
  let _value: USize
  new val create(value: USize) => _value = value
  fun value(): USize => _value
  fun eq(that: Index[Kind] box): Bool => _value == that._value
  fun lt(that: Index[Kind] box): Bool => _value < that._value
  fun add(n: USize): Index[Kind] => create(_value + n)

type ByteIndex      is Index[_ByteIdx]
type CodepointIndex is Index[_CodepointIdx]
type GraphemeIndex  is Index[_GraphemeIdx]
```

### How it shows up in `Text`'s methods

```pony
class val Text
  // Counting — distinct method per unit; no ambiguity
  fun size_bytes(): USize                            // O(1)
  fun size_codepoints(): USize                       // indexed: O(1); else O(n)
  fun size_graphemes(): USize                        // indexed: O(1); else O(n)

  // Indexing — argument kind enforces correctness; complexity varies with index
  fun codepoint_at(i: CodepointIndex): (Codepoint val | OutOfRange)   // indexed: O(n/64); else O(n)
  fun grapheme_at(i: GraphemeIndex): (String val | OutOfRange)         // indexed: O(n/64); else O(n)
  fun byte_at(i: ByteIndex): (U8 | OutOfRange)                          // O(1)

  // Slicing — no slice_bytes (would split UTF-8); cp/grapheme only.
  // Returned Text inherits the parent's index status — caller may call
  // .indexed() to materialize one or .unindexed() to drop it.
  fun slice_codepoints(start: CodepointIndex, finish: CodepointIndex)
    : (Text val | OutOfRange)
  fun slice_graphemes(start: GraphemeIndex, finish: GraphemeIndex)
    : (Text val | OutOfRange)

  // Explicit, named conversions between kinds — always need a Text
  fun codepoint_index_of_byte(b: ByteIndex): (CodepointIndex | OutOfRange)
  fun grapheme_index_of_codepoint(c: CodepointIndex): (GraphemeIndex | OutOfRange)
  fun byte_index_of_grapheme(g: GraphemeIndex): ByteIndex

  // Index control — produce a new Text with/without the bitmap index
  fun indexed(): Text val      // returns self if already indexed
  fun unindexed(): Text val    // returns self if already unindexed
  fun is_indexed(): Bool
```

Note: `grapheme_at` returns `String val` (the UTF-8 slice of the cluster), not a `Grapheme val` — graphemes are not a distinct type. See §4.3 for rationale.

The footgun being prevented:

```pony
// Caller wrote: "give me the grapheme at byte offset 7"
t.grapheme_at(7)
// ^ compile error: USize cannot match GraphemeIndex
t.grapheme_at(GraphemeIndex(7))   // OK — caller declared intent
// Or: convert explicitly from bytes (which can fail at a non-boundary)
let g = match t.codepoint_index_of_byte(ByteIndex(7))
        | let ci: CodepointIndex =>
          match t.grapheme_index_of_codepoint(ci)
          | let gi: GraphemeIndex => t.grapheme_at(gi)
          else None
          end
        else None
        end
```

This is verbose by design — the verbosity *is* the safety. Callers who know they have a grapheme index just write `GraphemeIndex(n)`.

The topical primitives do not expose `Index[Kind]` — they operate on whole strings or on `USize` offsets *only when the unit is named in the method* (e.g., `Graphemes.offset(s, n: USize)` returns the byte offset of the start of grapheme `n`).

### 3.5 The optional bitmap index

UTF-8 storage is the right default — zero-copy adoption from `String val`, zero-copy slices out as `String val`, no re-encoding on the way in or out. The cost is that random grapheme access is O(n) without help.

The package adds an **optional bitmap index** that the caller opts into at `Text` construction via the `indexed: Bool = false` parameter. The structure:

```pony
class val _TextIndex
  let _gr_starts: _BitVec val      // 1 bit per UTF-8 byte: is this byte a grapheme start?
  let _gr_count:  USize            // popcount of _gr_starts
  let _cp_count:  USize             // popcount of derived codepoint-start bitmap
                                    // (codepoint-start is derivable from the byte:
                                    //  (b & 0xC0) != 0x80; we cache the count only)

class val Text
  let _utf8:  String val
  let _form:  NormalForm
  let _index: (_TextIndex val | None)
```

**What's stored, and why:**
- **`_gr_starts`** (1 bit/byte). Genuinely new information — UAX #29 grapheme breaks require running a state machine over the codepoint stream; cannot be derived from a single byte. This is the bitmap that makes grapheme lookup fast.
- **`_gr_count`**. Cached popcount of `_gr_starts`. Makes `size_graphemes()` O(1) instead of O(n/64).
- **`_cp_count`**. Cached popcount of the *implicit* codepoint-start bitmap. The codepoint-start bitmap itself is *not* stored — it's derivable per-byte via `(b & 0xC0) != 0x80`, so SIMD popcount over the bytes gives the same answer without storing anything. We cache the resulting count.
- **No rank/select tables.** Lookup is O(n/64) bitmap scan, not true O(1). This was the user's explicit choice — simpler, smaller, fast enough for realistic text sizes; rank/select can be added later in a separate `indexed_select()` variant if needed.

**Memory cost:** roughly `n/8` bytes (one bit per UTF-8 byte) for `_gr_starts`, plus two `USize` cached counts. For 100 KB of UTF-8 text: ~12.5 KB index overhead.

**Construction cost:** one O(n) walk applying UAX #29, identical to what `size_graphemes()` would cost on a non-indexed Text. So if a program calls any grapheme operation even once, `Text.from_string(s, indexed = true)` is free relative to the alternative.

**Index propagation:** operations that return a derived `Text` (`slice_graphemes`, `+`, `to_lower`, etc.) inherit the parent's index status — if the input was indexed, the result is too (the implementation rebuilds the index for the new bytes; cheap because we're already walking them). Callers can call `.indexed()` or `.unindexed()` to flip explicitly.

**Iteration speedup, even for non-indexed Text:** `text.graphemes()` internally builds a local grapheme-start bitmap once during iteration construction and walks it. So iteration is faster than naive UAX #29 even without a stored index; the index just makes the bitmap survive past the iterator's lifetime.

---

## 4. Codepoint representation — split path

The skeptic's per-iteration allocation concern is concrete and correct. The other two personas' type-safety argument is also correct. The synthesis splits the path:

### 4.1 `Codepoint val` exists, but only as a validated wrapper

```pony
class val Codepoint
  let _scalar: U32

  new val _create(scalar: U32) => _scalar = scalar     // package-private

  fun scalar(): U32 => _scalar
  fun category(): Category
  fun script(): Script
  fun name(): (String val | NoName)
  fun is_letter(): Bool
  fun is_digit(): Bool
  fun is_whitespace(): Bool
  fun is_emoji(): Bool
  fun has_property(p: Property): Bool
  fun numeric_value(): (F64 | NoNumericValue)
  fun simple_uppercase(): Codepoint
  fun simple_lowercase(): Codepoint
  fun simple_titlecase(): Codepoint
  fun eq(that: Codepoint box): Bool
  fun lt(that: Codepoint box): Bool
  fun hash(): USize

primitive Codepoint
  fun from_u32(u: U32): (Codepoint val | InvalidScalar)
  fun from_u32_or_replacement(u: U32): Codepoint val
  fun is_scalar(u: U32): Bool                          // no allocation
```

### 4.2 Hot iteration uses `U32` directly

```pony
class val Text
  // Allocating iteration — type-safe, for normal use
  fun codepoints(): Iterator[Codepoint val]

  // Hot-path iteration — yields U32 scalars, no allocation per element
  fun codepoint_scalars(): Iterator[U32]
```

A parallel set of predicates accepts `U32` directly, for use inside hot iteration:

```pony
primitive Codepoint
  // U32-form predicates — for hot loops; bypass the wrapper
  fun is_letter_scalar(u: U32): Bool
  fun is_digit_scalar(u: U32): Bool
  fun is_whitespace_scalar(u: U32): Bool
  fun category_of_scalar(u: U32): Category
  fun script_of_scalar(u: U32): Script
```

**Invariant**: every `U32` yielded by `Text.codepoint_scalars()` is a valid scalar (the `Text` already validated UTF-8 at construction). Callers building `U32` from arithmetic, FFI, or external protocols must go through `Codepoint.from_u32(u)?` if they want validation, or `Codepoint.is_scalar(u)` if they want a check without allocation.

This pair lets users opt in to type safety where boundaries matter (network → `Codepoint.from_u32(u)?`) and out where it costs (`for u in text.codepoint_scalars() do ...`).

**Naming convention**: `_scalar`-suffixed forms take `U32`; bare forms take `Codepoint val`. The same convention applies on `Text` (`codepoints()` vs `codepoint_scalars()`).

### 4.3 Storage is always `U32`; graphemes are `String val` slices

The split path is about *iteration*. Storage carries the same allocation concern more sharply: a single `Array[Codepoint val]` of N elements is N heap allocations *plus* the array's pointer array. Per the user's explicit guidance, **anywhere the package stores codepoints in a collection, the element type is `U32`, not `Codepoint val`.**

**Graphemes are not a distinct type.** A grapheme cluster is a substring of UTF-8 bytes — a `String val` slice of the parent `Text`'s `_utf8`. Iterators yield `String val`; random access returns `String val`. Grapheme-level queries (base codepoint, script, properties) are free functions on the `Graphemes` topical primitive, not methods on a class.

Why drop the `Grapheme` class:
- **No invariant is preserved by operations.** Concatenating two graphemes can produce a non-grapheme; slicing produces a degenerate grapheme. There's nothing for a wrapper class to enforce that the slice itself doesn't already guarantee at construction.
- **Iterators yield zero-copy `String val` slices** — directly usable in any Pony API that takes `String val`. A `Grapheme` class would force a wrap-then-unwrap dance at every IO boundary.
- **No allocation overhead per cluster.** A `class val Grapheme` would heap-allocate per yielded element. With slices, only the parent UTF-8 buffer is on the heap; each "grapheme" is a sliced view.
- **The user's bitmap-index design makes this even cleaner** — iterating graphemes is "find next 1-bit in the bitmap, slice between consecutive 1-bits", which trivially yields slices.

```pony
class val Text
  fun graphemes(): Iterator[String val]      // zero-copy slices, no per-element allocation
  fun grapheme_at(i: GraphemeIndex): (String val | OutOfRange)

primitive Graphemes
  // Operations on a single grapheme cluster — input is the slice yielded by Text.graphemes()
  fun base_scalar(cluster: String box): U32          // first codepoint
  fun base(cluster: String box): Codepoint val       // wrapped form, allocating
  fun codepoint_scalars(cluster: String box): Iterator[U32]
  fun codepoints(cluster: String box): Iterator[Codepoint val]
  fun size_codepoints(cluster: String box): USize
  fun script(cluster: String box): Script
  fun has_property(cluster: String box, p: Property): Bool
  fun is_emoji(cluster: String box): Bool
  // Note: package-private underscore forms assume the slice is a valid single cluster;
  // public forms (validating across-cluster boundaries) are not exposed because
  // a `String val` from outside the package has no such guarantee — callers wanting
  // to check should lift to Text and iterate.

primitive Text
  // Constructor accepts the raw integer form — no Array[Codepoint val] required
  fun from_codepoint_scalars(scalars: ReadSeq[U32] box, indexed: Bool = false)
    : (Text val | InvalidScalar)
  // Convenience for the "I have one Codepoint val" case
  fun from_codepoint(cp: Codepoint val): Text val
```

`Text.from_codepoints(ReadSeq[Codepoint val])` is **not** provided. Callers with a sequence of codepoints have, by definition, already paid the allocation cost — but the package itself never forces it by exposing a function whose ergonomic shape implies `Array[Codepoint val]`. The constructor takes `U32` scalars; the user converts at the boundary if needed.

The same logic applies to any future API that returns or accepts a sequence of codepoints: the type is `Array[U32] val` or `ReadSeq[U32]`, never `Array[Codepoint val]` or `ReadSeq[Codepoint val]`.

---

## 5. NormalForm strategy

The principle-checker's tagged form wins, with consumer-first's lazy-default refinement:

- **`Text` carries a `_form: NormalForm` field.**
- **Default is `UnknownForm`** — construction does not implicitly normalize.
- **Transforms produce known forms**: `t.normalize(NFCForm)` returns a `Text val` with `_form = NFCForm`.
- **`t.is_normalized(form)` is the runtime check.** Cheap via UAX #15 quick-check, early-terminates on ASCII.
- **Equality is explicit per semantic**:
  - `t.eq_codepoints(u)` — byte-equal sequences
  - `t.eq_normalized(u, form = NFCForm)` — normalize both, then compare
  - `t.eq_caseless(u, locale = DefaultLocale)` — full case fold + NFD compare
  - `t.eq_caseless_normalized(u, form = NFCForm, locale = DefaultLocale)` — the identifier-matching default; one call, one decision, no chance to forget a step
- **`normalize` is idempotent when form matches**: `t.normalize(t._form)` short-circuits when `_form != UnknownForm`.

This satisfies "make illegal states unrepresentable" *for the operations where it matters* (a `Text` tagged `NFCForm` truly is NFC) without forcing every consumer to pay normalization on construction (the skeptic's correct concern about boundary cost).

The skeptic's objection — "why is NFC the only string property that gets typed?" — is addressed by the answer: it's the only property both *expensive to recompute* and *required for meaningful equality*. Category, script, etc. are cheap UCD lookups; normalization is a structural transform.

---

## 6. Error vocabulary

Per-layer, concrete, all `Stringable`. No cross-layer wrappers — callers match on disjoint primitives.

```pony
// Construction layer
primitive _InvalidUtf8At
  let offset: USize
  fun string(): String iso^ =>
    "invalid UTF-8 at byte offset " + offset.string()

type InvalidUtf8 is _InvalidUtf8At

// Codepoint layer
primitive _Surrogate
  let value: U32
  fun string(): String iso^ =>
    "surrogate codepoint U+" + Format.hex[U32](value)

primitive _OutOfRange
  let value: U32
  fun string(): String iso^ =>
    "codepoint out of range: U+" + Format.hex[U32](value)

type InvalidScalar is (_Surrogate | _OutOfRange)

// Indexing layer
class val OutOfRange
  let index: USize
  let size:  USize
  fun string(): String iso^ =>
    "index " + index.string() + " out of range [0, " + size.string() + ")"

// Encoding layer
primitive _DecodeIllFormed
primitive _DecodeUnmappable
type _DecodeKind is (_DecodeIllFormed | _DecodeUnmappable)

class val DecodeError
  let offset: USize
  let kind: _DecodeKind
  let encoding_name: String val
  fun string(): String iso^

class val EncodeError
  let codepoint: Codepoint val          // the unmappable codepoint
  let encoding_name: String val
  fun string(): String iso^

// Collation layer
class val LocaleError
  let tag: String val
  fun string(): String iso^ =>
    "unknown locale tag: " + tag
```

Callers compose by matching disjoint error primitives — `FileError | DecodeError | InvalidUtf8` all line up because each is its own type.

---

## 7. UCD strategy

- **Build-time generation**, runs at *library release time*, checked into the package source. Tool name: `unicode-build` (separate small Pony package; consumers don't depend on it at runtime).
- **Form**: two-stage radix tables (range → property) for cp→property lookups; CCC + decomposition side tables; break properties as sorted range arrays (binary search); DUCET packed weighted strings (when collation lands).
- **Output**: generated `.pony` source files defining `val` static tables. Compiled into the package; always resident. Compressed size projected at ~1–3 MB for v0.1 scope, up to ~5 MB at full UCD.
- **One Unicode version per package release.** `Unicode.version(): UnicodeVersion` returns it; bumping is a release event with notes. No runtime version switching.
- **Optional subpackages** for cold/large data:
  - `red/unicode/names` — codepoint name lookup (~600 KB of strings)
  - `red/unicode/collate` — DUCET + CLDR tailorings
  - `red/unicode/confusables` — UTS #39 skeleton tables
  - `red/unicode/idna` — IDNA mapping (later)

The `cp.name()` method in the core returns `(String val | NoName)`; `NoName` is returned both when no name exists for the codepoint and when the `names` subpackage isn't loaded. The names subpackage installs the real lookup at link time via a package-internal hook (one mechanism considered: a top-level primitive holding the lookup function, which `names` overwrites when imported; alternatively, names becomes a hard dep and the core never claims to know names). **This is a remaining design tension** — see §11.

---

## 8. Consumer sketches

The same 10 canonical scenarios, expressed in the synthesized API. Both `Text` and topical-primitive forms shown where the choice is meaningful.

### A. Count visible characters

Typed:
```pony
use unicode = "red/unicode"

actor Main
  new create(env: Env) =>
    let raw: String val = "café 🇫🇷👨‍👩‍👧"
    match unicode.Text.from_string(raw)
    | let t: unicode.Text val =>
      env.out.print("graphemes:  " + t.size_graphemes().string())
      env.out.print("codepoints: " + t.size_codepoints().string())
      env.out.print("bytes:      " + t.size_bytes().string())
    | let e: unicode.InvalidUtf8 => env.out.print(e.string())
    end
```

Utility:
```pony
match unicode.Graphemes.count(raw)
| let n: USize => env.out.print("graphemes: " + n.string())
| let e: unicode.InvalidUtf8 => env.out.print(e.string())
end
```

### B. Case-insensitive username compare after normalization

```pony
fun users_match(a: String box, b: String box)
  : (Bool | unicode.InvalidUtf8)
=>
  match (unicode.Text.from_string(a), unicode.Text.from_string(b))
  | (let ta: unicode.Text val, let tb: unicode.Text val) =>
    ta.eq_caseless_normalized(tb, unicode.NFCForm, unicode.DefaultLocale)
  | _ => unicode.InvalidUtf8
  end
```

Where `eq_caseless_normalized` is the single right call for identifier matching (consumer-first's `identifier_fold` consolidated into an equality method, since equality is what callers really want).

### C. Truncate display name at character N

```pony
fun truncate(s: String box, max: USize)
  : (String val | unicode.InvalidUtf8)
=>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    let limit_n = max.min(t.size_graphemes())
    let limit = unicode.GraphemeIndex(limit_n)
    match t.slice_graphemes(unicode.GraphemeIndex(0), limit)
    | let cut: unicode.Text val => cut.utf8_bytes()
    | let _: unicode.OutOfRange => t.utf8_bytes()  // unreachable given the min
    end
  | let e: unicode.InvalidUtf8 => e
  end
```

### D. Validate input: only letters and digits

Typed (boundary cares about each codepoint):
```pony
fun is_alnum_typed(s: String box): (Bool | unicode.InvalidUtf8) =>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    if t.size_codepoints() == 0 then return false end
    t.is_all_codepoints({(cp: unicode.Codepoint val): Bool =>
      cp.is_letter() or cp.is_digit() })
  | let e: unicode.InvalidUtf8 => e
  end
```

Hot-path version (no per-codepoint allocation):
```pony
fun is_alnum_fast(s: String box): (Bool | unicode.InvalidUtf8) =>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    if t.size_codepoints() == 0 then return false end
    for u in t.codepoint_scalars() do
      if not (unicode.Codepoint.is_letter_scalar(u)
              or unicode.Codepoint.is_digit_scalar(u))
      then return false end
    end
    true
  | let e: unicode.InvalidUtf8 => e
  end
```

### E. Iterate words

```pony
actor WordCount
  new create(env: Env, text: String val) =>
    match unicode.Text.from_string(text)
    | let t: unicode.Text val =>
      var n: USize = 0
      for w in t.words() do      // w: Text val, zero-copy slice
        env.out.print(w.utf8_bytes())
        n = n + 1
      end
      env.out.print("words: " + n.string())
    | let e: unicode.InvalidUtf8 => env.out.print(e.string())
    end
```

`words()`, `sentences()`, `lines()` yield `Iterator[Text val]`. Each yielded `Text` is a zero-copy slice of the underlying UTF-8 (memory is shared via Pony `val` semantics — relies on the same property the skeptic flagged: `String val.trim` zero-copy. **See §11 tension on this assumption.**)

### F. Read a Latin-1 file as text

```pony
use file = "files"
use unicode = "red/unicode"

actor LoadLatin1
  new create(env: Env, auth: AmbientAuth, path: String val) =>
    try
      let fp = file.FilePath(auth, path)?
      let f  = file.File(fp)
      let bytes: Array[U8] val = f.read(f.size())
      // Latin-1 decode is total — every byte maps. Returns Text val directly.
      let t = unicode.Latin1.decode_total(bytes)
      env.out.print(t.utf8_bytes())
    end
```

Codecs whose decode is *total* on byte input (Latin-1, ASCII when constrained) expose `decode_total(bytes): Text val` in addition to `decode(...)?`. This is convention, not a separate trait — consumer-first's call, kept because polymorphic codec loops still work uniformly via `decode(...)?`.

For potentially-failing codecs:
```pony
match unicode.Utf16Le.decode(bytes, unicode.StrictPolicy)
| let t: unicode.Text val => use(t)
| let e: unicode.DecodeError => env.err.print(e.string())
end
```

### G. Sort names in dictionary order

```pony
use collections = "collections"

fun sort_names(names: Array[unicode.Text val] iso)
  : Array[unicode.Text val] iso^
=>
  match unicode.Collator.locale("en-US")
  | let c: unicode.Collator val =>
    collections.Sort[Array[unicode.Text val], unicode.Text val](
      consume names,
      {(a: unicode.Text val, b: unicode.Text val): I32 => c.compare(a, b)})
  | let _: unicode.LocaleError =>
    // fall back to root collation
    let c = unicode.Collator.root()
    collections.Sort[Array[unicode.Text val], unicode.Text val](
      consume names,
      {(a: unicode.Text val, b: unicode.Text val): I32 => c.compare(a, b)})
  end
```

For repeated comparisons:
```pony
let keyed = Array[(Array[U8] val, unicode.Text val)]
for n in names.values() do
  keyed.push((c.sort_key(n), n))
end
```

### H. Detect mixed scripts for security

```pony
fun mixed_script(s: String box): (Bool | unicode.InvalidUtf8) =>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val => t.scripts().resolved().size() > 1
  | let e: unicode.InvalidUtf8 => e
  end

fun matches_brand(s: String box, brand: unicode.Text val)
  : (Bool | unicode.InvalidUtf8)
=>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    unicode.Confusables.skeleton(t).eq_codepoints(
      unicode.Confusables.skeleton(brand))
  | let e: unicode.InvalidUtf8 => e
  end

fun categorize(t: unicode.Text val): String val =>
  match t.dominant_script()
  | unicode.Script.latin    => "latin"
  | unicode.Script.cyrillic => "cyrillic"
  | unicode.Script.han      => "han"
  | unicode.Script.unknown  => "unknown"
  // … exhaustive match — compiler enforces handling of new scripts
  end
```

### I. Codepoint/grapheme by position

```pony
fun first_emoji(t: unicode.Text val): (String val | None) =>
  for g in t.graphemes() do
    if unicode.Graphemes.is_emoji(g) then return g end
  end
  None

fun nth_codepoint(t: unicode.Text val, n: USize)
  : (unicode.Codepoint val | unicode.OutOfRange)
=>
  t.codepoint_at(unicode.CodepointIndex(n))

fun byte_at(t: unicode.Text val, n: USize): (U8 | unicode.OutOfRange) =>
  t.byte_at(unicode.ByteIndex(n))
```

### J. Codepoint properties

```pony
match unicode.Codepoint.from_u32(0x1F600)
| let cp: unicode.Codepoint val =>
  env.out.print(cp.name())                  // (String val | NoName)
  env.out.print(cp.category().iso())        // "So"
  env.out.print(cp.script().iso())          // "Zyyy" (Common)
  env.out.print(cp.is_emoji().string())     // "true"
| let e: unicode.InvalidScalar =>
  env.out.print(e.string())
end
```

### K. Compile-time correctness — illegal index mixing

```pony
t.grapheme_at(unicode.CodepointIndex(3))
// compile error: argument is CodepointIndex, expected GraphemeIndex
```

---

## 9. Criticality ordering

Single ordering, synthesizing the three persona proposals. v0.1 is the smallest *coherent useful slice* (you can count characters, validate, segment by grapheme, run codepoint property queries, and round-trip UTF-8) — closer to consumer-first's pragmatic v0.1 than to the skeptic's everything-at-once v0.1.

| Release | Theme | Surface added | Deps | Conformance gate |
|---|---|---|---|---|
| **v0.1** | "It correctly counts and segments characters" | `Text` (with optional bitmap index, §3.5) carrying UTF-8 validation and `_form = UnknownForm`; `Codepoint val` + `U32`-form predicates; graphemes-as-`String val`-slices (no `Grapheme` class); `Index[Kind]` family; `size_bytes/codepoints/graphemes`; `codepoints()`, `codepoint_scalars()`, `graphemes()`, `bytes()`; `codepoint_at`, `grapheme_at`, `byte_at`; `slice_codepoints`, `slice_graphemes`; `indexed()`, `unindexed()`; `eq_codepoints`, `+`; `Category` + `is_letter`/`is_digit`/`is_whitespace`; UCD: general category + grapheme break tables; topical primitives `Graphemes`, `Codepoints`, `Bytes` covering the v0.1 free-function surface | stdlib + generated UCD | `GraphemeBreakTest.txt` |
| **v0.2** | "It compares meaningfully" | `text.normalize(form)`, `text.is_normalized(form)`; `eq_normalized`; `eq_caseless`, `eq_caseless_normalized`; `to_upper`, `to_lower`, `to_title`, `case_fold` (full + locale-aware: `DefaultLocale | TurkicLocale | LithuanianLocale | AzerbaijaniLocale`); topical primitives `Normalize`, `Case`, `Compare`; UCD: normalization + case mappings + special-casing | v0.1 | `NormalizationTest.txt` |
| **v0.3** | "It segments and queries" | `text.words()`, `sentences()`, `lines()`; `text.scripts()`, `dominant_script()`, `ScriptSet.resolved()`; `Script` closed union (full ISO 15924); `Property` closed union; `cp.script()`, `cp.has_property(p)`, `grapheme.script()`; UCD: word/sentence/line break + script + ScriptExtensions + binary properties | v0.1 | `WordBreakTest.txt`, `SentenceBreakTest.txt`, `LineBreakTest.txt` |
| **v0.4** | "Encodings beyond UTF-8" | `Encoding` trait; `Utf8`, `Utf16Le`, `Utf16Be`, `Utf32Le`, `Utf32Be`, `Latin1`, `WindowsCp1252`, `Ascii`; `DecodePolicy`, `EncodePolicy`; `Bytes.detect_bom(b)?`; streaming `Decoder` objects | v0.1 | encoding conformance suites |
| **v0.5** | "Codepoint names" | Separate package `red/unicode/names`: `cp.name()` returns real name when imported; `Codepoint.from_name(s)?` | v0.1 | UCD `NameAliases.txt` |
| **v0.6** | "Locale-aware sort" | Separate package `red/unicode/collate`: `Collator` with `locale(s)?`, `locale_or_root(s)`, `root()`; `compare(a, b)`, `sort_key(t)`; strength / case-first / numeric / variable-weighting; DUCET + minimal CLDR | v0.2, v0.3 | UCA conformance |
| **v0.7** | "Security / confusables" | Separate package `red/unicode/confusables`: `Confusables.skeleton(t)`, `Confusables.are_confusable(a, b)`; `IdentifierProfile` (restricted / moderate / unrestricted) | v0.3 | UTS #39 test data |
| **v0.8** | "IDNA" | Separate package `red/unicode/idna` | v0.2, v0.5 | UTS #46 tests |
| **v0.9** | "Bidi" | UAX #9 bidirectional algorithm | v0.3 | UAX #9 tests |
| **v1.0** | "Stable surface" | API freeze; Unicode version pinned; full UCD conformance suite green | all above | — |

**Rationale for v0.1's scope**: It must be *usable on its own*. A v0.1 with codepoint queries but no graphemes can't even answer "how many visible characters" — the dominant Unicode question. A v0.1 with everything would slow the foundation we'll have to live with. Graphemes + property queries + segmentation by grapheme is the minimum *coherent* package. Normalization and case (v0.2) is the smallest separate concern, and a useful program can be written against v0.1 even without it.

---

## 10. Improvements over Raku

1. **Explicit construction at the boundary.** Raku auto-promotes everywhere. `Text.from_string(s)?` is a checkpoint; downstream code knows it's holding well-formed UTF-8. Costs one extra call; buys clarity.
2. **No NFG; optional bitmap index instead.** Raku's synthetic codepoints buy fast grapheme indexing at the cost of forcing a normalization+copy on construction and a private string representation that no other API can produce or consume. We keep UTF-8 storage and offer an **optional bitmap index** built at `Text` construction (`Text.from_string(s, indexed = true)`). The index is a 1-bit-per-byte grapheme-start bitmap (~12.5% memory overhead); lookups walk the bitmap with popcount — O(n/64), not constant-time but much faster than UAX #29 state-machine scanning. Pass-through workloads (HTTP, log processors) pay nothing for the index they don't use; workloads that index pay one O(n) construction walk for fast subsequent operations. Graphemes are zero-copy `String val` slices, directly usable by any Pony API.
3. **Honest normalization tag.** Raku silently normalizes (or doesn't, depending on subtype). We carry `_form: NormalForm` on every `Text`, defaulted to `UnknownForm`, never silently mutated.
4. **Closed unions instead of stringy enums.** Raku's `"Latin"`, `"Lu"` are strings — no exhaustive match. Our `Script.latin`, `Category.uppercase_letter` give the compiler something to check. A Unicode bump that adds a script becomes a compile error in code that did exhaustive matching — the *right* kind of breakage.
5. **Compile-time index discrimination.** Raku has the same byte/cp/grapheme footgun (mitigated by ops returning the right unit). We make passing a `ByteIndex` to a grapheme function a compile error.
6. **Errors as data, not exceptions.** Every fallible op returns a union containing concrete error primitives; full provenance preserved across layer boundaries without cross-layer wrappers.
7. **No global state for collation, normalization, or case locale.** Raku has implicit current-locale collation. Every collator and locale is explicit. Two parts of a program can't drift into different behavior.
8. **Strict vs substituting factories.** `Text.from_string(s)?` is strict; `Text.from_string_lossy(s)` substitutes U+FFFD per the W3C maximal-subpart algorithm. Raku throws on ill-formed UTF-8 — fine sometimes, wrong for log processors.
9. **Capability-aware adoption.** `Text.from_utf8_iso(consume bytes)` adopts an `iso` byte array without copying. Raku has no equivalent — strings always copy in.
10. **Honest about the names data.** Raku ships codepoint names with the runtime; we make them opt-in (~600 KB of strings) via a subpackage. Common case is smaller; the dependency is visible.
11. **Dual surface is intentional, not accidental.** Raku's surface is "everything is a method on `Str`." Ours says: typed `Text` is canonical; topical primitives (`Graphemes`, `Codepoints`, `Normalize`, `Case`, `Compare`, …) carry the same logic under problem-domain names; both surfaces delegate to one underscore implementation. First-class, single source of truth.

---

## 11. Adopted tensions (left open for human judgment)

### T1. (RESOLVED — kept as historical note.)

The original synthesis had a single `Strops` primitive lifting through `Text` ("lift; call; unlift"), which made the contract review-enforced. Revised in §2 to a topical-primitives design: each topical primitive (`Graphemes`, `Codepoints`, `Normalize`, `Case`, `Compare`, …) carries the logic in its underscore method; `Text.X` and the public `<Topic>.X` form both delegate to the same `<Topic>._X` method. The relationship is now compile-enforced — both surfaces call the same function — so behavior cannot drift. No PonyCheck cross-check needed (though one can still be added cheaply as a regression guard). The "Strops" name itself was also dropped — it was a solution-domain abbreviation ("string ops") with a misleading real-world meaning; topical primitives use problem-domain names instead.

### T2. (RESOLVED — graphemes are `String val` slices; no `Grapheme` class.)

The skeptic's argument prevailed: grapheme-ness isn't preserved by any operation, iterators yielding `String val` slices are directly usable by every Pony API, and a `Grapheme` class would cost one heap allocation per yielded cluster for no protective invariant. Grapheme-level queries (base, script, properties) are free functions on the `Graphemes` topical primitive (§4.3). The user's bitmap-index design reinforces this: iteration becomes "find next 1-bit in the bitmap, slice between consecutive 1-bits" — naturally yields slices.

### T3. `String val.trim` zero-copy assumption

The skeptic raised this and the synthesis relies on it: `Text.graphemes()`, `Text.words()`, etc. yield `Text val` slices. If stdlib `String val.trim` actually allocates (rather than sharing the underlying buffer), per-segment cost dominates. **Action item before committing to v0.1**: empirically verify with a small benchmark; if allocation is happening, either upstream a fix or restructure the iterator to yield `(start_byte: USize, end_byte: USize)` pairs with on-demand materialization.

### T4. Codepoint names subpackage activation mechanism

How does `red/unicode/names`, when imported, install its lookup into the core `Codepoint.name()` method? Options:
- **Global mutable hook** — a top-level primitive holds a `((Codepoint -> (String val | NoName)) | None)`; `names` sets it on first call. Violates "default to immutability" and creates initialization ordering hazards.
- **Names is a hard dep** — `cp.name()` always returns a real name (or `NoName` for unnamed codepoints). Forces ~600 KB into every consumer.
- **`Codepoint.name()` lives only in the `names` subpackage** as `Names.of(cp): (String val | NoName)`. Core doesn't expose `cp.name()` at all. Cleaner; needs API rearrangement.

**Synthesis tentatively picks the third** (no global hook; names is a separate API in its subpackage). **Surfaced for human judgment** because the consumer ergonomics differ noticeably.

### T5. Unicode version bumps and the closed `Script` union

A major Unicode release that adds a script changes the closed `Script` union. Code that exhaustively matched on `Script` will fail to compile against the new version. This is the *intentional* behavior (consumer-first explicitly chose this), but it's a real source-compat hazard for users.

Options:
- Accept it. Bumping Unicode is a breaking event; users update their match arms.
- Add `Script.unknown_other` (or similar) sink case to absorb new scripts. Weakens the safety we just bought.
- Mitigate by tooling: a codemod that pre-populates new `match` arms.

**Surfaced for human judgment** — call dictates the policy on Unicode bumps.

### T6. `Codepoint val` vs `U32` — split path adopted, but ergonomically asymmetric

The synthesized split (iterators yield both; `_scalar` suffix denotes U32 form) is verbose. Some users will reach for whatever Pony's auto-completion surfaces first, miss the perf implication, and pay allocation cost they didn't intend.

Mitigation: docs steer hot loops to `codepoint_scalars()` + `*_scalar` predicates; lint or PonyCheck-style property that "iterating with `codepoints()` and only calling boolean predicates" can be safely rewritten to the `_scalar` form. Not currently surfaced as a problem; flagged here so the doc story is part of the design, not an afterthought.

### T7. NormalForm tag on free-function results

When `Normalize.to(s, NFCForm)` returns a `String iso^`, the `String iso^` carries no `_form` tag — only `Text val` carries that field. A downstream `Compare.eq_normalized(...)` call has to either re-check the form or just re-normalize. This is the inherent cost of the free-function surface; the typed path doesn't pay it. **Documented, not resolved** — users who care about repeated normalization should stay in `Text`.

---

## 12. Integrated Result (synthesizer protocol)

### Approach (synthesizer's framing)

Single behavioral truth (`Text` and friends), exposed via two surfaces: typed and utility. Both are first-class per user constraint, with the utility view contractually defined as the un-lifted form of the typed view — so behavior cannot drift. The principle-checker's `Index[Kind]` is adopted as the central correctness mechanism. The skeptic's perf concern about codepoint allocation is resolved by a split path: iterators expose both `Codepoint val` (type-safe, allocating) and `U32` (hot-path, free), with parallel `_scalar`-suffixed predicates that take `U32`. Normalization is tracked as a `_form` tag on `Text` (principle-checker), defaulting to `UnknownForm` and never silently set (consumer-first refinement). Closed unions, build-time UCD, version-pinned releases, errors as disjoint primitives — all carried forward from the convergent core. v0.1 is the smallest *coherent useful* slice.

### Decisions retained (from all three personas)

- **No NFG** — all three.
- **UCD generated at build time, shipped resident** — all three.
- **One Unicode version per package release** — all three.
- **Closed unions for `Script`, `Category`, `Property`, errors** — all three.
- **Don't replace stdlib `String`** — all three.
- **Errors as union-of-primitives, no exceptions** — all three.
- **`Encoding` as separate concern from text processing** — all three.
- **Locale tailoring deferred** — all three.
- **Word/sentence/line break iterators yielding text slices** — all three.

### Decisions retained from one persona

- **`Index[Kind]` phantom-typed indices** — *principle-checker*. The orchestrator flagged this as the highest-value unique finding; adopted as the central correctness mechanism. Other personas didn't consider it.
- **`Text` carries a `_form: NormalForm` tag with `UnknownForm` default, no implicit normalization** — *principle-checker*. Adopted because it makes "this Text is NFC" a type-system fact when it matters, without forcing normalization on every construction.
- **Dual surface (`Text` + topical primitives over `String`)** — *principle-checker* (Strops design) and *consumer-first* (`Unicode.Bytes`). Synthesized into a topical-primitives design where both surfaces delegate to the same underscore methods (§2). The principle-checker's monolithic `Strops` was renamed to topical primitives (`Graphemes`, `Codepoints`, `Normalize`, `Case`, `Compare`, `Scripts`, `Bytes`, …) for problem-domain naming.
- **Total + strict construction factories** — *consumer-first* (`Text` vs `TextStrict`). Adopted: `Text.from_string(s)?` strict, `Text.from_string_lossy(s)` substituting.
- **`decode_total` on infallible codecs by convention, not separate trait** — *consumer-first*. Kept; polymorphic codec loops keep working uniformly.
- **`Bytes` primitive for pre-validation byte helpers** — *consumer-first* (`Unicode.Bytes`). Carried as the answer to "have raw bytes, want one cheap question."

### Decisions revised

- **Codepoint representation.** Consumer-first and principle-checker said `class val Codepoint`. Skeptic said `U32` for perf. *Synthesis*: both paths exist. `codepoints()` yields `Codepoint val` (type-safe), `codepoint_scalars()` yields `U32` (hot path). Parallel `_scalar`-suffixed predicates accept `U32`. Boundary code uses `Codepoint.from_u32(u)?`.
- **Grapheme representation.** Skeptic said `String val` slice. Others said `class val Grapheme`. *Synthesis*: initially tentatively `class val Grapheme`; revised after user input to `String val` slice (the skeptic's design). The user's optional-bitmap-index design reinforced this — iteration becomes "find next 1-bit, slice", which naturally yields slices. *T2 resolved.*
- **v0.1 scope.** Skeptic proposed everything-at-once v0.1. Consumer-first / principle-checker proposed layered v0.1 (count+segment) → v0.2 (normalize+case). *Synthesis*: kept the layered ordering. Rationale: v0.1 should be a *coherent useful slice* (graphemes + property queries works alone), and a wider v0.1 prematurely commits to surface we'd have to live with. v0.2 lands fast (small scope).
- **Identifier-fold ergonomics.** Consumer-first had `Text.identifier_fold()` as a one-call NFKC_Casefold convenience. *Synthesis*: collapsed into `eq_caseless_normalized(other, form, locale)` since equality is what callers actually want; the standalone fold is available via `t.normalize(NFKCForm).case_fold(...)`.
- **`Codepoint.from_u32` totality.** Consumer-first said partial (`?`). *Synthesis*: returns `(Codepoint val | InvalidScalar)` union (errors-as-data, not partial functions) — matches principle-checker and the rest of the error model.

### Decisions rejected

- **Replacing or extending stdlib `String`** — considered and rejected by all three.
- **Marker traits / open interfaces for error grouping** — Pony gotcha #9; all three rejected.
- **Structural `Stringy` interface bridging `String` and `Text`** — consumer-first explicitly rejected; principle-checker would have rejected on principle 12; skeptic had no `Text`. Confirmed rejection.
- **Per-iteration `Codepoint val` allocation as the only path** — skeptic's perf concern is concrete; rejected in favor of split path.
- **Implicit normalization on `Text` construction (Raku NFG-style)** — principle-checker explicitly rejected; consumer-first and skeptic neutral. Confirmed rejection.
- **String tags for `Script`/`Category`** — all three rejected.
- **Skeptic's v0.1 (everything-at-once)** — preserved skeptic's *items* across v0.1–v0.3 but rejected the all-at-v0.1 packaging.
- **Mandatory codepoint names in the core** — keeps the binary lean; names is opt-in.

### Tensions surfaced for human judgment

Listed and detailed in §11. Summary:

1. **T1** — RESOLVED by the logic-in-primitives revision in §2; kept as a historical note.
2. **T2** — RESOLVED: graphemes are `String val` slices; no `Grapheme` class.
3. **T3** — `String val.trim` zero-copy assumption; empirically verify before v0.1.
4. **T4** — How does the names subpackage install its lookup into core?
5. **T5** — Unicode bumps add scripts → break exhaustive matches. Policy needed.
6. **T6** — `Codepoint val` vs `U32` ergonomic asymmetry; doc story.
7. **T7** — free-function results don't carry `_form` tag; documented cost, not resolved.

### Agent contribution summary

- **Consumer-first**: surfaced the *boundary ergonomics* — strict-vs-lossy factories, `decode_total` convention, `Bytes` primitive for one-shot byte questions, the `Text` + utility-primitive coexistence. Caught: `has_property` semantic divergence between `Codepoint` and `Grapheme`.
- **Skeptic**: surfaced the *perf cliff* in per-codepoint allocation; the *invariant analysis* on `Grapheme` (cluster-ness isn't preserved by ops); the *interop cost* of any `Text` wrapper (every IO library would have to convert). Forced the synthesis to provide a U32 path. Also contributed the *topical primitives* layout (`Case`, `Normalize`, `Collate`, etc.) that the topical-primitives rename now adopts.
- **Principle-checker**: surfaced **`Index[Kind]`** — the single highest-value design move of the ensemble. Surfaced the explicit `_form` tag on `Text`. Surfaced the verification matrix that confirms each design choice maps to a principle.

The three attention focuses were genuinely decorrelated: consumer-first found the *ergonomic answers*, skeptic found the *cost analysis*, principle-checker found the *invariant-preserving mechanisms*. The synthesis composes all three without picking one.
