# Consumer-First Design: Pony Unicode Package

**Persona**: Consumer-First Designer
**Method**: Write usage code first; derive types from what makes that code clean.

---

## 0. Framing

Raku is the high-water mark for *string-as-language-primitive* design (NFG, full UCD, properties everywhere). Pony's built-in `String` is at the opposite extreme: an `Array[U8]` with a `.utf32()` helper.

**Two design choices we have to settle up front:**

1. **Replace `String`?** No. Stdlib and every ecosystem package speaks `String`. A Unicode package that demands its own type everywhere will be ignored. Integrate, don't compete.

2. **What's the central abstraction?** Programs that process text need four views — bytes, codepoints, graphemes, encoding-aware byte streams. Consumer-First test: which do consumers write *most often* across the scenarios? Graphemes. So graphemes are the default unit of `Text`. Codepoints and bytes are explicit opt-ins.

Package conventions:
- `use "unicode"` — single import for the core
- Names under `Unicode.*` for explicit qualified reference (principle #6)
- Type aliases at root: `Text`, `Codepoint`, `Grapheme` — for ergonomic call sites
- `Text` is `val`, immutable, shareable

---

## 1. Consumer Sketches (real Pony, ≥7 scenarios)

### Scenario A — Count visible characters

```pony
use "unicode"

actor Main
  new create(env: Env) =>
    let raw: String val = "café"        // could be 5 or 6 bytes
    let text = Text(raw)
    env.out.print("graphemes:  " + text.size().string())          // 4
    env.out.print("codepoints: " + text.codepoints().size().string())
    env.out.print("bytes:      " + text.bytes().size().string())
```

**Key API decision**: `Text(s)` is a *total* constructor over any Pony `String`. Pony documents `String` as UTF-8 but doesn't validate contents. We do *not* error on ill-formed UTF-8 — that would make `Text` impossible to use as a drop-in. Ill-formed sequences become U+FFFD via the W3C maximal-subpart algorithm.

For strict input, a separate factory:

```pony
match TextStrict(raw)
| let t: Text => env.out.print(t.size().string())
| let e: TextError => env.out.print("invalid UTF-8 at byte " + e.offset.string())
end
```

Two factories, one type. The `Text` value is identical either way — the difference is *how* invalid input is handled at the boundary.

### Scenario B — Case-insensitive username comparison after normalization

```pony
primitive UserMatch
  fun eq(a: String, b: String): Bool =>
    // The right thing by default for identifier matching:
    Text(a).identifier_fold().eq(Text(b).identifier_fold())
```

`identifier_fold()` is NFKC_Casefold per UAX #31 / UAX #21 — one call, no chance to forget the normalization step. For users who know what they want, the lower-level `.casefold(form)` exists and takes a normalization form. Choosing right-thing-by-default for the common case is consumer-first; the lower-level door is open for the rest.

### Scenario C — Slice display name at character N

```pony
fun truncate(name: Text, max_chars: USize): Text =>
  if name.size() <= max_chars then
    name
  else
    name.slice(0, max_chars) + Text("…")
  end
```

`slice(start, stop)` is *total* on grapheme indices; out-of-range clamps. For consumers who need to know whether clamping occurred, `slice_exact(start, stop)?` is the partial sibling. The default is for the common case; the partial is named to signal its strictness.

`+` on `Text` is concatenation that respects grapheme boundaries — a trailing combining mark on `name` and a leading base codepoint on `"…"` don't get fused mid-join.

### Scenario D — Validate input: only letters and digits

```pony
primitive ValidIdentifier
  fun apply(input: String): Bool =>
    let t = Text(input)
    if t.size() == 0 then return false end
    for cp in t.codepoints().values() do
      if not (cp.is_letter() or cp.is_digit()) then return false end
    end
    true
```

Codepoint predicates are methods on the `Codepoint` value type. One obvious place for `is_letter`. No `Unicode.Category.is_letter(cp)` vs `Unicode.is_letter(cp)` confusion.

For property-style validation:

```pony
fun valid(input: String): Bool =>
  Text(input).all_match({(cp: Codepoint): Bool =>
    cp.is_letter() or cp.is_digit() })
```

### Scenario E — Iterate words / sentences / lines

```pony
fun word_count(t: Text): USize =>
  var n: USize = 0
  for _ in t.words().values() do n = n + 1 end
  n

fun first_sentence(t: Text): Text =>
  try t.sentences().next()? else Text("") end
```

`words()`, `sentences()`, `lines()`, `graphemes()`, `codepoints()`, `bytes()` all return iterables exposing the same shape:

```pony
trait UnicodeSegments[T: Any val]
  fun values(): Iterator[T]
  fun size(): USize          // lazy O(n) first call, cached
  fun apply(i: USize): T ?
```

Boundary rules follow UAX #29 (grapheme/word/sentence) and UAX #14 (line break).

### Scenario F — Read a Latin-1 file as text

```pony
use "files"

actor Loader
  new create(env: Env, path: FilePath) =>
    match OpenFile(path)
    | let f: File =>
      let bytes = f.read(f.size())
      // Latin-1 is total — every byte is valid
      let t = Encoding.latin1.decode_infallible(consume bytes)
      env.out.print("loaded " + t.size().string() + " chars")
    end
```

For potentially-failing codecs:

```pony
match Encoding.utf16_le.decode(consume bytes)
| let t: Text => use(t)
| let e: DecodeError => env.err.print("decode: " + e.string())
end
```

`Encoding` is a primitive providing access to codec instances (`Encoding.latin1`, `Encoding.utf16_le`, etc.). Each codec is itself a primitive implementing the `Codec` trait. Total codecs add a `decode_infallible` method by convention (Latin-1, ASCII when input is constrained, etc.). Compile-time enforcement of totality via separate traits was considered and rejected — it forces polymorphic codec code (`try these N codecs`) into match-and-recombine awkwardness.

### Scenario G — Sort names in dictionary order

```pony
use "collections"

fun sorted(names: Array[Text] iso): Array[Text] iso^ =>
  let collator = Collator.locale("en-US")?
  Sort[Array[Text], Text](consume names,
    {(a: Text, b: Text): I32 => collator.compare(a, b)})
```

`Collator.locale(s)?` is partial — errors on unknown tags. `Collator.locale_or_root(s)` falls back to root collation (DUCET) for unknown tags — for "best effort" code paths.

`Collator` is `val`. Construction is the expensive step (tailoring tables); comparison is a cheap method. For repeated comparisons of the same items, `collator.sort_key(t)` returns a byte array that can be compared with regular `compare`:

```pony
let keyed = Array[(Array[U8] val, Text)]
for name in names.values() do
  keyed.push((collator.sort_key(name), name))
end
// sort by first element; original Text preserved
```

### Scenario H — Detect script(s) for security

```pony
fun mixed_script(t: Text): Bool =>
  // Ignoring Common and Inherited pseudo-scripts:
  t.scripts().resolved().size() > 1

fun matches_known_brand(t: Text): Bool =>
  Confusables.skeleton(t).eq(Confusables.skeleton(Text("paypal")))

fun categorize(t: Text): String =>
  match t.dominant_script()
  | Script.latin => "latin"
  | Script.cyrillic => "cyrillic"
  | Script.han => "han"
  | Script.unknown => "unknown"
  // … exhaustive match — compiler enforces handling new scripts
  end
```

`scripts()` returns a `ScriptSet val`. `Script` is a closed union of `~165` primitives. The verbosity is in the library; the exhaustiveness safety is at every consumer site. Adding a script in a Unicode version bump becomes a compile error in consumers that match exhaustively — which is the behavior we want.

### Scenario I — Codepoint/grapheme by position; iterate

```pony
fun first_emoji(t: Text): (Grapheme | None) =>
  for g in t.graphemes().values() do
    if g.has_property(Property.emoji_presentation) then return g end
  end
  None

fun nth_codepoint(t: Text, n: USize): Codepoint ? =>
  t.codepoints()(n)?

fun byte_at(t: Text, n: USize): U8 ? =>
  t.bytes()(n)?
```

`Grapheme` is its own value type — it can hold multiple codepoints. `text.graphemes()` is what consumers iterate for "characters." The **biggest semantic difference from built-in String**: `Text(s).size()` is graphemes.

### Scenario J — Codepoint properties

```pony
let cp = Codepoint(0x1F600)?            // grinning face — partial
env.out.print(cp.name())                 // "GRINNING FACE" (if names pkg loaded)
env.out.print(cp.category().iso())       // "So"
env.out.print(cp.script().iso())         // "Zyyy" (Common)
env.out.print(cp.is_emoji().string())    // "true"
```

`Codepoint(u)?` errors on surrogates and out-of-range values. `Codepoint.from_u32_or_replacement(u)` is the total fallback.

We name `Codepoint` to mean *Unicode scalar value* (`0..0xD7FF`, `0xE000..0x10FFFF`) — the values that can appear in well-formed UTF-8. Arbitrary `U32` values stay as `U32`. This naming aligns with how "codepoint" is used in encoded contexts; the standard's broader sense ("any U+0000..U+10FFFF including surrogates") we don't need a type for.

### Scenario K (bonus) — Working with raw bytes

```pony
// Have raw bytes, one cheap question, don't allocate a Text:
fun has_bom(bytes: Array[U8] box): Bool =>
  Unicode.Bytes.starts_with_bom(bytes)

// Adopt iso bytes as a Text without copying:
fun to_text(bytes: Array[U8] iso): Text =>
  Text.from_utf8(consume bytes)
```

`Unicode.Bytes` is the **utility primitive** — free functions over `String` and `Array[U8]`. It exists for consumers who have raw bytes and don't want a `Text` allocation, are writing parsers, or need to operate on a `String` field they can't change.

---

## 2. Type Surface (derived from §1)

Each type was forced into existence by a sketch. The "semantic guarantee" column is what the consumer can rely on once they hold the type.

| Type | Cap | Semantic guarantee | Construction |
|---|---|---|---|
| `Text` | val | Well-formed Unicode; UTF-8 storage; substituted on input | `Text(s)`, `Text.from_utf8(consume bytes)`, `Encoding.X.decode(...)` |
| `Codepoint` | val (wraps U32) | Valid scalar value (0..D7FF, E000..10FFFF) | `Codepoint(u)?`, `Codepoint.from_u32_or_replacement(u)` |
| `Grapheme` | val | Exactly one extended grapheme cluster per UAX #29 | Only via `Text.graphemes()` |
| `Script` | primitive (closed union) | One of the scripts in the loaded UCD | `Script.latin`, `Script.from_iso(s)?` |
| `Category` | primitive (closed union) | One of the 30 general categories | `Category.uppercase_letter`, `Category.from_iso(s)?` |
| `Property` | primitive (closed union) | One of the binary properties tracked | `Property.alphabetic`, … |
| `NormalizationForm` | primitive (closed union) | NFC / NFD / NFKC / NFKD | `NFC`, `NFD`, `NFKC`, `NFKD` (top-level aliases) |
| `Codec` | trait val | An encoding with decode/encode | Codec instances are primitives: `Encoding.latin1`, … |
| `Collator` | val | Locale-tailored ordering; `compare` + `sort_key` | `Collator.locale(s)?`, `Collator.locale_or_root(s)`, `Collator.root()` |
| `ScriptSet` | val | Small set of `Script`; `.resolved()` drops Common/Inherited | `text.scripts()` |
| `Confusables` | primitive | UTS #39 skeleton | `Confusables.skeleton(t)` |
| `UnicodeSegments[T]` | trait | Iterable + sized + indexable view | `t.graphemes()`, `t.words()`, … |

**Errors** (each is a primitive carrying one piece of context, implementing `Stringable`):

| Type | Context | When |
|---|---|---|
| `TextError` (= `TextErrorIllFormedUtf8`) | byte offset | `TextStrict` rejected input |
| `CodepointError` (= surrogate \| out-of-range) | u32 value | `Codepoint(u)?` failed |
| `DecodeError` (= ill-formed \| unsupported-byte) | byte offset | Codec decode failed |
| `EncodeError` (= unmappable) | codepoint | Codec can't represent a codepoint |
| `LocaleError` (= unknown-tag) | locale string | `Collator.locale(s)?` failed |

Each error is part of a *closed union* returned from the fallible constructor (principle: closed unions for exhaustive matching, not marker traits — see Pony gotcha #9).

---

## 3. Typed Entities vs Utility Functions

**One sentence**: `Text` is the typed entity that guarantees well-formedness; `Unicode.Bytes` is a set of functions over raw `String`/`Array[U8]` for common Unicode operations without paying for a `Text` allocation.

### When to use each

| You have | You want | Use |
|---|---|---|
| `Text` | any Unicode operation | methods on `Text` |
| `String` processed repeatedly | repeated Unicode ops | construct `Text` once |
| `String` + one cheap question | a single answer | `Unicode.Bytes.X(s)` |
| Raw bytes in known encoding | a `Text` | `Encoding.X.decode(...)` |
| `Array[U8] iso` you own | a `Text` | `Text.from_utf8(consume bytes)` |
| `Text` to send over network | bytes | `t.utf8_bytes()` or `Encoding.utf16_be.encode(t)` |

### Conversion API (small and symmetric)

```pony
// String <-> Text
let t: Text = Text(some_string)             // total, substituting
match TextStrict(s)                          // strict
| let t: Text => …
| let e: TextError => …
end
let s: String val = t.string()              // canonical UTF-8

// Array[U8] iso <-> Text  (zero-copy adoption)
let t: Text = Text.from_utf8(consume bytes)
let b: Array[U8] val = t.utf8_bytes()       // zero-copy view (val data)

// Codepoint <-> Text
let t: Text = Text.from_codepoint(cp)
let cp: Codepoint = t.codepoints().head()?

// Codepoint <-> U32  (for FFI / low-level)
let cp: Codepoint = Codepoint(u)?
let u: U32 = cp.u32()
```

### Why both views

Two real consumer profiles:

- **Profile 1**: works with `String` everywhere, occasionally needs Unicode answers. Shouldn't have to learn `Text` for "is this valid UTF-8?". → `Unicode.Bytes.is_valid_utf8(s)`.
- **Profile 2**: works with text *meaningfully* — segments, normalizes, compares. Shouldn't redo decoding on each call. → construct `Text` once.

Both exposed, conversion documented above.

### What we don't do

Define a structural `Stringy` interface that both `String` and `Text` implement. Pony's structural typing would let it compile, but `.size()` differs in units (bytes vs graphemes). Making them substitutable would silently lie to consumers. This is rejecting an import of dynamic-language pattern reflexes (principle: distinct semantics deserve distinct representations).

---

## 4. Error Vocabulary

```pony
type TextError is TextErrorIllFormedUtf8

primitive TextErrorIllFormedUtf8
  let offset: USize
  fun string(): String iso^ =>
    "ill-formed UTF-8 at byte offset " + offset.string()

type CodepointError is (CodepointErrorSurrogate | CodepointErrorOutOfRange)

primitive CodepointErrorSurrogate
  let value: U32
  fun string(): String iso^ =>
    "surrogate codepoint U+" + Format.hex[U32](value)

primitive CodepointErrorOutOfRange
  let value: U32
  fun string(): String iso^ =>
    "codepoint out of range: " + value.string()

type DecodeError is (DecodeIllFormed | DecodeUnsupportedByte)
type EncodeError is EncodeUnmappable
type LocaleError is LocaleUnknownTag
```

**No cross-layer wrappers.** When a high-level op (read file as text) can fail at I/O or Unicode layer, the consumer matches on both — both are already disjoint primitives:

```pony
match read_text_file(path, Encoding.utf8)
| let t: Text => use(t)
| let e: FileError => log("io: " + e.string())
| let e: DecodeError => log("decode: " + e.string())
end
```

A `ReadTextError` wrapper would erase the provenance.

---

## 5. UCD Strategy

### Data needed (by version target)

1. General Category — v0.1
2. Grapheme break properties — v0.1
3. Decomposition + Composition tables — v0.2
4. Case mappings (simple + full, locale specials) — v0.2
5. Word/Sentence/Line break properties — v0.3
6. Scripts + ScriptExtensions — v0.3
7. Binary properties — v0.3
8. Codepoint names — v0.4 (separate package)
9. Collation (DUCET + CLDR tailorings) — v0.6
10. Confusables data — v0.7

### Form

**Build-time generated, compiled-in tables** (small/hot data):
- `_UnicodeData`, `_CaseMappings`, `_NormalizationTables` — Pony primitives generated by `tools/gen-ucd.pony`.
- Generator runs at *library release time*, not user build time. Generated files checked in.
- Two-stage tables (range → property) keep size down; total compiled tables several hundred KB.

**Lazy / opt-in package** (large/cold data):
- `unicode/names` (~600 KB of strings) is a separate package. `cp.name()` returns `"U+XXXX"` if the names package is not imported, real name if it is. One `use` line is the opt-in.

**Always resident**: everything else. Compiled tables small enough that "always loaded" is right for a general-purpose library.

### Unicode version tracking

```pony
primitive Unicode
  fun version(): UnicodeVersion =>
    UnicodeVersion(_GeneratedUcdVersion.major(),
                   _GeneratedUcdVersion.minor(),
                   _GeneratedUcdVersion.patch())

class val UnicodeVersion is (Equatable[UnicodeVersion] & Stringable)
  let major: U8
  let minor: U8
  let patch: U8
```

Library targets a single Unicode version per release. Bumping is a release event with notes.

---

## 6. Criticality Ordering (with dependencies)

### v0.1 — "It correctly counts characters"

- `Text` value type; `Text(s)`, `TextStrict(s)?`, `Text.from_utf8(consume bytes)`
- `text.size()` (graphemes), `.graphemes()`, `.codepoints()`, `.bytes()`
- `text.slice(start, stop)`, `text.slice_exact(start, stop)?`
- `text.eq`, `text.ne`, `+`
- `Codepoint` with `category()`, `is_letter()`, `is_digit()`, `is_whitespace()`, basic predicates
- `Grapheme` with `string()`, `codepoints()`, `eq()`
- `Category` closed union
- UCD: general category + grapheme breaks
- **Deps**: nothing
- **Conformance**: GraphemeBreakTest.txt passing

### v0.2 — "It compares meaningfully"

- `text.normalize(form)`, `text.is_normalized(form)`
- `text.casefold(form)`, `text.identifier_fold()`
- `text.upper()`, `text.lower()`, `text.title()` — full mappings, locale-aware for Turkic/Lithuanian/Azeri (optional locale param)
- UCD: normalization + case mappings
- **Deps**: v0.1
- **Conformance**: NormalizationTest.txt passing

### v0.3 — "It segments and queries"

- `text.words()`, `text.sentences()`, `text.lines()`
- `text.scripts()`, `text.dominant_script()`, `ScriptSet.resolved()`
- `Script` closed union, `Property` closed union
- `cp.script()`, `cp.has_property(p)`, `grapheme.has_property(p)`
- **Deps**: v0.1
- **Conformance**: WordBreakTest.txt, SentenceBreakTest.txt, LineBreakTest.txt passing

### v0.4 — "Encodings beyond UTF-8"

- `Codec` trait
- Codecs: `utf8`, `utf16_le`, `utf16_be`, `utf16` (BOM-detecting), `utf32_le`, `utf32_be`, `latin1`, `ascii`, `windows_1252`
- `Encoding.detect_bom(bytes)?`
- Streaming decode for chunked files
- **Deps**: v0.1

### v0.5 — "Cold queries"

- Separate package `unicode/names`
- `cp.name()` with names loaded, `Codepoint.from_name(s)?`
- **Deps**: v0.1

### v0.6 — "Locale-aware sort"

- `Collator` value type; `locale(s)?`, `locale_or_root(s)`, `root()`
- `compare(a, b): I32`, `sort_key(t): Array[U8] val`
- Strength / case-first / numeric / variable-weighting options
- DUCET + minimal CLDR tailorings
- **Deps**: v0.2, v0.3

### v0.7 — "Security / confusables"

- `Confusables.skeleton(t)`, `Confusables.are_confusable(a, b)`
- `IdentifierProfile` (restricted / moderate / unrestricted)
- **Deps**: v0.3

### v1.0 — "Stable surface"

- API freeze, Unicode version pinned, full UCD conformance suite

---

## 7. Improvements Over Raku

### 7.1 Explicit construction at the boundary
Raku auto-promotes everywhere. We require `Text(s)`. Downstream code knows the bytes have been validated. Costs one extra call site; buys clarity.

### 7.2 Closed unions instead of stringy enums
Raku script/category names are strings (`"Latin"`, `"Lu"`) — no exhaustive matching. Our `Script.latin`, `Category.uppercase_letter` give the compiler something to check. Adding a script in a Unicode bump becomes a compile error in code that did exhaustive matching — the right kind of breakage.

### 7.3 No global state for collation or normalization
Raku has implicit current-locale collation. We always pass a `Collator` explicitly. Two parts of a program can't drift into different behavior.

### 7.4 NFG-free design
Raku's NFG assigns synthetic codepoints to multi-codepoint graphemes for O(1) indexing. Clever, but locks representation and forces a copy at construction. We keep UTF-8 storage; segment boundaries computed lazily, cached after first iteration. Wrapping a `String val` in a `Text` is zero-copy. For programs that mostly pass text through (HTTP servers, log processors), this wins.

### 7.5 Separate strict vs substituting factories
Raku throws on ill-formed UTF-8. Right for some uses, wrong for others (log processor wants to substitute and keep going). Two factories make the choice explicit at the point of construction.

### 7.6 Capability-aware adoption
`Text.from_utf8(consume iso_bytes)` adopts an `iso` byte array without copying. Raku has no equivalent — strings always copy in.

### 7.7 Honest about the names data
Raku ships codepoint names with the runtime. We make them an opt-in package. Most programs don't need them; opt-in shrinks common-case binary and makes the dependency visible.

---

## 8. Side-by-Side Consistency Checks

### 8.1 Codepoint queries on `Codepoint` vs `Grapheme`

```pony
// Codepoint
let cp: Codepoint = Codepoint(0x1F600)?
cp.is_emoji()                                // Bool
cp.has_property(Property.emoji_presentation) // Bool
cp.category()                                // Category
cp.script()                                  // Script

// Grapheme
let g: Grapheme = some_text.graphemes()(0)?
g.is_emoji()                                 // Bool — about the base codepoint
g.has_property(Property.emoji_presentation)  // Bool — *cluster contains* a codepoint with that property
g.category()                                 // Category — of the base codepoint
g.script()                                   // Script — of the base codepoint
```

**Status**: signature-aligned, **deliberately divergent in semantics for `has_property`**. A grapheme is a cluster; "has property" reasonably means "any codepoint in the cluster has the property." Documented explicitly.

### 8.2 Iteration APIs

```pony
text.graphemes().values()    // Iterator[Grapheme]
text.codepoints().values()   // Iterator[Codepoint]
text.bytes().values()        // Iterator[U8]
text.words().values()        // Iterator[Text]
text.sentences().values()    // Iterator[Text]
text.lines().values()        // Iterator[Text]
```

**Status**: aligned. Element type varies, container shape doesn't. Word/sentence/line yield `Text` (not new types) — they're just text. `Grapheme` is its own type because it carries an extra invariant.

### 8.3 Strict vs substituting factories

```pony
Text(s)                              // total, substitutes
TextStrict(s)                         // (Text | TextError)

Codepoint(u)?                         // partial, errors on invalid
Codepoint.from_u32_or_replacement(u)  // total, substitutes

Encoding.utf8.decode(bytes)           // (Text | DecodeError)
Encoding.latin1.decode_infallible(bytes)  // Text  (only on total codecs)
```

**Status**: convention-aligned but signatures differ deliberately.

---

## 9. Key Decisions

- **`Text(s)` is total over any `String`, substituting U+FFFD**; `TextStrict(s)` is the partial sibling. **Confidence**: high.
- **Graphemes are the default unit of `text.size()` and `text.slice()`**. **Confidence**: high.
- **Closed unions of primitives for `Script`, `Category`, `Property`, errors.** **Confidence**: high.
- **`Text` + `Unicode.Bytes` (utility primitive) coexist.** **Confidence**: high.
- **UTF-8 internal storage with lazy cached grapheme offsets; no NFG.** **Confidence**: medium-high.
- **UCD as build-time generated, compiled-in tables for hot data; names as separate opt-in package.** **Confidence**: medium-high.
- **Locale-specific case mapping defaults to "no tailoring"; locale is an optional explicit parameter.** **Confidence**: medium.
- **`decode_infallible` only on total codecs by convention, not by trait.** **Confidence**: medium.
- **No structural `Stringy` interface.** **Confidence**: high.
- **`Codepoint(u)?` is partial, asymmetric with `Text(s)` totality.** **Confidence**: low-medium.

---

## 10. Uncertainties

1. Whether iterator refcap behavior over `Text val` works as sketched — not type-checker-verified.
2. Whether v0.1's slice/size combo is fast enough without precomputing all grapheme offsets.
3. Streaming-decode API shape for big files (v0.4).
4. Whether the `has_property` semantic divergence between `Codepoint` and `Grapheme` (§8.1) trips users in practice.
5. Should there be a mutable `TextBuilder` sibling?
6. Locale tag parsing strictness for `Collator.locale`.

---

## 11. Assumptions

1. `Text` is `val`. Mutable text path is "use `String`".
2. UTF-8 as canonical internal encoding.
3. Build-time UCD generation, files checked in.
4. Pony's `String` stays byte-oriented.
5. 1.0 pins one Unicode version.
6. Correctness established by UCD conformance suites + PonyCheck algebraic properties.
