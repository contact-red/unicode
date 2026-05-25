# Pony Unicode Package — Candidate v3

**Stage**: Post-v2 review. All 15 H/M/L review findings resolved (one-by-one with user).
**Supersedes**: `candidate-v2.md`. See §14 for delta against v2; §15 for cumulative delta against v1.

---

## 0. Approach (one paragraph)

The package is **dual-surface, single-truth, Unicode-correct text processing.** The canonical typed surface is `Text` (default cap `val`; can be constructed `iso`/`trn`/`ref` for build-mutably-then-freeze patterns). Topical primitives (`Graphemes`, `Codepoints`, `Search`, `Split`, `Join`, `Trim`, `Replace`, `Concat`, `Insert`, `Delete`, `Normalize`, `Case`, `Compare`, `Scripts`, `Bytes`, …) expose the same logic as free functions over `String box`. Both surfaces delegate to package-private underscore methods on the topical primitives, so behavior cannot drift. `Text` carries the well-formed-UTF-8 invariant (checked at construction via `?` partial constructors) and an optional bitmap index for fast random grapheme access (opt-in at construction). No `_form` (normal-form) tag — explicit normalization is honest. Codepoint iteration yields bare `U32` by default (no per-element allocation); `Codepoint val` is available for the type-safe boundary case. Iterators come in two flavors: convenience slice-yielding (`graphemes()`) and zero-alloc range-yielding (`grapheme_ranges()`). Closed unions for `Script`/`Category`/`Property`/error types — compile-enforced exhaustive matching, with Unicode-version bumps treated as semver-significant. UCD generated at build-time, compiled-in, version-pinned. Codepoint names live in core (Pony's dead-code elimination strips unused tables at link time). First public release is `0.1.0`.

---

## 1. Type surface

### Type aliases

```pony
type Findable is (Text box | String box | Array[U8] box)
type ByteSeq  is (String box | Array[U8] box)
```

`Findable` covers any source of text-shaped bytes (string ops accept any of these). `ByteSeq` covers byte-only sources (pre-validation helpers). Both use `box` for maximum permissiveness — accepts any read cap.

### Core types

| Type | Default cap | Semantic guarantee | Construction |
|---|---|---|---|
| `Text` | `val` | Well-formed UTF-8; optional bitmap index (§3.5) | `Text.create(len)` (empty); `Text.from_string(s)?`, `from_array(a)?`, `from_iso_string(consume s)?`, `from_iso_array(consume a)?` — all partial functions, raise on invalid UTF-8 |
| `Codepoint` | `val` (wraps `U32`) | Valid Unicode scalar | Factory on `Codepoints` primitive: `Codepoints.from_u32(u): (Codepoint val \| InvalidScalar)` |
| `ByteIndex` | val | Byte offset into a Text; bound to that Text | `t.byte_index(n): (ByteIndex \| OutOfRange)` |
| `CodepointIndex` | val | Codepoint offset | `t.codepoint_index(n): (CodepointIndex \| OutOfRange)` |
| `GraphemeIndex` | val | Grapheme offset | `t.grapheme_index(n): (GraphemeIndex \| OutOfRange)` |
| `Script` | closed union of primitives | ISO 15924 script | `Script.latin`, `Script.from_iso(s)?` |
| `Category` | closed union of primitives | General Category | `Category.uppercase_letter`, `Category.from_iso(s)?` |
| `Property` | closed union of primitives | Binary property tracked by package | `Property.alphabetic`, … |
| `NormalForm` | closed union of primitives | `NFCForm \| NFDForm \| NFKCForm \| NFKDForm` | direct primitives |
| `CaseLocale` | closed union of primitives | `DefaultLocale \| TurkicLocale \| LithuanianLocale \| AzerbaijaniLocale` | direct primitives |
| `ScriptSet` | `class val` | Set of `Script`; `.resolved()` drops Common/Inherited | `Scripts.of(t)` |
| `Encoding` | trait `val` | encode/decode | Implementations are primitives: `Utf8`, `Utf16Le`, `Utf16Be`, `Latin1`, … (`0.3.0`+) |
| `DecodePolicy` | closed union | `StrictPolicy \| ReplacePolicy` | direct primitives |
| `EncodePolicy` | closed union | `StrictPolicy \| ReplacePolicy` | direct primitives |

### Topical primitives

| Primitive | Concern | Release |
|---|---|---|
| `Graphemes` | UAX #29 cluster ops over `String` | 0.1.0 |
| `Codepoints` | Codepoint factories, U32-form predicates, String-level codepoint ops | 0.1.0 |
| `Bytes` | Byte-level pre-validation helpers (UTF-8 validity, offset) | 0.1.0 |
| `Search` | `contains`, `starts_with`, `ends_with`, `index_of` | 0.1.0 |
| `Split` | `iter`, `ranges` | 0.1.0 |
| `Join` | string assembly from parts (M2 resolution) | 0.1.0 |
| `Concat` | `+` operator implementation (H3) | 0.1.0 |
| `Trim` | pure + in-place trim | 0.1.0 |
| `Replace` | pure + in-place substring replace | 0.1.0 |
| `Insert` | pure + in-place insertion at grapheme index | 0.1.0 |
| `Delete` | pure + in-place deletion at grapheme range | 0.1.0 |
| `Normalize` | NFC/NFD/NFKC/NFKD | 0.1.0 |
| `Case` | lower/upper/title/fold, locale-aware | 0.1.0 |
| `Compare` | `eq_normalized`, `eq_caseless`, `eq_caseless_normalized` | 0.1.0 |
| `Words`, `Sentences`, `Lines` | UAX #14 / UAX #29 break iterators | 0.2.0 |
| `Scripts` | `of`, `dominant`, `restrict_to` | 0.2.0 |
| `Confusables` | UTS #39 skeleton, `eq_identifier(profile)` | 0.5.0 (was 0.6.0 in v2; shifted by names move per H1) |

### Errors

All error types are `class val` (Pony primitives cannot carry fields). All implement `Stringable`.

| Type | Fields | Layer | When |
|---|---|---|---|
| `InvalidUtf8` | (none — partial constructor raises) | construction | `Text.from_string`/`from_array`/`from_iso_*` failed |
| `InvalidScalar` | `value: U32`, `kind: (SurrogateKind \| OutOfRangeKind)` | codepoint | `Codepoints.from_u32` failed |
| `UnknownName` | `name: String val` | codepoint | `Codepoints.from_name` failed (H1) |
| `NoName` | (none) | codepoint | `cp.name()` for unnamed codepoints (control chars, private-use, unassigned) |
| `OutOfRange` | `index: USize`, `size: USize` | indexing | `Index` past end |
| `AllValid` | (sentinel) | byte query | `Bytes.first_bad_utf8_offset` for fully-valid input |
| `DecodeError` | `offset: USize`, `kind: _DecodeKind`, `encoding_name: String val` | encoding (0.3.0+) | codec decode failed |
| `EncodeError` | `offset: USize`, `encoding_name: String val` | encoding | codec can't represent codepoint at offset |
| `LocaleError` | `tag: String val` | collation (0.4.0+) | `Collator.locale(s)?` unknown tag |
| `NoBom` | (none) | encoding (0.3.0+) | `Bytes.detect_bom` found no BOM |

Constructors use `?` partial functions for binary-failure cases. Method-level errors with useful context use union returns. (Pony language constraint: constructors can be total or partial; only methods can return unions.)

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
| `Text` to send out | bytes | `t.utf8_bytes()` (clones; see H4) or `Encoding.X.encode(t, policy)?` |
| Need to check raw bytes pre-validation | a single boolean / scan | `Bytes.X(b)` |

**Chained operations belong in `Text`.** Each step in `t.replace("  ", " ").trim().to_lower()` skips re-validation because the Text invariant holds. The free-function equivalent validates at each public boundary — fine for one-shot use, recurring cost for chains. The free-function surface is an *ergonomic* path, not a *perf* path.

### What we deliberately don't do

- **No structural `Stringy` interface** over `String` and `Text`. `.size()` would mean different things (bytes vs graphemes). Distinct semantics → distinct representations.
- **No implicit normalization on construction.** `Text` does not carry a `_form` tag. Callers normalize explicitly.

---

## 3. Index types

Phantom-typed indices prevent byte/codepoint/grapheme offsets from being mixed at compile time. The public construction route requires a `Text` (which lets the constructor range-check); the bare-`USize` constructor is package-private.

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
  // Public construction — tied to a Text, range-checked, returns union with context
  fun box byte_index(n: USize): (ByteIndex | OutOfRange)
  fun box codepoint_index(n: USize): (CodepointIndex | OutOfRange)
  fun box grapheme_index(n: USize): (GraphemeIndex | OutOfRange)

  // Counting
  fun box size_bytes(): USize                        // O(1)
  fun box size_codepoints(): USize                   // see §3.5 complexity table
  fun box size_graphemes(): USize

  // Indexing — argument kind enforces correctness
  fun box codepoint_at(i: CodepointIndex): (Codepoint val | OutOfRange)
  fun box grapheme_at(i: GraphemeIndex): (String val | OutOfRange)     // grapheme is a slice
  fun box byte_at(i: ByteIndex): (U8 | OutOfRange)

  // Slicing — no slice_bytes (would split UTF-8); cp/grapheme only
  // Equal indices return empty Text (success); reverse range returns OutOfRange (L2)
  fun box slice_codepoints(start: CodepointIndex, finish: CodepointIndex): (Text iso^ | OutOfRange)
  fun box slice_graphemes(start: GraphemeIndex, finish: GraphemeIndex): (Text iso^ | OutOfRange)

  // Explicit conversions between kinds
  fun box codepoint_index_of_byte(b: ByteIndex): (CodepointIndex | OutOfRange)
  fun box grapheme_index_of_codepoint(c: CodepointIndex): (GraphemeIndex | OutOfRange)
  fun box byte_index_of_grapheme(g: GraphemeIndex): ByteIndex

  // Index control
  fun box indexed(): Text iso^      // returns self with index materialized
  fun box unindexed(): Text iso^    // returns self with index dropped
  fun box is_indexed(): Bool

  // Bytes accessor (H4)
  fun box utf8_bytes(): String iso^   // clones _utf8; safe to mutate or transfer ownership

  // Concatenation (H3)
  fun box add(other: Findable): (Text iso^ | InvalidUtf8)
  fun ref add_in_place(other: Findable): (None | InvalidUtf8)
```

Footgun being prevented at compile time:

```pony
let s: Span[ByteIndex] = tokenizer.next()?
t.grapheme_at(s.start)
// ^ compile error if tokenizer returns ByteIndex but grapheme_at wants GraphemeIndex
```

The construction footgun (`GraphemeIndex(byte_offset)` from external context) is prevented by the package-private constructor — public callers must go through `t.grapheme_index(n)` which range-checks.

The topical primitives do not expose `Index[Kind]` — they operate on whole strings or on `USize` offsets only when the unit is named in the method (e.g., `Graphemes.offset(s, n: USize)` returns the byte offset of grapheme `n`).

### 3.5 The optional bitmap index

UTF-8 storage is the right default — zero byte-copy adoption from `String val`, zero byte-copy slices out as `String val`. The cost is that random grapheme access is O(n) without help.

The package adds an **optional bitmap index** that the caller opts into at `Text` construction.

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
- `_gr_count`, `_cp_count`. Cached popcounts.
- **No rank/select tables.** Lookup is bitmap scan via popcount; simpler, smaller.

**Memory cost:** ~`n/8` bytes for the bitmap, plus two `USize` counts. ~12.5% overhead.

**Construction cost:** one O(n) walk applying UAX #29.

**Index propagation:** operations returning a derived `Text` (`slice_graphemes`, `slice_codepoints`, `+`, `to_lower`, `trim`, …) **do NOT inherit the parent's index** by default. Caller calls `.indexed()` on the result if they want it. Saves index-rebuild cost in pipelines.

**Slice index integrity:** `slice_codepoints` always returns `_index = None` (cuts may fall mid-grapheme; inherited index would be wrong). `slice_graphemes` may rebuild because its cuts are grapheme-aligned, but per the default, doesn't unless explicitly asked.

**Iteration:** Non-indexed `Text.graphemes()` uses the UAX #29 state machine directly (O(1) per element from the start, friendly to short-prefix patterns like truncate-to-N). Only `Text.indexed()` materializes a stored bitmap.

### Complexity per operation (L5)

| Op | Non-indexed | Indexed |
|---|---|---|
| `size_bytes()` | O(1) | O(1) |
| `size_codepoints()` | O(n) | **O(1)** (cached count) |
| `size_graphemes()` | O(n) | **O(1)** (cached count) |
| `codepoint_at(k)`, `grapheme_at(k)` | O(n) | O(n), ~64× faster |
| `slice_codepoints(s, e)`, `slice_graphemes(s, e)` | O(e) | O(e), ~64× faster |
| `graphemes()` / `codepoints()` full iteration | O(n) total | O(n) total |
| `is_indexed()` | O(1) | O(1) |
| `indexed()` / `unindexed()` | O(n) to build/drop | O(1) |

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
  fun name(): (String val | NoName)                    // H1: lives in core; data subject to DCE
  fun is_letter(): Bool
  fun is_digit(): Bool
  fun is_whitespace(): Bool
  fun is_emoji(): Bool
  fun is_assigned(): Bool
  fun has_property(p: Property): Bool                  // single bitmap lookup
  fun numeric_value(): (F64 | NoNumericValue)
  fun simple_uppercase(): Codepoint val
  fun simple_lowercase(): Codepoint val
  fun simple_titlecase(): Codepoint val
  fun eq(that: Codepoint box): Bool
  fun lt(that: Codepoint box): Bool
  fun hash(): USize
```

### 4.2 The `Codepoints` primitive (M2 merger)

All factories, U32-form predicates, and String-level codepoint operations live on the plural `Codepoints` primitive. (The singular class `Codepoint` cannot coexist with a primitive of the same name — Pony language constraint.)

```pony
primitive Codepoints
  // Factories (single-codepoint construction)
  fun from_u32(u: U32): (Codepoint val | InvalidScalar)
  fun from_name(s: String box): (Codepoint val | UnknownName)            // H1

  // U32-form predicates (take a single U32; validate scalar then dispatch)
  fun is_scalar(u: U32): Bool
  fun is_letter(u: U32): Bool =>
    if is_scalar(u) then _is_letter_unchecked(u) else false end
  fun is_digit(u: U32): Bool
  fun is_whitespace(u: U32): Bool
  fun is_emoji(u: U32): Bool
  fun is_assigned(u: U32): Bool
  fun has_property(u: U32, p: Property): Bool
  fun category(u: U32): Category
  fun script(u: U32): Script

  // String-level (take a String box of UTF-8 codepoints)
  fun count(s: String box): (USize | InvalidUtf8)
  fun iter(s: String box): (Iterator[U32] | InvalidUtf8)
  fun iter_typed(s: String box): (Iterator[Codepoint val] | InvalidUtf8)
  fun is_all(s: String box, p: {(U32): Bool} val): (Bool | InvalidUtf8)

  // Package-private hot-path forms — caller has already proved scalar validity
  fun _is_letter_unchecked(u: U32): Bool
  fun _category_unchecked(u: U32): Category
  // ...
```

**Receiver-type signals scale:** functions taking `U32` operate on a single codepoint; functions taking `String box` operate on a string of codepoints. The plural name `Codepoints` covers both ("operations relating to codepoints").

The U32-form predicates check `is_scalar(u)` first and return false / Category.unassigned for non-scalars (rather than indexing into the property table at an out-of-range offset). The `_unchecked` variants assume validity for the hot iterator path.

### 4.3 Hot iteration uses `U32` directly

The default-named iteration method yields the cheap form. Users opt into the typed form when they want it.

```pony
class Text
  // Default — cheap, no per-element heap allocation; yields valid scalars by construction
  fun box codepoints(): Iterator[U32]

  // Explicit typed form — one Codepoint val per element (allocates)
  fun box codepoints_typed(): Iterator[Codepoint val]

  fun box bytes(): Iterator[U8]
  fun box graphemes(): Iterator[String val]
  fun box grapheme_ranges(): Iterator[(USize, USize)]
```

**Invariant**: every `U32` yielded by `Text.codepoints()` is a valid scalar (the Text's UTF-8 was validated at construction). External code building `U32` from arithmetic, FFI, or external protocols must go through `Codepoints.from_u32(u)` or `Codepoints.is_scalar(u)` to validate.

**Iterator capabilities:** Iterators are `ref` over the parent's data. Multiple actors holding the same `Text val` iterate independently with no shared state.

### 4.4 Storage is always `U32`; graphemes are `String val` slices

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

  // String-level
  fun count(s: String box): (USize | InvalidUtf8)
  fun iter(s: String box): (Iterator[String val] | InvalidUtf8)
  fun ranges(s: String box): (Iterator[(USize, USize)] | InvalidUtf8)
  fun offset(s: String box, n: USize): (USize | OutOfRange | InvalidUtf8)
```

---

## 5. Comparison and normalization

No `_form` tag on Text. Normalization is explicit; callers control caching.

```pony
class Text
  fun box normalize(form: NormalForm): Text iso^                 // pure
  fun ref normalize_in_place(form: NormalForm)                   // mutator (no validation needed)
  fun box is_normalized(form: NormalForm): Bool                  // UAX #15 quick-check (SIMD byte scan + cp scan)

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
    form: NormalForm = NFKCForm,
    locale: CaseLocale = DefaultLocale
  ): (Bool | InvalidUtf8)
```

**`eq_caseless_normalized` framing:** This method is case-insensitive normalized equality. Useful for display-string comparison, many identifier scenarios, and as a building block for higher-level matching. **It is NOT sufficient for security-critical identifier matching against homograph attacks** — see §12 and `eq_identifier` (lands with `Confusables` in `0.5.0`).

---

## 6. Search, split, join, concat, trim, replace, insert, delete

Every Findable-taking method exists on both `Text` (validating-once invariant) and the topical primitive (validating per call). Mutator forms exist on `Text` and on the primitive's `in_place` form.

**Mutator return-type rule (M5):** Mutators that take a `Findable` parameter return `(None | InvalidUtf8 [| OutOfRange])` because input validation can reject the parameter. Mutators that only transform the receiver's existing bytes return implicit `None`. Mutators with a `GraphemeIndex` parameter that could be out-of-range return `(None | OutOfRange)`.

### Search (0.1.0)

```pony
class Text
  fun box contains(needle: Findable): (Bool | InvalidUtf8)
  fun box starts_with(prefix: Findable): (Bool | InvalidUtf8)
  fun box ends_with(suffix: Findable): (Bool | InvalidUtf8)
  fun box index_of(needle: Findable): ((GraphemeIndex | None) | InvalidUtf8)

primitive Search
  fun contains(haystack: String box, needle: Findable): (Bool | InvalidUtf8)
  fun starts_with(haystack: String box, prefix: Findable): (Bool | InvalidUtf8)
  fun ends_with(haystack: String box, suffix: Findable): (Bool | InvalidUtf8)
  fun index_of(haystack: String box, needle: Findable): ((GraphemeIndex | None) | InvalidUtf8)
```

### Split / Join (0.1.0)

```pony
class Text
  fun box split(delim: Findable): (Iterator[String val] | InvalidUtf8)
  fun box split_ranges(delim: Findable): (Iterator[(USize, USize)] | InvalidUtf8)

primitive Split
  fun iter(haystack: String box, delim: Findable): (Iterator[String val] | InvalidUtf8)
  fun ranges(haystack: String box, delim: Findable): (Iterator[(USize, USize)] | InvalidUtf8)

primitive Join
  fun apply(separator: Findable, parts: ReadSeq[Findable] box): (Text iso^ | InvalidUtf8)
  // Call site: Join(sep, parts) uses Pony's apply shorthand
```

### Concat (0.1.0) — `+` operator

```pony
class Text
  fun box add(other: Findable): (Text iso^ | InvalidUtf8)      // t1 + t2
  fun ref add_in_place(other: Findable): (None | InvalidUtf8)

primitive Concat
  fun apply(left: String box, right: Findable): (String iso^ | InvalidUtf8)
  fun in_place(left: String ref, right: Findable): (None | InvalidUtf8)
```

### Trim / Replace / Insert / Delete (0.1.0)

All take `Findable` for content. Trim chars match at the **grapheme** level by byte equality after grapheme segmentation.

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

  // Byte-budget truncation
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
  fun box contains_unassigned_codepoint(): (Bool | InvalidUtf8)

class val ScriptSet
  fun size(): USize
  fun resolved(): ScriptSet val             // drops Common, Inherited
  fun contains(s: Script): Bool
  fun to_array(): Array[Script] val

primitive Scripts
  fun of(s: String box): (ScriptSet | InvalidUtf8)
  fun dominant(s: String box): (Script | InvalidUtf8)
  fun restrict_to(s: String box, allowed: ScriptSet val): (Bool | InvalidUtf8)
```

---

## 7. UCD strategy

- **Build-time generation**, runs at *library release time*, checked into the package source. Tool name: `unicode-build` (separate small Pony package; consumers don't depend on it at runtime).
- **Form**: two-stage radix tables (8-bit / 13-bit split) for cp→property lookups; CCC + decomposition side tables; break properties as sorted range arrays (binary search); DUCET packed weighted strings (when collation lands).
- **Combined binary-property bitmap**: stage-2 entries hold a per-codepoint bitmap of all tracked binary properties; `has_property(p)` is one bit-test, not a match dispatch.
- **Closed-union enumeration arrays**: `unicode-build` emits `Script._all: Array[Script] val`, `Category._all: Array[Category] val`, `CaseLocale._all: Array[CaseLocale] val`, etc., alongside the variants. Tests can iterate all variants without drift; production code keeps its compile-checked exhaustive matching.
- **Output**: generated `.pony` source files defining `val` static tables. Compiled into the package; always resident. Projected size: ~1–5 MB for the core package.
- **Names data lives in core (H1).** `Codepoint.name()` and `Codepoints.from_name()` are part of `0.1.0`. The ~600 KB names table is embedded; Pony's monomorphization + LLVM dead-code elimination strips it at link time for programs that don't call `name()` or `from_name()`.
- **One Unicode version per package release.** `Unicode.version(): UnicodeVersion` returns it; bumping is a release event. Unicode bumps that change closed-union membership (new `Script` or `Category`) are **semver-significant** — labeled accordingly with explicit CHANGELOG entries.
- **Conformance gates**: each release is pipeline-gated on the relevant conformance suite (see §9). Pre-tag CI verifies; runtime `Unicode.self_check()` is opt-in for embedded callers who want startup verification.
- **`unicode-build` tests**: the build tool ships its own test suite covering UCD-file parsing, range-table compression round-trip, and cross-checks against `DerivedCoreProperties.txt`.
- **Cold/large data in subpackages**:
  - `red/unicode/collate` — DUCET + CLDR tailorings (`0.4.0`)
  - `red/unicode/confusables` — UTS #39 + `eq_identifier(profile)` (`0.5.0`)
  - `red/unicode/idna` — IDNA mapping (`0.6.0`)

---

## 8. Consumer sketches

All sketches use correct Pony syntax (H2 resolution):
- Partial constructors (`?`) are handled with `try`/`else` blocks
- Union returns are narrowed with `match` (or `as Type ?` for one-line "expect success or raise")

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

### B. Case-insensitive username compare

```pony
fun users_match_display(a: String box, b: String box): (Bool | unicode.InvalidUtf8) =>
  // Display equality — NOT safe for identifier matching against homograph attacks.
  // For identifier matching, see §12 and use eq_identifier (0.5.0+).
  try
    let ta = unicode.Text.from_string(a)?
    let tb = unicode.Text.from_string(b)?
    ta.eq_caseless_normalized(tb)   // default form is NFKCForm
  else
    unicode.InvalidUtf8
  end
```

For identifier matching after `0.5.0`:
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
fun truncate(s: String box, max: USize): (String iso^ | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    let n = max.min(t.size_graphemes())
    let zero = t.grapheme_index(0) as unicode.GraphemeIndex ?      // always succeeds for non-empty
    let limit = t.grapheme_index(n) as unicode.GraphemeIndex ?     // n <= size_graphemes() by min
    let cut = t.slice_graphemes(zero, limit) as unicode.Text val ?
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
      if not (unicode.Codepoints.is_letter(u) or unicode.Codepoints.is_digit(u))
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
  let t: unicode.Text iso = unicode.Text.from_string(name)?
  let end_idx = t.grapheme_index(t.size_graphemes()) as unicode.GraphemeIndex ?
  match t.insert_at_in_place(end_idx, ": ")
  | let _: None => None
  | let e: unicode.InvalidUtf8 => error
  | let e: unicode.OutOfRange => error
  end
  let end_idx2 = t.grapheme_index(t.size_graphemes()) as unicode.GraphemeIndex ?
  match t.insert_at_in_place(end_idx2, value)
  | let _: None => None
  | let e: unicode.InvalidUtf8 => error
  | let e: unicode.OutOfRange => error
  end
  consume t    // freeze to Text val for sharing across actors
```

A cleaner alternative using `+`:
```pony
fun build_header_pure(name: String box, value: String box): unicode.Text val ? =>
  let n = unicode.Text.from_string(name)?
  // Each step returns Text iso^; chain consumes through to val.
  ((n + ": ") as unicode.Text iso ?) + value as unicode.Text val ?
```

### F. Search and split

```pony
fun parse_pairs(s: String box): (Map[String iso^, String iso^] | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    let map = Map[String iso^, String iso^]
    let lines = t.split("\n") as Iterator[String val] ?
    for line in lines do
      try
        let line_t = unicode.Text.from_string(line)?
        match line_t.index_of("=")
        | let idx: unicode.GraphemeIndex =>
          let key = line_t.slice_graphemes(line_t.grapheme_index(0) as unicode.GraphemeIndex ?, idx) as unicode.Text val ?
          let after = (idx.add(1)) as unicode.GraphemeIndex
          let end_idx = line_t.grapheme_index(line_t.size_graphemes()) as unicode.GraphemeIndex ?
          let val_t = line_t.slice_graphemes(after, end_idx) as unicode.Text val ?
          map(key.utf8_bytes()) = val_t.utf8_bytes()
        | None => None
        end
      end
    end
    map
  else
    unicode.InvalidUtf8
  end
```

(Real code would extract the key/value extraction into a helper; the inline form shows the explicit Pony shape.)

### G. Hot-path range iteration on a large indexed text

```pony
fun count_emoji(t: unicode.Text val): USize =>
  // Range iteration avoids per-yield wrapper alloc
  var n: USize = 0
  let bytes = t.utf8_bytes()    // String iso^ via clone
  for (start, finish) in t.grapheme_ranges() do
    let cluster = bytes.trim(start, finish)
    if unicode.Graphemes.is_emoji(cluster) then n = n + 1 end
  end
  n
```

### H. Detect mixed scripts and restrict to allowed (0.2.0)

```pony
fun is_latin_only_identifier(s: String box): (Bool | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    let allowed = unicode.ScriptSet.of([unicode.Script.latin])
    unicode.Scripts.restrict_to(t.utf8_bytes(), allowed) as Bool ?
  else
    unicode.InvalidUtf8
  end

fun is_mixed_script(s: String box): (Bool | unicode.InvalidUtf8) =>
  try
    let t = unicode.Text.from_string(s)?
    (t.scripts() as unicode.ScriptSet ?).resolved().size() > 1
  else
    unicode.InvalidUtf8
  end
```

### I. Codepoint by position

```pony
fun nth_codepoint(t: unicode.Text val, n: USize): (unicode.Codepoint val | unicode.OutOfRange) =>
  match t.codepoint_index(n)
  | let idx: unicode.CodepointIndex => t.codepoint_at(idx)
  | let e: unicode.OutOfRange => e
  end
```

### J. Codepoint properties

```pony
match unicode.Codepoints.from_u32(0x1F600)
| let cp: unicode.Codepoint val =>
  env.out.print(cp.category().iso())
  env.out.print(cp.script().iso())
  env.out.print(cp.is_emoji().string())
  env.out.print(cp.is_assigned().string())
  match cp.name()
  | let n: String val => env.out.print(n)
  | unicode.NoName => env.out.print("(unnamed)")
  end
| let e: unicode.InvalidScalar => env.out.print(e.string())
end
```

### K. Compile-time index discrimination

```pony
match t.codepoint_index(3)
| let idx: unicode.CodepointIndex =>
  t.grapheme_at(idx)
  // ^ compile error: argument is CodepointIndex, expected GraphemeIndex
| let e: unicode.OutOfRange => /* handle */
end
```

---

## 9. Release plan

Renumbered after H1 moved names from `0.4.0` into `0.1.0`.

| Release | Theme | Surface added | Deps | Conformance gate |
|---|---|---|---|---|
| `0.1.0` | "First public release: well-formed-UTF-8 text with everyday ops + normalize + case-fold + compare + names" | `Text` with constructors + optional bitmap index; `Codepoint val` + `U32`-form predicates on `Codepoints` primitive; graphemes-as-`String val`-slices; `Index[Kind]` family with `t.byte_index(n)`/`t.codepoint_index(n)`/`t.grapheme_index(n)` construction; `size_bytes/codepoints/graphemes`; `codepoints()`, `codepoints_typed()`, `graphemes()`, `grapheme_ranges()`, `bytes()`; `codepoint_at`, `grapheme_at`, `byte_at`; `slice_codepoints`, `slice_graphemes`; `+`/`add`/`add_in_place`; `eq_codepoints`, `eq_graphemes`, `eq_normalized`, `eq_caseless`, `eq_caseless_normalized`; `Category` + predicates (`is_letter`/`is_digit`/`is_whitespace`/`is_emoji`/`is_assigned`); `cp.name()` + `Codepoints.from_name(s)`; `Normalize`, `Case`, `Compare`, `Search`, `Split`, `Join`, `Concat`, `Trim`, `Replace`, `Insert`, `Delete` topical primitives + matching `Text` methods (pure + in-place); `Bytes.is_valid_utf8`, `Bytes.first_bad_utf8_offset`; `unicode.version()`. UCD: general category + grapheme breaks + decomposition + composition + case mapping + binary properties as combined bitmap + codepoint names. | stdlib + generated UCD | `GraphemeBreakTest.txt`, `NormalizationTest.txt`, `SpecialCasing.txt`, `NameAliases.txt` |
| `0.2.0` | "Segments and queries" | `Text.words/sentences/lines` + `*_ranges` variants; `Words`/`Sentences`/`Lines` primitives; `Text.scripts`, `dominant_script`, `contains_unassigned_codepoint`; `Script` closed union (full ISO 15924); `Scripts.of/dominant/restrict_to`; `cp.script()`, `cp.has_property(p)`; `ScriptSet.contains/to_array`; UCD: word/sentence/line break + script + ScriptExtensions | `0.1.0` | `WordBreakTest.txt`, `SentenceBreakTest.txt`, `LineBreakTest.txt` |
| `0.3.0` | "Encodings beyond UTF-8" | `Encoding` trait; `Utf8`, `Utf16Le`, `Utf16Be`, `Utf32Le`, `Utf32Be`, `Latin1`, `WindowsCp1252`, `Ascii`; `DecodePolicy = StrictPolicy \| ReplacePolicy`; `EncodePolicy = StrictPolicy \| ReplacePolicy`; `Bytes.detect_bom(b): (Encoding val \| NoBom)`; streaming `Decoder` objects | `0.1.0` | encoding conformance suites |
| `0.4.0` | "Locale-aware sort" | Subpackage `red/unicode/collate`: `Collator.locale(s)?`, `Collator.locale_or_root(s)`, `Collator.root()`; `compare(a, b)`, `sort_key(t)`; DUCET + minimal CLDR | `0.1.0`, `0.2.0` | UCA conformance |
| `0.5.0` | "Security / confusables / safe identifier matching" | Subpackage `red/unicode/confusables`: `Confusables.skeleton(t)`; `Confusables.are_confusable(a, b)`; **`eq_identifier(a, b, profile: IdentifierProfile)`** (safe identifier primitive); `IdentifierProfile.restricted/moderate/unrestricted` | `0.2.0` | UTS #39 test data |
| `0.6.0` | "IDNA" | Subpackage `red/unicode/idna` | `0.1.0`, `0.2.0` (M6: not `0.4.0`/names) | UTS #46 tests |
| `0.7.0` | "Bidi" | UAX #9 bidirectional algorithm | `0.2.0` | UAX #9 tests |
| `1.0.0` | "Stable surface" | API freeze; Unicode version pinned; full UCD conformance suite green | all above | — |

---

## 10. Improvements over Raku

1. **Explicit construction at the boundary.** Raku auto-promotes everywhere. `Text.from_string(s)?` is a checkpoint; downstream code knows it's holding well-formed UTF-8.
2. **No NFG; optional bitmap index instead.** Raku's synthetic codepoints buy fast grapheme indexing at the cost of forcing a normalization+copy on construction and a private string representation. We keep UTF-8 storage and offer an **optional bitmap index** built at `Text` construction. The index is a 1-bit-per-byte grapheme-start bitmap (~12.5% memory overhead); lookups walk the bitmap with popcount — O(n), 64× faster than unindexed. Pass-through workloads pay nothing for the index they don't use. Graphemes are zero-byte-copy `String val` slices (with one wrapper allocation per yield); range-yielding iterators (`grapheme_ranges()`) avoid even that for hot paths.
3. **Closed unions instead of stringy enums.** Raku's `"Latin"`, `"Lu"` are strings — no exhaustive match. Our `Script.latin`, `Category.uppercase_letter` give the compiler something to check. A Unicode bump that adds a script becomes a compile error in code that did exhaustive matching — the *right* kind of breakage (Unicode bumps are semver-significant).
4. **Compile-time index discrimination.** Raku has the same byte/cp/grapheme footgun. We make passing a `ByteIndex` to a grapheme function a compile error, and we make constructing the wrong-unit index harder (indices are constructed through a `Text` that range-checks).
5. **Errors as data, not exceptions.** Methods return unions containing concrete error primitives. Constructors use `?` partials for binary fail/succeed (Pony language constraint).
6. **No global state for collation, normalization, or case locale.** Raku has implicit current-locale collation. Every collator and locale is explicit.
7. **Strict construction by default.** `Text.from_string(s)?` is strict — invalid UTF-8 fails. No lossy variant (security-positive: no silent substitution attacks).
8. **Capability-aware adoption.** `Text.from_iso_array(consume bytes)?` adopts an `iso` byte array without copying the buffer. Raku has no equivalent.
9. **Honest about identifier matching.** Raku-style "compare with normalize+case-fold" passes for identifier matching but isn't actually safe (no confusables). We document the limits and reserve `eq_identifier(profile)` for the release that ships confusables (`0.5.0`). See §12.
10. **Build-mutably-then-freeze pattern.** `Text iso` constructors + `_in_place` mutators let callers build text up via insert/delete/replace/trim, then `consume` to `Text val` for sharing across actors. Same logic as `String iso` → `String val` in Pony stdlib.
11. **Newer-Unicode-input safety.** `cp.is_assigned()` and `t.contains_unassigned_codepoint()` let callers detect codepoints from Unicode versions newer than the bundled UCD, rather than silently misclassifying them as non-letters/non-digits.
12. **Names data is pay-for-what-you-use.** Embedded in core, but Pony's monomorphization + LLVM dead-code elimination strips it for programs that don't use it. No subpackage activation complexity.

---

## 11. Tensions: resolved and remaining

### Resolved

All tensions previously listed in candidate-v2 §11. Plus the 15 H/M/L items from the v2 review:

- **H1** (NamesPackageNotLoaded doesn't work): resolved → names in core, DCE handles unused.
- **H2** (Pony syntax in sketches): resolved → spec pattern is forced by Pony; sketches rewritten with correct syntax.
- **H3** (`+` operator undefined): resolved → `add`/`add_in_place` on Text via `Concat` primitive.
- **H4** (`utf8_bytes`/`create` missing): resolved → both added; `utf8_bytes()` returns `String iso^` via clone.
- **M1** (Findable too restrictive): resolved → `Text box` (not val).
- **M2** (class/primitive name collision): resolved → `Join` primitive; `Codepoints` primitive absorbs codepoint factories + U32 predicates.
- **M3** (construction signature inconsistency): dissolved by H2.
- **M4** (BOM functions): resolved → drop `starts_with_bom`; only `detect_bom` in 0.3.0.
- **M5** (mutator return types): resolved → keep as-is; document the rule.
- **M6** (IDNA dep): resolved → `0.1.0, 0.2.0`.
- **L1** (Bytes parameter types): resolved → `ByteSeq` union type.
- **L2** (slice edge cases): resolved → equal indices → empty; reverse → OutOfRange.
- **L3** (`create` cap notation): no change; standard Pony convention.
- **L4** (Codepoint coexistence): dissolved by M2.
- **L5** (complexity table): resolved → per-op table in §3.5.

### Remaining (open)

- **`String val.trim` verification**: confirm `String val.trim` is wrapper-only (not full byte-copy) before implementation. If it copies bytes, internal iterator construction uses `String.create_from_pointer` or similar instead. The public API is insulated either way.

### New tensions surfaced during this revision

*(none)*

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
| `0.1.0` – `0.4.0` | Display-string equality | `t.eq_caseless_normalized(other)` (default NFKCForm) | Safe for display; NOT safe for identifier matching against homograph attacks. |
| `0.1.0` – `0.4.0` | Identifier matching | **No fully-safe primitive available.** See "What to do before `0.5.0`" below. | Caller must accept the gap. |
| `0.5.0`+ | Identifier matching | `Confusables.eq_identifier(a, b, profile)` (in `red/unicode/confusables`) | Safe per UTS #39 + RFC 8264. |

### What to do before `0.5.0`

If your release schedule requires identifier matching before `0.5.0`:

- **Option 1: Defer the use case** until `0.5.0` lands.
- **Option 2: Restrict the input space.** Reject input containing any codepoint outside `Property.alphabetic` + ASCII digits + an explicit set of allowed punctuation. Combined with `Scripts.restrict_to(s, allowed)` (`0.2.0`+) to limit to a specific script.
- **Option 3: Compose what's available.** Apply `t.normalize(NFKCForm).case_fold()` then `eq_codepoints`. Acknowledge in your codebase that this is incomplete identifier matching.

---

## 13. Migration from stdlib `String`

Pony's stdlib `String` is documented UTF-8 but never validates. `Text` adds the validation invariant plus Unicode-aware operations. Migration paths:

| You have | You want | How |
|---|---|---|
| `String val` | `Text val` | `Text.from_string(s)?` |
| `String iso` | `Text iso` (zero byte-copy adoption) | `Text.from_iso_string(consume s)?` |
| `Array[U8] val` | `Text val` | `Text.from_array(a)?` |
| `Array[U8] iso` | `Text iso` (zero byte-copy) | `Text.from_iso_array(consume a)?` |
| `Text val` | `String iso^` (round-trip out, copies) | `t.utf8_bytes()` (H4: clones internal buffer; caller owns) |
| `Text` to feed a `String`-taking API | `String val` view | `t.utf8_bytes()` then `recover val end` if needed |

**One-shot work**: if you have a `String box` and want a single Unicode answer, use the topical primitive (`Graphemes.count(s)`, `Search.contains(s, needle)`, etc.) without wrapping. Each call validates UTF-8.

**Repeated work**: if you'll perform two or more Unicode operations on the same input, wrap once with `Text.from_string(s)?` and chain on the result. Subsequent operations skip re-validation.

**Round-trip caveat**: `Text → String → Text` is cheap-ish (one byte-copy at `utf8_bytes()`; one validation walk at re-construction). For high-frequency round-trips, stay in `Text`.

---

## 14. Delta against `candidate-v2.md`

For readers who reviewed v2:

| v2 element | v3 status |
|---|---|
| `NamesPackageNotLoaded` variant | **removed** — H1 |
| `cp.name()` in core | **kept** — H1; data subject to DCE |
| `Codepoints.from_name(s)` reverse lookup | **added** — H1 |
| Names subpackage `red/unicode/names` (planned for 0.4.0) | **removed** from release plan — H1 |
| Release numbering past 0.4.0 | **shifted down by one** — H1: collate → 0.4.0, confusables → 0.5.0, IDNA → 0.6.0, bidi → 0.7.0 |
| Consumer sketches with `?` on union returns and bare `as` casts | **rewritten** with correct Pony syntax — H2 |
| `+` (Text concatenation) referenced but undefined | **defined** as `add`/`add_in_place` on Text, via `Concat` primitive — H3 |
| `utf8_bytes()` not in class definition, return type unclear | **defined** as `fun box utf8_bytes(): String iso^` (clone) — H4 |
| `Text.create(len)` not in class definition | **added** to §3 — H4 |
| `Findable = (Text val \| String box \| Array[U8] box)` | **changed** to `(Text box \| String box \| Array[U8] box)` — M1 |
| `primitive Text` (just for `Text.join`) | **removed** — M2 (class/primitive name collision is a Pony compile error) |
| `Join` primitive | **added** — M2 |
| `primitive Codepoint` (factories + U32 predicates) | **removed** — M2 (same collision issue) |
| `Codepoints` primitive expanded | **absorbs** Codepoint primitive's factories and predicates — M2 |
| `Bytes.starts_with_bom` | **removed** — M4 |
| `Bytes.detect_bom(b)?` | **kept** in 0.3.0; documented to return `(Encoding val \| NoBom)` — M4 |
| Mutator return-type inconsistency | **documented** rule in §6 (not changed) — M5 |
| IDNA deps `0.1.0, 0.4.0` (names) | **corrected** to `0.1.0, 0.2.0` — M6 |
| `Bytes` parameter types inconsistent (`String box`, unspecified) | **unified** via `ByteSeq` union type — L1 |
| `slice_graphemes(equal_indices)` behavior unspecified | **specified**: empty Text (success); reverse range returns OutOfRange — L2 |
| `Text.create(len)` cap notation | **no change**; standard Pony convention — L3 |
| Codepoint class/primitive coexistence concern | **dissolved** by M2 — L4 |
| §3.5 blanket "All grapheme-random-access ops are O(n)" | **replaced** with per-op complexity table — L5 |
| §12 confusables references "0.6.0" | **updated** to "0.5.0" |
| Names subpackage tension (T4 historical) | **fully dissolved** — H1 |
| `NamesPackageNotLoaded` framing in §4.1 | **removed** — H1 |
| Errors table (added `UnknownName`, `NoBom`) | **expanded** for new error types from H1 + M4 |

---

## 15. Cumulative delta against `candidate-v1.md`

For completeness, the v1 → v3 cumulative changes are the union of `candidate-v2.md`'s §14 (v1 → v2) plus this document's §14 (v2 → v3). The v1 baseline document is at `/home/red/tmp/unicode-design-20260525-103015/candidate-v1.md`.
