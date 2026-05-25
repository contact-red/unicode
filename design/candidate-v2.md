# Pony Unicode Package — Candidate v2

**Stage**: Post-Stage-2 candidate, all six tensions resolved, applicable Stage 2 adjustments folded in.
**Supersedes**: `candidate-v1.md`. See §14 for a delta against v1.

---

## 0. Approach (one paragraph)

The package is **dual-surface, single-truth, Unicode-correct text processing.** The canonical typed surface is `Text` (default cap `val`; can be constructed `iso`/`trn`/`ref` for build-mutably-then-freeze patterns). Topical primitives (`Graphemes`, `Codepoints`, `Search`, `Split`, `Trim`, `Replace`, `Insert`, `Delete`, `Normalize`, `Case`, `Compare`, `Scripts`, `Bytes`, …) expose the same logic as free functions over `String box`. Both surfaces delegate to package-private underscore methods on the topical primitives, so behavior cannot drift. `Text` carries the well-formed-UTF-8 invariant (checked at construction via `?` partial constructors) and an optional bitmap index for fast random grapheme access (opt-in at construction). No `_form` (normal-form) tag — explicit normalization is honest and avoids producer-claim-without-validator footguns. Codepoint iteration yields bare `U32` by default (no per-element allocation); `Codepoint val` is available for the type-safe boundary case. Iterators come in two flavors: convenience slice-yielding (`graphemes()`) and zero-alloc range-yielding (`grapheme_ranges()`). Closed unions for `Script`/`Category`/`Property`/error types — compile-enforced exhaustive matching, with Unicode-version bumps treated as semver-significant. UCD generated at build-time, compiled-in, version-pinned. First public release is `0.1.0` (covers what was internally v0.1+v0.2: validation + everyday ops + normalization + case-fold + comparison).

---

## 1. Type surface

### Findable union (used by all needle/separator/content parameters)

```pony
type Findable is (Text val | String box | Array[U8] box)
```

`box` is the most permissive read-only cap, so any caller can pass any of the three without conversion. Internal code matches once to extract bytes.

### Core types

| Type | Default cap | Semantic guarantee | Construction |
|---|---|---|---|
| `Text` | `val` | Well-formed UTF-8; optional bitmap index (§3.5) | `Text.create(len)` (empty mutable); `Text.from_string(s)?`, `from_array(a)?`, `from_iso_string(consume s)?`, `from_iso_array(consume a)?` — all partial functions, error on invalid UTF-8. Returns `iso^` so caller chooses cap. |
| `Codepoint` | `val` (wraps `U32`) | Valid Unicode scalar | `Codepoint.from_u32(u): (Codepoint val \| InvalidScalar)` |
| `ByteIndex` | val | Byte offset into a Text's UTF-8; bound to that Text | `t.byte_index(n)?` (range-checked); `Index._raw_byte(n)` package-private |
| `CodepointIndex` | val | Codepoint offset; bound to a Text | `t.codepoint_index(n)?` |
| `GraphemeIndex` | val | Grapheme offset; bound to a Text | `t.grapheme_index(n)?` |
| `Script` | closed union of primitives | ISO 15924 script | `Script.latin`, `Script.from_iso(s)?` |
| `Category` | closed union of primitives | General Category | `Category.uppercase_letter`, `Category.from_iso(s)?` |
| `Property` | closed union of primitives | Binary property tracked by package | `Property.alphabetic`, … |
| `NormalForm` | closed union of primitives | `NFCForm \| NFDForm \| NFKCForm \| NFKDForm` | direct primitives |
| `CaseLocale` | closed union of primitives | `DefaultLocale \| TurkicLocale \| LithuanianLocale \| AzerbaijaniLocale` | direct primitives |
| `ScriptSet` | `class val` | Set of `Script`; `.resolved()` drops Common/Inherited | `Scripts.of(t)` |
| `Encoding` | trait `val` | encode/decode | Implementations are primitives: `Utf8`, `Utf16Le`, `Utf16Be`, `Latin1`, … (`0.3.0`+) |
| `DecodePolicy` | closed union | `StrictPolicy \| ReplacePolicy` (no IgnorePolicy — see §11 dissolved tensions) | direct primitives |
| `EncodePolicy` | closed union | `StrictPolicy \| ReplacePolicy` | direct primitives |

### Topical primitives

| Primitive | Concern | Release |
|---|---|---|
| `Graphemes` | UAX #29 cluster ops over `String` | 0.1.0 |
| `Codepoints` | Codepoint-level ops over `String` | 0.1.0 |
| `Codepoint` | Single-codepoint factory + U32-based predicates | 0.1.0 |
| `Bytes` | Byte-level pre-validation helpers | 0.1.0 |
| `Search` | `contains`, `starts_with`, `ends_with`, `index_of` | 0.1.0 |
| `Split` | `iter`, `ranges` | 0.1.0 |
| `Text.join` | static method (primitive form on `Text`) | 0.1.0 |
| `Trim` | pure + in-place trim | 0.1.0 |
| `Replace` | pure + in-place substring replace | 0.1.0 |
| `Insert` | pure + in-place insertion at grapheme index | 0.1.0 |
| `Delete` | pure + in-place deletion at grapheme range | 0.1.0 |
| `Normalize` | NFC/NFD/NFKC/NFKD | 0.1.0 |
| `Case` | lower/upper/title/fold, locale-aware | 0.1.0 |
| `Compare` | `eq_normalized`, `eq_caseless`, `eq_caseless_normalized` | 0.1.0 |
| `Words`, `Sentences`, `Lines` | UAX #14 / UAX #29 break iterators | 0.2.0 |
| `Scripts` | `of`, `dominant`, `restrict_to` | 0.2.0 |
| `Confusables` | UTS #39 skeleton, `eq_identifier(profile)` | 0.6.0 |

### Errors

All error types are `class val` (Pony primitives cannot carry fields — see Adj-1). All implement `Stringable`.

| Type | Fields | Layer | When |
|---|---|---|---|
| `InvalidUtf8` | (none — partial constructor signals failure) | construction | `Text.from_string`/`from_array`/`from_iso_*` failed |
| `InvalidScalar` | `value: U32`, `kind: (SurrogateKind \| OutOfRangeKind)` | codepoint | `Codepoint.from_u32` failed |
| `OutOfRange` | `index: USize`, `size: USize` | indexing | `Index` past end |
| `AllValid` | (sentinel) | byte query | `Bytes.first_bad_utf8_offset` for fully-valid input |
| `DecodeError` | `offset: USize`, `kind: _DecodeKind`, `encoding_name: String val` | encoding (0.3.0+) | codec decode failed |
| `EncodeError` | `offset: USize` *(was `codepoint: Codepoint val` — changed per Adj-8 to avoid leaking sensitive content)*, `encoding_name: String val` | encoding | codec can't represent |
| `LocaleError` | `tag: String val` | collation (0.5.0+) | `Collator.locale(s)?` unknown tag |

Constructors use `?` partial functions for binary-failure cases (`Text.from_string(s)?`) — concise at call site; callers wanting offset/kind detail call `Bytes.first_bad_utf8_offset(s)` first. Runtime errors (decode, codepoint property, etc.) use union returns for full context preservation.

---

## 2. Typed / utility relationship

The user explicitly requires both views. The synthesis answer is **logic-in-primitives; both surfaces delegate**:

- **The Unicode logic lives in topical primitives** named after the operation domain. Each primitive has both a public (validating) form and a package-private underscore form (assumes valid).
- **`Text` is the typed wrapper.** Its methods carry the validated UTF-8 invariant by construction, so they call the underscore form directly and skip re-validation.
- **The same topical primitive serves both surfaces**: a free-function call validates first; a `Text` method call doesn't. No drift possible — both call the same function.

Concretely:

```pony
primitive Graphemes
  // Public, validates first
  fun count(s: String box): (USize | InvalidUtf8) =>
    if Bytes.is_valid_utf8(s) then _count(s)
    else InvalidUtf8 end

  // Package-private, the actual logic. Assumes valid UTF-8.
  fun _count(utf8: String box): USize =>
    var n: USize = 0
    let cursor = _GraphemeCursor.from_start(utf8)
    while cursor.advance() do n = n + 1 end
    n

class Text  // default cap val; can also be iso, trn, ref, box, tag
  let _utf8: String ref         // ref-typed field; view adapts to receiver cap
  var _index: (_TextIndex val | None)

  fun box size_graphemes(): USize =>
    Graphemes._count(_utf8)     // no re-validation, no wrapper allocation
```

### When to use each surface

| You have | You want | Use |
|---|---|---|
| Already a `Text` | any Unicode op | methods on `Text` |
| `String box` you'll touch **two or more times** | repeated Unicode ops | construct `Text` once; chained pipelines skip re-validation |
| `String box` + **one** cheap question | a single answer | `Graphemes.X(s)` / `Compare.X(s, ...)` / etc. |
| Raw bytes, known encoding | a `Text` | `Encoding.X.decode(b, policy)?` (0.3.0+) |
| `Array[U8] iso` you own (UTF-8) | a `Text`, zero byte-copy | `Text.from_iso_array(consume b)?` |
| `Text` to send out | bytes | `t.utf8_bytes()` or `Encoding.X.encode(t, policy)?` |
| Need to check raw bytes pre-validation | a single boolean / scan | `Bytes.X(b)` |

**Chained operations belong in `Text`.** Each step in `t.replace("  ", " ").trim().to_lower()` skips re-validation because the Text invariant holds. The free-function equivalent (`Case._lower(Trim._apply(Replace._apply(s, ...)))`) validates at each public boundary — fine for one-shot use, recurring cost for chains. The free-function surface is an *ergonomic* path, not a *perf* path.

### What we deliberately don't do

- **No structural `Stringy` interface** over `String` and `Text`. `.size()` would mean different things (bytes vs graphemes). Distinct semantics → distinct representations (principle 12).
- **No implicit normalization on construction.** `Text` does not carry a `_form` tag (see §11 / TN-B(c)). Callers normalize explicitly.

---

## 3. Index types

Phantom-typed indices prevent byte/codepoint/grapheme offsets from being mixed at compile time. Per Adj-2, the public construction route requires a `Text` (which lets the constructor range-check); the bare-`USize` constructor is package-private.

```pony
primitive _ByteIdx
primitive _CodepointIdx
primitive _GraphemeIdx

class val Index[Kind: (_ByteIdx | _CodepointIdx | _GraphemeIdx)]
  let _value: USize
  new val _raw(value: USize) => _value = value   // package-private; callers use Text methods
  fun value(): USize => _value
  fun eq(that: Index[Kind] box): Bool => _value == that._value
  fun lt(that: Index[Kind] box): Bool => _value < that._value
  fun add(n: USize): Index[Kind] => _raw(_value + n)

type ByteIndex      is Index[_ByteIdx]
type CodepointIndex is Index[_CodepointIdx]
type GraphemeIndex  is Index[_GraphemeIdx]
```

### How indices are constructed and used

```pony
class Text
  // Public construction — tied to a Text, range-checked
  fun box byte_index(n: USize): (ByteIndex | OutOfRange) =>
    if n <= _utf8.size() then Index[_ByteIdx]._raw(n) else OutOfRange(n, _utf8.size()) end
  fun box codepoint_index(n: USize): (CodepointIndex | OutOfRange)
  fun box grapheme_index(n: USize): (GraphemeIndex | OutOfRange)

  // Counting — distinct method per unit
  fun box size_bytes(): USize                        // O(1)
  fun box size_codepoints(): USize                   // indexed: O(1); else O(n)
  fun box size_graphemes(): USize                    // indexed: O(1); else O(n)

  // Indexing — argument kind enforces correctness
  fun box codepoint_at(i: CodepointIndex): (Codepoint val | OutOfRange)
  fun box grapheme_at(i: GraphemeIndex): (String val | OutOfRange)     // grapheme is a slice
  fun box byte_at(i: ByteIndex): (U8 | OutOfRange)

  // Slicing — no slice_bytes (would split UTF-8); cp/grapheme only
  fun box slice_codepoints(start: CodepointIndex, finish: CodepointIndex): (Text iso^ | OutOfRange)
  fun box slice_graphemes(start: GraphemeIndex, finish: GraphemeIndex): (Text iso^ | OutOfRange)

  // Explicit conversions between kinds — always need a Text
  fun box codepoint_index_of_byte(b: ByteIndex): (CodepointIndex | OutOfRange)
  fun box grapheme_index_of_codepoint(c: CodepointIndex): (GraphemeIndex | OutOfRange)
  fun box byte_index_of_grapheme(g: GraphemeIndex): ByteIndex

  // Index control
  fun box indexed(): Text iso^      // returns self with index materialized
  fun box unindexed(): Text iso^    // returns self with index dropped
  fun box is_indexed(): Bool
```

Footgun being prevented at compile time:

```pony
let s: Span[ByteIndex] = tokenizer.next()?
t.grapheme_at(s.start)
// ^ compile error if tokenizer returns ByteIndex but grapheme_at wants GraphemeIndex
```

The previous footgun (calling `GraphemeIndex(byte_offset)` with a raw `USize` from external context) is prevented by the package-private constructor — public callers must go through `t.grapheme_index(n)?` which range-checks against the right unit count.

The topical primitives do not expose `Index[Kind]` — they operate on whole strings or on `USize` offsets only when the unit is named in the method (e.g., `Graphemes.offset(s, n: USize)` returns the byte offset of the start of grapheme `n`).

### 3.5 The optional bitmap index

UTF-8 storage is the right default — zero byte-copy adoption from `String val`, zero byte-copy slices out as `String val`. The cost is that random grapheme access is O(n) without help.

The package adds an **optional bitmap index** that the caller opts into at `Text` construction. Per the storage rule:

```pony
class val _TextIndex
  let _gr_starts: _BitVec val   // 1 bit per UTF-8 byte: is this byte a grapheme start?
  let _gr_count:  USize          // popcount of _gr_starts
  let _cp_count:  USize          // popcount of the implicit codepoint-start bitmap
                                 // (derivable per-byte via (b & 0xC0) != 0x80; cached only)

class Text
  let _utf8:  String ref
  var _index: (_TextIndex val | None)
```

**What's stored, and why:**
- `_gr_starts` (1 bit/byte). Genuinely new information — UAX #29 grapheme breaks require running a state machine.
- `_gr_count`, `_cp_count`. Cached popcounts; make `size_graphemes()` / `size_codepoints()` O(1).
- **No rank/select tables.** Lookup is O(n/64) bitmap scan, not true O(1). Simpler, smaller; rank/select can be added later in a separate variant if needed.

**Memory cost:** ~`n/8` bytes for the bitmap, plus two `USize` counts. ~12.5% overhead.

**Construction cost:** one O(n) walk applying UAX #29, identical to `size_graphemes()` on a non-indexed Text.

**Index propagation (Adj-10):** operations returning a derived `Text` (`slice_graphemes`, `slice_codepoints`, `+`, `to_lower`, `trim`, …) **do NOT inherit the parent's index** by default. Caller calls `.indexed()` on the result if they want it. Inverts the previous default; saves index-rebuild cost in pipelines.

**Slice index integrity (Adj-20):** `slice_codepoints` always returns `_index = None` (cuts may fall mid-grapheme; inherited index would be wrong). `slice_graphemes` may inherit because its cuts are grapheme-aligned.

**Iteration speedup (Adj-14):** Non-indexed `Text.graphemes()` uses the UAX #29 state machine directly (O(1) per element from the start, friendly to short-prefix patterns like truncate-to-N). Only `Text.indexed()` materializes a stored bitmap. No "local bitmap during iteration" — that penalized short-prefix iteration.

**Complexity table (Adj-12):** All grapheme-random-access ops are O(n) asymptotically; the index makes them 64× faster, not constant-time. Documentation states "O(n), 64× faster than unindexed" rather than the misleading "O(n/64) vs O(n)" notation.

---

## 4. Codepoint representation

### 4.1 `Codepoint val` as a validated wrapper

```pony
class val Codepoint
  let _scalar: U32

  new val _create(scalar: U32) => _scalar = scalar     // package-private; invariant: caller has proved scalar validity

  fun scalar(): U32 => _scalar
  fun category(): Category
  fun script(): Script
  fun name(): (String val | NoName | NamesPackageNotLoaded)  // Adj-29
  fun is_letter(): Bool
  fun is_digit(): Bool
  fun is_whitespace(): Bool
  fun is_emoji(): Bool
  fun is_assigned(): Bool                              // TN-G4
  fun has_property(p: Property): Bool                  // implementation uses combined bitmap (Adj-15)
  fun numeric_value(): (F64 | NoNumericValue)
  fun simple_uppercase(): Codepoint val
  fun simple_lowercase(): Codepoint val
  fun simple_titlecase(): Codepoint val
  fun eq(that: Codepoint box): Bool
  fun lt(that: Codepoint box): Bool
  fun hash(): USize

primitive Codepoint
  // Factories
  fun from_u32(u: U32): (Codepoint val | InvalidScalar)
  // U32-form predicates — validate scalar then dispatch
  fun is_scalar(u: U32): Bool
  fun is_letter(u: U32): Bool =>
    if is_scalar(u) then _is_letter_unchecked(u) else false end
  fun is_digit(u: U32): Bool
  fun is_whitespace(u: U32): Bool
  fun is_assigned(u: U32): Bool
  fun is_emoji(u: U32): Bool
  fun has_property(u: U32, p: Property): Bool
  fun category(u: U32): Category
  fun script(u: U32): Script
  // Package-private hot-path forms — caller has already proved scalar validity
  fun _is_letter_unchecked(u: U32): Bool
  fun _category_unchecked(u: U32): Category
  // ...
```

The U32-form predicates check `is_scalar(u)` first and return false / Category.unassigned for non-scalars. The `_unchecked` variants assume validity for the hot iterator path. This resolves Wildcard S12 (predicates that "advertise safety they don't enforce"): the public predicates always return a sane answer; the `_unchecked` variants are called only by code that already validated.

### 4.2 Hot iteration uses `U32` directly (Adj-11)

The default-named iteration method yields the cheap form. Users opt into the typed form when they want it.

```pony
class Text
  // Default — cheap, no per-element heap allocation; yields valid scalars by construction
  fun box codepoints(): Iterator[U32]

  // Explicit typed form — one Codepoint val per element (allocates)
  fun box codepoints_typed(): Iterator[Codepoint val]

  fun box bytes(): Iterator[U8]
  fun box graphemes(): Iterator[String val]
  fun box grapheme_ranges(): Iterator[(USize, USize)]   // §11 / TN-F
```

**Invariant**: every `U32` yielded by `Text.codepoints()` is a valid scalar (the Text's UTF-8 was validated at construction). External code building `U32` from arithmetic, FFI, or external protocols must go through `Codepoint.from_u32(u)?` or `Codepoint.is_scalar(u)` to validate.

**Iterator capabilities (Adj-27):** Iterators are `ref` over the parent's data. Multiple actors holding the same `Text val` iterate independently with no shared state.

### 4.3 Storage is always `U32`; graphemes are `String val` slices

The split path is about *iteration*. Storage carries the same allocation concern more sharply: a single `Array[Codepoint val]` of N elements is N heap allocations *plus* the array's pointer array. **Anywhere the package stores codepoints in a collection, the element type is `U32`, not `Codepoint val`.**

**Graphemes are not a distinct type.** A grapheme cluster is a substring of UTF-8 bytes — a `String val` slice of the parent `Text`'s `_utf8`. Iterators yield `String val`; random access returns `String val`. Grapheme-level queries (base codepoint, script, properties) are free functions on the `Graphemes` topical primitive, not methods on a class.

```pony
primitive Graphemes
  // Operations on a single grapheme cluster — input is the slice yielded by Text.graphemes()
  fun base_scalar(cluster: String box): U32
  fun base(cluster: String box): Codepoint val
  fun codepoints(cluster: String box): Iterator[U32]
  fun codepoints_typed(cluster: String box): Iterator[Codepoint val]
  fun size_codepoints(cluster: String box): USize
  fun script(cluster: String box): Script
  fun has_property(cluster: String box, p: Property): Bool
  fun is_emoji(cluster: String box): Bool
```

---

## 5. Comparison and normalization

No `_form` tag on Text (per TN-B(c)). Normalization is explicit; callers control caching.

```pony
class Text
  fun box normalize(form: NormalForm): Text iso^                 // pure
  fun ref normalize_in_place(form: NormalForm)                   // mutator
  fun box is_normalized(form: NormalForm): Bool                  // UAX #15 quick-check (Adj-9: SIMD byte scan + cp scan)

  fun box to_lower(locale: CaseLocale = DefaultLocale): Text iso^
  fun box to_upper(locale: CaseLocale = DefaultLocale): Text iso^
  fun box to_title(locale: CaseLocale = DefaultLocale): Text iso^
  fun box case_fold(): Text iso^
  fun ref to_lower_in_place(locale: CaseLocale = DefaultLocale)
  fun ref to_upper_in_place(locale: CaseLocale = DefaultLocale)
  fun ref to_title_in_place(locale: CaseLocale = DefaultLocale)
  fun ref case_fold_in_place()

  fun box eq_codepoints(other: Findable): (Bool | InvalidUtf8)
  fun box eq_graphemes(other: Findable): (Bool | InvalidUtf8)
  fun box eq_normalized(other: Findable, form: NormalForm): (Bool | InvalidUtf8)
  fun box eq_caseless(other: Findable, locale: CaseLocale = DefaultLocale): (Bool | InvalidUtf8)
  fun box eq_caseless_normalized(
    other: Findable,
    form: NormalForm = NFKCForm,   // ← default per TN-D; was NFCForm
    locale: CaseLocale = DefaultLocale
  ): (Bool | InvalidUtf8)
```

**`eq_caseless_normalized` framing (TN-D resolution):** This method is case-insensitive normalized equality. Useful for display-string comparison, many identifier scenarios, and as a building block for higher-level matching. **It is NOT sufficient for security-critical identifier matching against homograph attacks** — see §12 "Identifier matching" and `eq_identifier` (lands with `Confusables` in `0.6.0`).

---

## 6. Search, split, join, trim, replace, insert, delete

Every Findable-taking method exists on both `Text` (validating-once invariant) and the topical primitive (validating per call). Mutator forms exist on `Text` and on the primitive's `in_place` form.

### Search (0.1.0)

```pony
class Text
  fun box contains(needle: Findable): (Bool | InvalidUtf8)
  fun box starts_with(prefix: Findable): (Bool | InvalidUtf8)
  fun box ends_with(suffix: Findable): (Bool | InvalidUtf8)
  fun box index_of(needle: Findable): ((GraphemeIndex | None) | InvalidUtf8)   // returns GraphemeIndex per TN-A Q3

primitive Search
  fun contains(haystack: String box, needle: Findable): (Bool | InvalidUtf8)
  fun starts_with(haystack: String box, prefix: Findable): (Bool | InvalidUtf8)
  fun ends_with(haystack: String box, suffix: Findable): (Bool | InvalidUtf8)
  fun index_of(haystack: String box, needle: Findable): ((GraphemeIndex | None) | InvalidUtf8)
  // _contains, _starts_with, _ends_with, _index_of — package-private, assume valid
```

### Split / Join (0.1.0)

```pony
class Text
  fun box split(delim: Findable): (Iterator[String val] | InvalidUtf8)
  fun box split_ranges(delim: Findable): (Iterator[(USize, USize)] | InvalidUtf8)   // per TN-F

primitive Split
  fun iter(haystack: String box, delim: Findable): (Iterator[String val] | InvalidUtf8)
  fun ranges(haystack: String box, delim: Findable): (Iterator[(USize, USize)] | InvalidUtf8)

primitive Text   // static method on the Text primitive
  fun join(separator: Findable, parts: ReadSeq[Findable] box): (Text iso^ | InvalidUtf8)
```

### Trim / Replace / Insert / Delete (0.1.0)

All take `Findable` for content. Trim chars match at the **grapheme** level (TN-A Q4) by byte equality after grapheme segmentation — callers wanting normalization-aware matching normalize both sides first.

```pony
class Text
  // Pure forms
  fun box trim(chars: (Findable | None) = None): (Text iso^ | InvalidUtf8)
  fun box trim_left(chars: (Findable | None) = None): (Text iso^ | InvalidUtf8)
  fun box trim_right(chars: (Findable | None) = None): (Text iso^ | InvalidUtf8)
  fun box replace(old: Findable, new: Findable): (Text iso^ | InvalidUtf8)
  fun box replace_first(old: Findable, new: Findable): (Text iso^ | InvalidUtf8)
  fun box insert_at(at: GraphemeIndex, content: Findable): (Text iso^ | InvalidUtf8 | OutOfRange)
  fun box delete_at(at: GraphemeIndex, count: USize): (Text iso^ | OutOfRange)

  // In-place mutators (require Text ref or higher)
  fun ref trim_in_place(chars: (Findable | None) = None): (None | InvalidUtf8)
  fun ref replace_in_place(old: Findable, new: Findable): (None | InvalidUtf8)
  fun ref replace_first_in_place(old: Findable, new: Findable): (None | InvalidUtf8)
  fun ref insert_at_in_place(at: GraphemeIndex, content: Findable): (None | InvalidUtf8 | OutOfRange)
  fun ref delete_at_in_place(at: GraphemeIndex, count: USize): (None | OutOfRange)

  // Byte-budget truncation (Adj-19) — distinct from slice_graphemes for callers who care about byte size
  fun box truncate_to_byte_budget(max_bytes: USize): Text iso^
```

Parallel topical primitives: `Trim`, `Replace`, `Insert`, `Delete` — each with `apply(s)` (validating) and `in_place(s)` (validating, mutating `String ref`) forms, both delegating to package-private underscore methods.

### Words / Sentences / Lines (0.2.0)

```pony
class Text
  fun box words(): (Iterator[String val] | InvalidUtf8)
  fun box sentences(): (Iterator[String val] | InvalidUtf8)
  fun box lines(): (Iterator[String val] | InvalidUtf8)
  fun box word_ranges(): (Iterator[(USize, USize)] | InvalidUtf8)
  fun box sentence_ranges(): (Iterator[(USize, USize)] | InvalidUtf8)
  fun box line_ranges(): (Iterator[(USize, USize)] | InvalidUtf8)

primitive Words
  fun iter(s: String box): (Iterator[String val] | InvalidUtf8)
  fun ranges(s: String box): (Iterator[(USize, USize)] | InvalidUtf8)
// same for Sentences, Lines
```

### Scripts (0.2.0)

```pony
class Text
  fun box scripts(): (ScriptSet | InvalidUtf8)
  fun box dominant_script(): (Script | InvalidUtf8)
  fun box contains_unassigned_codepoint(): (Bool | InvalidUtf8)   // TN-G4

class val ScriptSet
  fun size(): USize
  fun resolved(): ScriptSet val             // drops Common, Inherited
  fun contains(s: Script): Bool             // Adj-22
  fun to_array(): Array[Script] val

primitive Scripts
  fun of(s: String box): (ScriptSet | InvalidUtf8)
  fun dominant(s: String box): (Script | InvalidUtf8)
  fun restrict_to(s: String box, allowed: ScriptSet val): (Bool | InvalidUtf8)   // Adj-17 — moved to 0.2.0 so users have it before confusables
```

---

## 7. UCD strategy

- **Build-time generation**, runs at *library release time*, checked into the package source. Tool name: `unicode-build` (separate small Pony package; consumers don't depend on it at runtime).
- **Form**: two-stage radix tables (8-bit / 13-bit split, per Adj-15 perf guidance) for cp→property lookups; CCC + decomposition side tables; break properties as sorted range arrays (binary search); DUCET packed weighted strings (when collation lands).
- **Combined binary-property bitmap (Adj-15)**: stage-2 entries hold a per-codepoint bitmap of all tracked binary properties; `has_property(p)` is one bit-test, not a match dispatch.
- **Closed-union enumeration arrays (Adj-23)**: `unicode-build` emits `Script._all: Array[Script] val`, `Category._all: Array[Category] val`, `CaseLocale._all: Array[CaseLocale] val`, etc., alongside the variants. Tests can iterate all variants without drift; production code keeps its compile-checked exhaustive matching.
- **Output**: generated `.pony` source files defining `val` static tables. Compiled into the package; always resident. Projected size: ~1–5 MB for the core package.
- **One Unicode version per package release.** `Unicode.version(): UnicodeVersion` returns it; bumping is a release event. Unicode bumps that change closed-union membership (new `Script` or `Category`) are **semver-significant** (TN-G5) — labeled accordingly with explicit CHANGELOG entries.
- **Conformance gates (Adj-7 / Security F7 fix)**: each release is pipeline-gated on the relevant conformance suite (see §9 column "Conformance gate"). Pre-tag CI verifies; runtime `Unicode.self_check()` is opt-in for embedded callers who want startup verification.
- **`unicode-build` tests (G2 fix)**: the build tool ships its own test suite covering UCD-file parsing, range-table compression round-trip, and cross-checks against `DerivedCoreProperties.txt`.
- **Cold/large data in subpackages**:
  - `red/unicode/names` — codepoint names (~600 KB of strings) (lands `0.4.0`)
  - `red/unicode/collate` — DUCET + CLDR tailorings (`0.5.0`)
  - `red/unicode/confusables` — UTS #39 + `eq_identifier(profile)` (`0.6.0`)
  - `red/unicode/idna` — IDNA mapping (`0.7.0`)

---

## 8. Consumer sketches

Updated for the v2 API. Both `Text` and free-function forms shown where the choice is meaningful.

### A. Count visible characters

```pony
use unicode = "red/unicode"

actor Main
  new create(env: Env) =>
    let raw: String val = "café 🇫🇷👨‍👩‍👧"
    try
      let t = unicode.Text.from_string(raw)?
      env.out.print("graphemes:  " + t.size_graphemes().string())
      env.out.print("codepoints: " + t.size_codepoints().string())
      env.out.print("bytes:      " + t.size_bytes().string())
    else
      env.out.print("invalid UTF-8")
    end
```

Free-function form:
```pony
match unicode.Graphemes.count(raw)
| let n: USize => env.out.print("graphemes: " + n.string())
| let _: unicode.InvalidUtf8 => env.out.print("invalid UTF-8")
end
```

### B. Case-insensitive username compare (with TN-D guidance)

```pony
fun users_match_display(a: String box, b: String box): (Bool | unicode.InvalidUtf8) =>
  // Display equality — NOT safe for identifier matching against homograph attacks.
  // For identifier matching, see §12 and use eq_identifier (0.6.0+).
  try
    let ta = unicode.Text.from_string(a)?
    let tb = unicode.Text.from_string(b)?
    // Default form is NFKCForm — covers compatibility-form attacks (ligatures, fullwidth).
    ta.eq_caseless_normalized(tb)
  else
    unicode.InvalidUtf8
  end
```

For identifier matching after `0.6.0`:
```pony
fun users_match_identifier(a: String box, b: String box): (Bool | unicode.InvalidUtf8) =>
  use confusables = "red/unicode/confusables"
  try
    let ta = unicode.Text.from_string(a)?
    let tb = unicode.Text.from_string(b)?
    confusables.eq_identifier(ta, tb, confusables.IdentifierProfile.moderate)
  else
    unicode.InvalidUtf8
  end
```

### C. Truncate display name at character N

```pony
fun truncate(s: String box, max: USize): (String val | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    let limit = t.grapheme_index(max.min(t.size_graphemes()))?
    let cut = t.slice_graphemes(t.grapheme_index(0)?, limit) as unicode.Text val
    cut.utf8_bytes()
  else
    unicode.InvalidUtf8
  end
```

### D. Validate input: only letters and digits

Hot path (no per-codepoint allocation):
```pony
fun is_alnum(s: String box): (Bool | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    if t.size_codepoints() == 0 then return false end
    for u in t.codepoints() do        // yields U32, no alloc
      if not (unicode.Codepoint.is_letter(u) or unicode.Codepoint.is_digit(u))
      then return false end
    end
    true
  else
    unicode.InvalidUtf8
  end
```

### E. Build text mutably, then freeze for sharing

```pony
fun build_header(name: String box, value: String box): unicode.Text val ? =>
  let t = recover iso unicode.Text.from_string(name)? end   // Text iso
  t.insert_at_in_place(t.grapheme_index(t.size_graphemes())?, ": ")?
  t.insert_at_in_place(t.grapheme_index(t.size_graphemes())?, value)?
  consume t    // freeze to Text val for sharing across actors
```

### F. Search and split

```pony
fun parse_pairs(s: String box): (Map[String val, String val] | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    let map = Map[String val, String val]
    for line in t.split("\n")? do
      match unicode.Text.from_string(line)?.index_of("=")
      | let idx: unicode.GraphemeIndex =>
        // ...
      | None => continue
      end
    end
    map
  else
    unicode.InvalidUtf8
  end
```

### G. Hot-path range iteration on a large indexed text

```pony
fun count_emoji(t: unicode.Text val): USize =>
  // Range iteration avoids per-yield wrapper alloc
  var n: USize = 0
  let bytes = t.utf8_bytes()
  for (start, finish) in t.grapheme_ranges() do
    let cluster = bytes.trim(start, finish)
    if unicode.Graphemes.is_emoji(cluster) then n = n + 1 end
  end
  n
```

### H. Detect mixed scripts and restrict to allowed (security check, 0.2.0)

```pony
fun is_latin_only_identifier(s: String box): (Bool | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    let allowed = unicode.ScriptSet.of([unicode.Script.latin])
    unicode.Scripts.restrict_to(t.utf8_bytes(), allowed)
  else
    unicode.InvalidUtf8
  end

fun is_mixed_script(s: String box): (Bool | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    t.scripts().resolved().size() > 1   // resolved() drops Common, Inherited
  else
    unicode.InvalidUtf8
  end
```

### I. Codepoint by position

```pony
fun nth_codepoint(t: unicode.Text val, n: USize): (unicode.Codepoint val | unicode.OutOfRange) =>
  try t.codepoint_at(t.codepoint_index(n)?)
  else unicode.OutOfRange(n, t.size_codepoints())
  end
```

### J. Codepoint properties

```pony
match unicode.Codepoint.from_u32(0x1F600)
| let cp: unicode.Codepoint val =>
  env.out.print(cp.category().iso())
  env.out.print(cp.script().iso())
  env.out.print(cp.is_emoji().string())
  env.out.print(cp.is_assigned().string())   // TN-G4
  match cp.name()
  | let n: String val => env.out.print(n)
  | unicode.NoName => env.out.print("(unnamed)")
  | unicode.NamesPackageNotLoaded => env.out.print("(names package not imported)")
  end
| let e: unicode.InvalidScalar => env.out.print(e.string())
end
```

### K. Compile-time index discrimination

```pony
t.grapheme_at(t.codepoint_index(3)?)
// ^ compile error: argument is CodepointIndex, expected GraphemeIndex
```

---

## 9. Release plan

Renumbered per TN-C. First public release is `0.1.0`. The internal "v0.1" milestone (foundation only) is a non-released checkpoint.

| Release | Theme | Surface added | Deps | Conformance gate |
|---|---|---|---|---|
| `0.1.0` | "First public release: well-formed-UTF-8 text with everyday ops + normalize + case-fold + compare" | `Text` with constructors + optional bitmap index (§3.5); `Codepoint val` + `U32`-form predicates; graphemes-as-`String val`-slices; `Index[Kind]` family with `t.byte_index(n)?`/`t.codepoint_index(n)?`/`t.grapheme_index(n)?` construction; `size_bytes/codepoints/graphemes`; `codepoints()`, `codepoints_typed()`, `graphemes()`, `grapheme_ranges()`, `bytes()`; `codepoint_at`, `grapheme_at`, `byte_at`; `slice_codepoints`, `slice_graphemes`; `eq_codepoints`, `eq_graphemes`, `eq_normalized`, `eq_caseless`, `eq_caseless_normalized`; `Category` + predicates (`is_letter`/`is_digit`/`is_whitespace`/`is_emoji`/`is_assigned`); `Normalize`, `Case`, `Compare`, `Search`, `Split`, `Trim`, `Replace`, `Insert`, `Delete` topical primitives + matching `Text` methods (pure + in-place); `Text.join`; `Bytes.is_valid_utf8`, `Bytes.starts_with_bom`, `Bytes.first_bad_utf8_offset`; `unicode.version()`. UCD: general category + grapheme breaks + decomposition + composition + case mapping + binary properties as combined bitmap. | stdlib + generated UCD | `GraphemeBreakTest.txt`, `NormalizationTest.txt`, `SpecialCasing.txt` |
| `0.2.0` | "Segments and queries" | `Text.words/sentences/lines` + `*_ranges` variants; `Words`/`Sentences`/`Lines` primitives; `Text.scripts`, `dominant_script`, `contains_unassigned_codepoint`; `Script` closed union (full ISO 15924); `Scripts.of/dominant/restrict_to`; `cp.script()`, `cp.has_property(p)`; `ScriptSet.contains/to_array`; UCD: word/sentence/line break + script + ScriptExtensions | `0.1.0` | `WordBreakTest.txt`, `SentenceBreakTest.txt`, `LineBreakTest.txt` |
| `0.3.0` | "Encodings beyond UTF-8" | `Encoding` trait; `Utf8`, `Utf16Le`, `Utf16Be`, `Utf32Le`, `Utf32Be`, `Latin1`, `WindowsCp1252`, `Ascii`; `DecodePolicy = StrictPolicy \| ReplacePolicy` (no IgnorePolicy — Adj-7); `EncodePolicy = StrictPolicy \| ReplacePolicy`; `Bytes.detect_bom(b)?`; streaming `Decoder` objects | `0.1.0` | encoding conformance suites |
| `0.4.0` | "Codepoint names" | Subpackage `red/unicode/names`: `cp.name()` returns real name when imported; `Codepoint.from_name(s)?` | `0.1.0` | UCD `NameAliases.txt` |
| `0.5.0` | "Locale-aware sort" | Subpackage `red/unicode/collate`: `Collator.locale(s)?`, `Collator.locale_or_root(s)`, `Collator.root()`; `compare(a, b)`, `sort_key(t)`; DUCET + minimal CLDR | `0.1.0`, `0.2.0` | UCA conformance |
| `0.6.0` | "Security / confusables / safe identifier matching" | Subpackage `red/unicode/confusables`: `Confusables.skeleton(t)`; `Confusables.are_confusable(a, b)`; **`eq_identifier(a, b, profile: IdentifierProfile)`** (TN-D safe identifier primitive); `IdentifierProfile.restricted/moderate/unrestricted` | `0.2.0` | UTS #39 test data |
| `0.7.0` | "IDNA" | Subpackage `red/unicode/idna` | `0.1.0`, `0.4.0` | UTS #46 tests |
| `0.8.0` | "Bidi" | UAX #9 bidirectional algorithm | `0.2.0` | UAX #9 tests |
| `1.0.0` | "Stable surface" | API freeze; Unicode version pinned; full UCD conformance suite green | all above | — |

---

## 10. Improvements over Raku

1. **Explicit construction at the boundary.** Raku auto-promotes everywhere. `Text.from_string(s)?` is a checkpoint; downstream code knows it's holding well-formed UTF-8. Costs one extra call; buys clarity.
2. **No NFG; optional bitmap index instead.** Raku's synthetic codepoints buy fast grapheme indexing at the cost of forcing a normalization+copy on construction and a private string representation that no other API can produce or consume. We keep UTF-8 storage and offer an **optional bitmap index** built at `Text` construction. The index is a 1-bit-per-byte grapheme-start bitmap (~12.5% memory overhead); lookups walk the bitmap with popcount — O(n), 64× faster than unindexed, not constant-time but much faster than UAX #29 state-machine scanning. Pass-through workloads (HTTP, log processors) pay nothing for the index they don't use; workloads that index pay one O(n) construction walk for fast subsequent operations. Graphemes are zero-byte-copy `String val` slices (with one wrapper allocation per yield); range-yielding iterators (`grapheme_ranges()`) avoid even that for hot paths.
3. **Closed unions instead of stringy enums.** Raku's `"Latin"`, `"Lu"` are strings — no exhaustive match. Our `Script.latin`, `Category.uppercase_letter` give the compiler something to check. A Unicode bump that adds a script becomes a compile error in code that did exhaustive matching — the *right* kind of breakage (TN-G5: Unicode bumps are semver-significant).
4. **Compile-time index discrimination.** Raku has the same byte/cp/grapheme footgun (mitigated by ops returning the right unit). We make passing a `ByteIndex` to a grapheme function a compile error, and we make constructing the wrong-unit index harder (Adj-2: indices are constructed through a `Text` that range-checks).
5. **Errors as data, not exceptions.** Every fallible op returns a union containing concrete error primitives; full provenance preserved across layer boundaries without cross-layer wrappers. Construction uses `?` partial functions for concise call sites.
6. **No global state for collation, normalization, or case locale.** Raku has implicit current-locale collation. Every collator and locale is explicit. Two parts of a program can't drift into different behavior.
7. **Strict construction by default.** `Text.from_string(s)?` is strict — invalid UTF-8 fails the partial constructor. No lossy variant (security-positive: no silent substitution attacks).
8. **Capability-aware adoption.** `Text.from_iso_array(consume bytes)?` adopts an `iso` byte array without copying the buffer. Raku has no equivalent.
9. **Honest about the names data.** Raku ships codepoint names with the runtime; we make them opt-in (~600 KB of strings) via a subpackage. Common case is smaller; the dependency is visible.
10. **Honest about identifier matching.** Raku-style "compare with normalize+case-fold" passes for identifier matching but isn't actually safe (no confusables). We document the limits and reserve `eq_identifier(profile)` for the release that ships confusables (`0.6.0`). See §12.
11. **Build-mutably-then-freeze pattern.** `Text iso` constructors + `_in_place` mutators let callers build text up via insert/delete/replace/trim, then `consume` to `Text val` for sharing across actors. Same logic as `String iso` → `String val` in Pony stdlib.
12. **Newer-Unicode-input safety.** `cp.is_assigned()` and `t.contains_unassigned_codepoint()` let callers detect codepoints from Unicode versions newer than the bundled UCD, rather than silently misclassifying them as non-letters/non-digits (TN-G4).

---

## 11. Tensions: resolved and remaining

### Resolved during the post-Stage-2 user-steering pass

- **T1** (Strops contract review-enforced): RESOLVED in v1 via logic-in-primitives.
- **T2** (Grapheme as class vs slice): RESOLVED in v1 → slice.
- **TN-A** (general text processing vs Unicode correctness): RESOLVED → foundation is right; expand v0.1 with everyday text ops (search/split/join/trim/replace/insert/delete). All apply to both surfaces, take `Findable`. Mutator + pure forms on Text and on topical primitives.
- **TN-B** (wrapper vs no-wrapper, revisited): RESOLVED → option (c). Keep Text, **drop the `_form` tag**. Normalization is explicit; callers cache. Removes producer-claim-without-validator class of bug (Adversarial S3); removes "form tag lost in free-function path" tension (T7).
- **TN-C** (v0.1 ship-ability): RESOLVED → no v0.1 public release. Renumber for first public release: combined v0.1+v0.2 = `0.1.0`, etc.
- **TN-D** (eq_caseless_normalized unsafe for identifier matching): RESOLVED → default form changes from `NFCForm` to `NFKCForm`; framing stripped (no longer "the identifier-matching default"); reserve `eq_identifier(profile)` for `0.6.0` confusables release. New §12 documents identifier matching honestly.
- **TN-E** (dual-surface advice contradictory for chained ops): RESOLVED → option (b), document only. Chained pipelines belong in `Text`; free functions are an ergonomic path for one-shots, not a perf path. §2 carries this.
- **TN-F** (`String val.trim` zero-copy assumption): RESOLVED → option (a)+(b) combined. Slice-yielding iterators stay as the default; range-yielding variants (`grapheme_ranges()` etc.) added as the zero-allocation perf path. Verification action item: confirm `String val.trim` is wrapper-only (most likely) rather than full byte-copy.
- **TN-G1** (package name): RESOLVED → keep `unicode`.
- **TN-G2** (editing/building): RESOLVED → add `insert_at`/`delete_at` with both forms; no `TextBuilder` (Pony `String iso` covers it).
- **TN-G3** (Cursor abstraction): DEFERRED to a later release if real users ask.
- **TN-G4** (newer-Unicode silent corruption): RESOLVED → add `is_assigned()` predicates; document.
- **TN-G5** (closed Script union vs Unicode bumps): RESOLVED → accept; document Unicode bumps as semver-significant.

### Dissolved by other decisions

- **T7** (free-function results drop `_form` tag): dissolved by TN-B(c) — no tag exists.
- **Security F1** (`eq_caseless_normalized` as identifier default): resolved by TN-D.
- **Security F3** (`from_string_lossy` invisibility): dissolved by TN-A constructor list (no lossy variant).
- **Adversarial S1** (v0.1 unsafe equality): dissolved by TN-C (no v0.1 public release).
- **Adversarial S2** (`from_u32_or_replacement` launders scalars): dissolved by TN-A (function dropped).
- **Adversarial S3** (`_form` is producer claim with no validator): dissolved by TN-B(c).
- **Adversarial S4** (`Index[Kind]` bypassable via bare USize constructor): resolved by Adj-2 (package-private USize constructor; public path via `t.X_index(n)?`).
- **Adversarial G7** (`_form` propagation undefined per operation): dissolved by TN-B(c).
- **Wildcard S11** (5/11 scenarios in v0.1): dissolved by TN-C + TN-A — first public release is much broader.
- **Wildcard S17** (`primitive` with fields won't compile): resolved by Adj-1 — error types changed to `class val`.

### Remaining (open)

- **Verification action item from TN-F**: confirm `String val.trim` is wrapper-only (not full byte-copy) before implementation. If it copies bytes, internal iterator construction uses `String.create_from_pointer` or similar instead. The public API is insulated either way.

### New tensions surfaced during this revision

- *(none; all v2 changes are either user-steered decisions or mechanical fixes)*

---

## 12. Identifier matching

This section documents the package's stance on identifier matching honestly — what works at each release, what doesn't, and the recommended approach.

### What "identifier matching" requires

Per UTS #39 (Unicode Security Mechanisms) and RFC 8264 (PRECIS), safe identifier matching combines:

1. **NFKC normalization** (compatibility decomposition + canonical composition). Catches attacks using ligatures (`ﬃ` vs `ffi`), fullwidth forms (`Ａ` vs `A`), superscripts (`²` vs `2`), etc.
2. **Case folding** (full, not simple). Catches case-variation attacks. Locale-independent for identifiers.
3. **Confusables check** (UTS #39 skeleton). Catches homograph attacks where visually-identical characters from different scripts (`а` U+0430 Cyrillic vs `a` U+0061 Latin) would otherwise compare unequal.
4. **Script restrictions** (per `IdentifierProfile`). Rejects mixed-script identifiers that combine scripts the policy doesn't allow.

`eq_caseless_normalized(other, NFKCForm, DefaultLocale)` (the default) does (1) and (2). It does **not** do (3) or (4). It is therefore **not safe** as the only check for identifier matching against homograph attacks.

### Per-release recommendation

| Release | Use case | Recommended primitive | Safety status |
|---|---|---|---|
| `0.1.0` – `0.5.0` | Display-string equality | `t.eq_caseless_normalized(other)` (default NFKCForm) | Safe for display; NOT safe for identifier matching against homograph attacks. |
| `0.1.0` – `0.5.0` | Identifier matching | **No fully-safe primitive available.** See "What to do before `0.6.0`" below. | Caller must accept the gap. |
| `0.6.0`+ | Identifier matching | `Confusables.eq_identifier(a, b, profile)` (in `red/unicode/confusables`) | Safe per UTS #39 + RFC 8264. |

### What to do before `0.6.0`

If your release schedule requires identifier matching before `0.6.0`:

- **Option 1: Defer the use case** until `0.6.0` lands.
- **Option 2: Restrict the input space.** Reject input containing any codepoint outside `Property.alphabetic` + ASCII digits + an explicit set of allowed punctuation. Combined with `Scripts.restrict_to(s, allowed)` (`0.2.0`+) to limit to a specific script. This reduces the homograph attack surface dramatically without fully eliminating it.
- **Option 3: Compose what's available.** Apply `t.normalize(NFKCForm).case_fold()` then `eq_codepoints`. Acknowledge in your codebase that this is incomplete identifier matching. Do not market it as safe to users.

The package itself ships option (2)'s building blocks (`Scripts.restrict_to` in `0.2.0`) and option (3)'s composition primitives (all in `0.1.0`). It deliberately does not ship a partial-identifier-matching primitive that looks safe but isn't.

---

## 13. Migration from stdlib `String`

Pony's stdlib `String` is documented UTF-8 but never validates. `Text` adds the validation invariant plus Unicode-aware operations. Migration paths:

| You have | You want | How |
|---|---|---|
| `String val` | `Text val` | `Text.from_string(s)?` |
| `String iso` | `Text iso` (zero byte-copy adoption) | `Text.from_iso_string(consume s)?` |
| `Array[U8] val` | `Text val` | `Text.from_array(a)?` |
| `Array[U8] iso` | `Text iso` (zero byte-copy) | `Text.from_iso_array(consume a)?` |
| `Text val` | `String val` (round-trip out) | `t.utf8_bytes()` (cheap; shares the underlying buffer) |
| `Text` to feed a `String`-taking API | `String val` view | `t.utf8_bytes()` |

**One-shot work**: if you have a `String box` and want a single Unicode answer, use the topical primitive (`Graphemes.count(s)`, `Search.contains(s, needle)`, etc.) without wrapping. Each call validates UTF-8.

**Repeated work**: if you'll perform two or more Unicode operations on the same input, wrap once with `Text.from_string(s)?` and chain on the result. Subsequent operations skip re-validation.

**Round-trip caveat**: `Text → String → Text` is cheap but the second `from_string` re-validates. This is intentional — once you've handed bytes to code that takes `String box`, those bytes are once again "from outside the package" and need re-validation at re-entry.

---

## 14. Delta against `candidate-v1.md`

For readers who reviewed v1:

| v1 element | v2 status |
|---|---|
| `Text` with `_form: NormalForm` field | **removed** — TN-B(c) |
| `Text.normal_form()` accessor (suggested in Adj-3) | not added — moot without `_form` |
| `Text.from_string_lossy` | **removed** — TN-A constructor list |
| `Text.from_codepoint_scalars` | **removed** — TN-A Q2 |
| `Text.from_codepoint` | **removed** — TN-A Q2 |
| `Text.decode` as Text constructor | **moved** to `Encoding.X.decode(b, policy)?` in `0.3.0` |
| `Codepoint.from_u32_or_replacement` | **removed** — Adj-5 |
| `eq_caseless_normalized` default `NFCForm` | **changed** to `NFKCForm` — TN-D |
| `eq_caseless_normalized` "identifier-matching default" framing | **removed** — TN-D; see §12 |
| Phantom `Index[Kind]` public USize constructor | **package-private** — Adj-2; public via `t.X_index(n)?` |
| `Codepoint` class methods + `_scalar`-suffixed primitive predicates | **renamed**: `codepoints()` now yields `U32` by default; predicates lose `_scalar` suffix; unsafe internal forms have `_unchecked` suffix — Adj-11, Adj-16 |
| `IgnorePolicy` in DecodePolicy | **removed** — Adj-7 (Security F2) |
| `EncodeError.codepoint: Codepoint val` | **changed** to `offset: USize` — Adj-8 (Security F5) |
| Index propagation default "inherit on derived ops" | **inverted** to "do NOT inherit by default" — Adj-10 |
| `slice_codepoints` index inheritance | **always None** — Adj-20 |
| Error types as `primitive` with fields | **changed** to `class val` — Adj-1 (Wildcard S17) |
| Iterators yield slices only | **added** `*_ranges()` variants — TN-F |
| `class val Grapheme` | already removed in v1 (T2) |
| Constructors return unions on UTF-8 failure | **changed** to `?` partial functions — TN-A Q1 |
| New: `Text.create(len)` empty constructor | added |
| New: `Text.from_iso_string`, `from_iso_array` zero-byte-copy adoption | added |
| New: `Search`, `Split`, `Trim`, `Replace`, `Insert`, `Delete` primitives + Text methods | added — TN-A |
| New: `Text.join` static method | added — TN-A |
| New: `Text.truncate_to_byte_budget` | added — Adj-19 |
| New: `Findable` union type | added — TN-A |
| New: `Codepoint.is_assigned`, `Text.contains_unassigned_codepoint` | added — TN-G4 |
| New: `cp.name()` distinct `NoName` vs `NamesPackageNotLoaded` | added — Adj-29 |
| New: `ScriptSet.contains`, `to_array` | added — Adj-22 |
| New: `Scripts.restrict_to` (in `0.2.0`) | added — Adj-17 |
| New: `Bytes.first_bad_utf8_offset(s): (USize | AllValid)` | spec'd — Adj-21 |
| New: §12 "Identifier matching" | added — TN-D |
| New: §13 "Migration from stdlib String" | added — Adj-30 |
| New: combined binary-property bitmap (implementation guidance) | added — Adj-15 |
| New: `unicode-build` emits `_all` enumeration arrays | added — Adj-23 |
| New: package-private bitmap observability hooks for tests | added — Adj-25 |
| New: `Graphemes._is_break_at` for conformance tests | added — Adj-26 |
| New: iterator capability statement in §4.2 | added — Adj-27 |
| New: state-machine default for non-indexed iteration | added — Adj-14 |
| New: Renumbered releases (v0.1+v0.2 → 0.1.0, etc.) | applied — TN-C |
| Surface name `Strops` | already renamed in v1 → topical primitives |
| §11 tensions count: 7 open in v1 | reduced to 1 (`String val.trim` verification) |
