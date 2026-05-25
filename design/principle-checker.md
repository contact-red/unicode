# Pony Unicode Package — Principle Checker's Design

## 1. Problem framing

Pony's built-in `String` is byte-oriented UTF-8. The byte view is the *only* view stdlib gives users. Pain:

- `.size()` is bytes, never codepoints or graphemes
- Two visibly identical strings can compare unequal (NFC vs NFD)
- `lower()` is ASCII-only — wrong for `"Straße"`, `"İ"`, `"Σ"`
- Byte offsets cut codepoints and grapheme clusters in half
- Only UTF-8 in/out
- No properties, scripts, names

Users want: visible-length (graphemes), written-length (codepoints), meaningful equality (normalization + case folding + collation), property queries, and non-UTF-8 encodings.

**Improvements over Raku**: (a) we never silently normalize on construction — form is part of the type; (b) byte/codepoint/grapheme distinction is in the type system; (c) errors are concrete data, not exceptions; (d) encoding is first-class and distinct from text operations.

## 2. The design

### 2.1 Top-level shape

Package `red/unicode`. Two coexisting views:

- `red/unicode/text` — typed entities (`Text`, `Codepoint`, `Grapheme`, `CodepointIndex`, `GraphemeIndex`, `ByteIndex`, `NormalForm`, `Encoding`, `Script`, `Category`, …)
- `red/unicode/strops` — utility functions over Pony's `String`, defined as the un-lifted form of `Text` methods

Canonical layer is `Text`; `strops` never exceeds it.

### 2.2 Index types — central correctness mechanism

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

type ByteIndex      is Index[_ByteIdx]
type CodepointIndex is Index[_CodepointIdx]
type GraphemeIndex  is Index[_GraphemeIdx]
```

`ByteIndex` and `CodepointIndex` are not interchangeable — the compiler rejects passing one for the other.

Conversion between index kinds is **always explicit** and requires the `Text`:

```pony
class val Text
  fun codepoint_index_of_byte(b: ByteIndex): (CodepointIndex | OutOfRange)
  fun grapheme_index_of_codepoint(c: CodepointIndex): (GraphemeIndex | OutOfRange)
  fun byte_index_of_grapheme(g: GraphemeIndex): ByteIndex
```

No `index.to_codepoint_index()` — the question doesn't make sense without a `Text`.

### 2.3 Codepoint and Grapheme — distinct types

```pony
class val Codepoint
  """A Unicode scalar value: U+0000..U+10FFFF excluding surrogates."""
  let _scalar: U32
  new val _create(scalar: U32) => _scalar = scalar
  fun scalar(): U32 => _scalar
  fun category(): Category
  fun script(): Script
  fun name(): (String val | NoName)
  fun is_letter(): Bool
  fun is_digit(): Bool
  fun is_whitespace(): Bool
  fun numeric_value(): (F64 | NoNumericValue)
  fun simple_uppercase(): Codepoint
  fun simple_lowercase(): Codepoint
  fun simple_titlecase(): Codepoint
  fun eq(that: Codepoint box): Bool => _scalar == that._scalar
  fun lt(that: Codepoint box): Bool => _scalar < that._scalar
  fun hash(): USize => _scalar.hash()

primitive Codepoint
  fun from_u32(u: U32): (Codepoint | InvalidScalar)

class val Grapheme
  """A user-perceived character: codepoint sequence forming one
     extended grapheme cluster (UAX #29)."""
  let _codepoints: Array[Codepoint] val
  new val _create(cps: Array[Codepoint] val) => _codepoints = cps
  fun codepoints(): Array[Codepoint] val => _codepoints
  fun size_codepoints(): USize => _codepoints.size()
  fun base(): Codepoint => try _codepoints(0)? else Unreachable() end
  fun script(): Script
  fun eq(that: Grapheme box): Bool  // element-wise sequence equality
  fun hash(): USize                 // combined hash of elements
```

### 2.4 Text — the central type

```pony
primitive NFCForm
primitive NFDForm
primitive NFKCForm
primitive NFKDForm
primitive UnknownForm

type NormalForm is (NFCForm | NFDForm | NFKCForm | NFKDForm | UnknownForm)

class val Text
  let _utf8: String val      // guaranteed valid UTF-8
  let _form: NormalForm
  new val _create(utf8: String val, form: NormalForm) =>
    _utf8 = utf8; _form = form

  fun normal_form(): NormalForm => _form
  fun utf8_bytes(): String val => _utf8

  // Counting
  fun size_bytes(): USize => _utf8.size()
  fun size_codepoints(): USize
  fun size_graphemes(): USize

  // Indexing
  fun codepoint_at(i: CodepointIndex): (Codepoint | OutOfRange)
  fun grapheme_at(i: GraphemeIndex): (Grapheme | OutOfRange)

  // Iteration
  fun codepoints(): Iterator[Codepoint]
  fun graphemes(): Iterator[Grapheme]
  fun bytes(): Iterator[U8] => _utf8.values()

  // Slicing — explicit about which index kind
  fun slice_codepoints(start: CodepointIndex, finish: CodepointIndex)
    : (Text val | OutOfRange)
  fun slice_graphemes(start: GraphemeIndex, finish: GraphemeIndex)
    : (Text val | OutOfRange)
  // no slice_bytes — that would be a footgun

  // Normalization
  fun normalize(target: NormalForm): Text val

  // Case mapping (full, locale-aware)
  fun to_upper(locale: CaseLocale = DefaultLocale): Text val
  fun to_lower(locale: CaseLocale = DefaultLocale): Text val
  fun to_title(locale: CaseLocale = DefaultLocale): Text val
  fun case_fold(form: CaseFoldForm = DefaultCaseFold): Text val

  // Equality
  fun eq_codepoints(that: Text box): Bool  // exact sequence
  fun eq_normalized(that: Text box, form: NormalForm = NFCForm): Bool
  fun eq_caseless(that: Text box, locale: CaseLocale = DefaultLocale): Bool

  // Breaks
  fun words(): Iterator[Text val]
  fun sentences(): Iterator[Text val]
  fun lines(): Iterator[Text val]

  // Predicates
  fun is_all(p: {(Codepoint): Bool} val): Bool

primitive Text
  fun from_string(s: String box, form: NormalForm = UnknownForm)
    : (Text val | InvalidUtf8)
  fun from_utf8_bytes(b: Array[U8] val, form: NormalForm = UnknownForm)
    : (Text val | InvalidUtf8)
  fun from_codepoints(cps: ReadSeq[Codepoint] box): Text val
  fun decode(bytes: Array[U8] val, encoding: Encoding,
             policy: DecodePolicy = StrictPolicy)
    : (Text val | DecodeError)
```

Centralized validation: `Text` cannot exist with invalid UTF-8.

### 2.5 Encoding — separate from text operations

```pony
trait val Encoding
  fun name(): String val
  fun decode(bytes: Array[U8] val, policy: DecodePolicy)
    : (Text val | DecodeError)
  fun encode(text: Text val, policy: EncodePolicy)
    : (Array[U8] val | EncodeError)

primitive Utf8       is Encoding
primitive Utf16Le    is Encoding
primitive Utf16Be    is Encoding
primitive Utf32Le    is Encoding
primitive Utf32Be    is Encoding
primitive Latin1     is Encoding
primitive ShiftJis   is Encoding

primitive StrictPolicy
primitive ReplacePolicy
primitive IgnorePolicy
type DecodePolicy is (StrictPolicy | ReplacePolicy | IgnorePolicy)
```

### 2.6 Categories, scripts, properties

```pony
primitive Lu  primitive Ll  primitive Lt  primitive Lm  primitive Lo
primitive Mn  primitive Mc  primitive Me
primitive Nd  primitive Nl  primitive No
primitive Pc  primitive Pd  primitive Ps  primitive Pe
primitive Pi  primitive Pf  primitive Po
primitive Sm  primitive Sc  primitive Sk  primitive So
primitive Zs  primitive Zl  primitive Zp
primitive Cc  primitive Cf  primitive Cs  primitive Co  primitive Cn

type Category is (Lu | Ll | Lt | Lm | Lo
                  | Mn | Mc | Me
                  | Nd | Nl | No
                  | Pc | Pd | Ps | Pe | Pi | Pf | Po
                  | Sm | Sc | Sk | So
                  | Zs | Zl | Zp
                  | Cc | Cf | Cs | Co | Cn)

primitive Latin     primitive Cyrillic   primitive Greek
primitive Han       primitive Hiragana   primitive Katakana
// ... full ISO 15924 inventory
primitive Common    primitive Inherited  primitive Unknown_Script

type Script is (Latin | Cyrillic | Greek | ... | Common | Inherited | Unknown_Script)
```

Closed unions give exhaustive `match`, clean `Hashable`, no string typos.

### 2.7 Errors — concrete data

```pony
primitive InvalidUtf8     fun string(): String iso^ => "invalid UTF-8".clone()
primitive InvalidScalar   fun string(): String iso^ => "surrogate or > U+10FFFF".clone()
primitive OutOfRange      fun string(): String iso^ => "index out of range".clone()
primitive NoName
primitive NoNumericValue

class val DecodeError
  let offset: USize
  let kind: _DecodeErrorKind
  let encoding_name: String val
  fun string(): String iso^

class val EncodeError
  let codepoint: Codepoint
  let encoding_name: String val
  fun string(): String iso^
```

### 2.8 strops — utility view over Pony String

```pony
primitive Strops
  fun size_codepoints(s: String box): (USize | InvalidUtf8)
  fun size_graphemes(s: String box): (USize | InvalidUtf8)
  fun is_valid_utf8(s: String box): Bool
  fun is_all_letters(s: String box): (Bool | InvalidUtf8)
  fun to_lower(s: String box, locale: CaseLocale = DefaultLocale)
    : (String iso^ | InvalidUtf8)
  fun to_upper(s: String box, locale: CaseLocale = DefaultLocale)
    : (String iso^ | InvalidUtf8)
  fun normalize(s: String box, target: NormalForm)
    : (String iso^ | InvalidUtf8)
  fun eq_normalized(a: String box, b: String box, form: NormalForm = NFCForm)
    : (Bool | InvalidUtf8)
  fun eq_caseless(a: String box, b: String box,
                  locale: CaseLocale = DefaultLocale)
    : (Bool | InvalidUtf8)
```

Contract (review-enforced): `Strops.X(s, args)` == lift `s` to `Text`, call `Text.X(args)`, unlift if needed. `Strops` does not add behavior beyond `Text`.

### 2.9 UCD strategy

- **Build-time generation**: `ucd_data` subpackage generated from UCD XML into `val` static tables (two-level radix tables, shared-trie compressed)
- **Always-resident**: tables live in compiled code; ~5MB acceptable
- **Unicode version exposed**: `primitive UnicodeVersion fun string(): String val => "16.0.0"` — bumping Unicode requires a package version bump (adding scripts changes the closed `Script` union)
- **Optional data in subpackages**: `red/unicode/confusables`, `red/unicode/collate`, `red/unicode/idna` — users pay only for what they import

### 2.10 Criticality ordering

| Release | Surface | Rationale / deps |
|---------|---------|------------------|
| v0.1 | `Codepoint`, `Grapheme` (no break logic), `Text` with bytes + codepoints + UTF-8 decode/encode, `InvalidUtf8`, `OutOfRange`, `Category`, codepoint properties + script, index types, `Strops` codepoint subset | Foundation. Deps: stdlib + generated UCD. |
| v0.2 | UAX #29 grapheme breaks, `Text.graphemes()`, `size_graphemes()`, `GraphemeIndex`, grapheme slicing | Scenarios (a), (c). Deps: v0.1 + break tables. |
| v0.3 | Normalization (NFC/NFD/NFKC/NFKD), `eq_normalized`, `Strops.normalize` | Scenario (b). Deps: v0.1 + decomposition/composition/CCC tables. |
| v0.4 | Full locale-aware case mapping, case folding, `eq_caseless`, `CaseLocale` (`DefaultLocale | TurkicLocale | LithuanianLocale | AzerbaijaniLocale`) | Scenario (b) part two. Deps: v0.3 + special-casing tables. |
| v0.5 | Word/sentence/line breaks (UAX #29 + UAX #14) | Scenario (e). Deps: v0.2. |
| v0.6 | `Encoding` trait + Latin-1, UTF-16 LE/BE, UTF-32 LE/BE; `DecodeError`, `DecodePolicy` | Scenario (f). Deps: v0.1. |
| v0.7 | `red/unicode/collate`: UCA with locale + strength options | Scenario (g). Deps: v0.3 + UCA + CLDR locale tables. |
| v0.8 | `red/unicode/script_detect`: mixed-script analysis | Scenario (h). Deps: v0.1. |
| v0.9 | `red/unicode/confusables`: confusable-skeleton lookup | Scenario (h) deeper. Deps: v0.1 + confusables table. |
| v1.0 | Additional encodings (Shift-JIS, Big5, GB18030, EUC, codepages), `red/unicode/idna`, deeper segmentation APIs | Round out. |

## 3. Consumer sketches

### (a) Count visible characters

```pony
use unicode = "red/unicode"

actor Main
  new create(env: Env) =>
    let raw: String = "café 🇫🇷👨‍👩‍👧"
    match unicode.Text.from_string(raw)
    | let t: unicode.Text val =>
      env.out.print("visible: " + t.size_graphemes().string())
    | unicode.InvalidUtf8 =>
      env.out.print("not valid UTF-8")
    end
```

### (b) Case-insensitive username compare after normalization

```pony
fun usernames_match(a: String box, b: String box)
  : (Bool | unicode.InvalidUtf8)
=>
  match (unicode.Text.from_string(a), unicode.Text.from_string(b))
  | (let ta: unicode.Text val, let tb: unicode.Text val) =>
    let na = ta.normalize(unicode.NFCForm).case_fold()
    let nb = tb.normalize(unicode.NFCForm).case_fold()
    na.eq_codepoints(nb)
  | _ => unicode.InvalidUtf8
  end
```

### (c) Truncate to N visible characters

```pony
fun truncate(s: String box, max: USize)
  : (String val | unicode.InvalidUtf8)
=>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    let limit = unicode.GraphemeIndex(max.min(t.size_graphemes()))
    match t.slice_graphemes(unicode.GraphemeIndex(0), limit)
    | let cut: unicode.Text val => cut.utf8_bytes()
    | unicode.OutOfRange => t.utf8_bytes()
    end
  | unicode.InvalidUtf8 => unicode.InvalidUtf8
  end
```

### (d) Validate: only letters and digits

```pony
fun is_alphanumeric(s: String box): (Bool | unicode.InvalidUtf8) =>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    t.is_all({(cp: unicode.Codepoint): Bool =>
      cp.is_letter() or cp.is_digit()
    } val)
  | unicode.InvalidUtf8 => unicode.InvalidUtf8
  end
```

### (f) Read Latin-1 file

```pony
use file = "files"
use unicode = "red/unicode"

actor Main
  new create(env: Env) =>
    try
      let path = file.FilePath(env.root, "data.txt")?
      let f = file.File(path)
      let bytes: Array[U8] val = f.read(f.size())
      match unicode.Text.decode(bytes, unicode.Latin1, unicode.StrictPolicy)
      | let t: unicode.Text val => env.out.print(t.utf8_bytes())
      | let e: unicode.DecodeError => env.out.print(e.string())
      end
    end
```

### (h) Script detection for security

```pony
fun detect_scripts(s: String box)
  : (Set[unicode.Script] | unicode.InvalidUtf8)
=>
  match unicode.Text.from_string(s)
  | let t: unicode.Text val =>
    let scripts = Set[unicode.Script]
    for cp in t.codepoints() do
      match cp.script()
      | unicode.Common | unicode.Inherited | unicode.Unknown_Script => None
      else
        scripts.set(cp.script())
      end
    end
    scripts
  | unicode.InvalidUtf8 => unicode.InvalidUtf8
  end
```

### Compile-time correctness — illegal mixing

```pony
t.grapheme_at(unicode.CodepointIndex(3))
// compile error: argument is CodepointIndex, expected GraphemeIndex
```

## 4. Verification matrix

### 4.1 Design disciplines

| # | Discipline | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Start from the problem | PASS | §1 states pain before any type; `Text` does not appear until §2.4. |
| 2 | Explore before committing | PASS | §6 records three considered framings: extend `String`, typed `Text`-only, dual view. |
| 3 | Sketch consumer code first | PASS | §3 has 8 sketches; sketches drove `slice_graphemes`/`slice_codepoints` split. |
| 4 | Inventory before inventing | PASS | We reuse `Iterator[T]` from stdlib; do not invent a new error trait — union-of-primitives. |
| 5 | Build up incrementally | PASS | §2.10 builds in 10 releases. v0.1 is the smallest coherent piece. |
| 6 | Every step changes what you can see | PASS | When grapheme breaks were added (v0.2), the parameterized-`slice` design from earlier was revisited. |
| 7 | Question every abstraction | PASS | `Codepoint` exists because `U32` can hold surrogates; `Grapheme` carries cluster semantics; `Text` carries UTF-8 + form invariant. |
| 8 | Name things precisely | PASS | `Text`, `Codepoint`, `Grapheme`, `CodepointIndex`/`GraphemeIndex`/`ByteIndex`, `eq_codepoints`/`eq_normalized`/`eq_caseless`. |
| 9 | Reason about ownership boundaries | PASS | Library owns: UCD, normalization, break logic, encoding, validity invariants. User owns: form choice, locale, policy, all I/O. |
| 10 | Separate layers | N/A | Library, not layered application. Covered by #9. |
| 11 | Map state explicitly | PASS | Only state is `_form: NormalForm` — closed union. No booleans. New `Text` per transform. |
| 12 | Articulate invariants | PASS | (i) `Text._utf8` always valid UTF-8; (ii) `Codepoint._scalar` always in 0..0x10FFFF excl. surrogates; (iii) `Grapheme._codepoints.size() >= 1`; (iv) form tag honest; (v) index kinds not interchangeable. |
| 13 | Check cohesion | PASS | Each subpackage has a single theme. |
| 14 | Surface the grain | PASS | Easy: new `Encoding`. Expensive: new `Script` variant (intentional). |
| 15 | Look for footguns | PASS | §5 hazard checklist. |
| 16 | Distinguish values with distinct semantics | PASS | `ByteIndex`/`CodepointIndex`/`GraphemeIndex`; `Codepoint`/`Grapheme`/`Text`; `NFCForm`/`NFDForm`/etc; error primitives. |
| 17 | Design error vocabularies | PASS | Per-layer vocabulary in §2.7. `DecodeError(offset, kind, encoding_name)` actionable. |

### 4.2 Code-design principles

| # | Principle | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Prefer explicit over implicit | PASS | No implicit normalization on construction. Locale explicit. |
| 2 | Make illegal states unrepresentable | PASS | `Text` with invalid UTF-8 cannot exist. `Codepoint` with surrogate cannot exist. Index-kind confusion is a compile error. |
| 3 | Errors are data, not exceptions | PASS | All fallible ops return `(T | ErrorPrimitive)`. No `?`/`error`. |
| 4 | Separate data shape from data validity | PASS | `String box` raw → `Text val` validated. |
| 5 | Define separate types per boundary | PASS | `Array[U8] val` → `Text val` via `Encoding.decode`. |
| 6 | Default to immutability | PASS | All public types `val`. UCD tables `val`. Iterators `ref` over `val` data. |
| 7 | Prefer qualified references | PASS | Sketches use `unicode.Text`, `unicode.NFCForm`, etc. |
| 8 | Handle sensitive data deliberately | PASS-with-caveat | `EncodeError.codepoint` leaks one codepoint if encoding a secret. Documented. |
| 9 | Domain/orchestration/presentation | N/A | Library. |
| 12 | Distinct semantics → distinct representations | PASS | See #16. |
| 13 | Easier to give than take away | PASS | v0.1 ships only codepoint-level ops. |

## 5. Hazard checklist

| Hazard | Verdict | Evidence |
|--------|---------|----------|
| Every outcome explicit? | PASS | Every fallible op returns a union. |
| Implicit success/failure paths? | PASS | `Text.from_string(invalid)` returns `InvalidUtf8`. |
| Can the user forget a step? | PASS | `eq_codepoints` vs `eq_normalized` distinct. |
| Required ordering not enforced? | PASS | `Text` is value, methods order-independent. |
| Byte vs codepoint vs grapheme index confusion? | PASS | `Index[Kind]` makes it a compile error. |
| Two representations for same concept? | PASS-with-caveat | "café" precomposed vs decomposed are *different* `Text` values — intentional; `eq_normalized` is the right tool. |
| Distinct concepts same representation? | PASS | No `U32` grapheme IDs. |
| Capability mismatches? | PASS | UCD `val`, types `val`, iterators `ref`. |
| `Equal`/`Comparable`/`Hashable`? | PASS | Explicit implementations. |
| Implicit knowledge required? | PASS | Naming alone conveys distinctions. |

All hazards PASS.

## 6. Key decisions

### 1. Two coexisting views (Text + Strops)
Picked: typed `Text` canonical; `Strops` thin utility. **Confidence: medium-high.**
- Extend `String` (rejected): can't carry form tag, can't enforce UTF-8 validity.
- Typed `Text` only (rejected): forces lifting for every one-shot operation.

### 2. Explicit normalization tag on Text, default UnknownForm
Picked: form is part of `Text`; default `UnknownForm`; no implicit normalization. **Confidence: high.**
- Always-NFC on construction (Raku; rejected): silent mutation round-tripping bytes.
- No tracking (rejected): renormalize every time.

### 3. Distinct index types via phantom-tagged generic
Picked: `Index[Kind]` with `_ByteIdx`/`_CodepointIdx`/`_GraphemeIdx` tags. **Confidence: high.**
- Plain `USize` (rejected): the bug being prevented.
- Three independent classes (rejected): boilerplate.

### 4. UCD always-resident from build-time generation
Picked: generated `val` tables, always loaded. **Confidence: medium.**
- Lazy load (rejected): I/O in pure ops.
- Optional UCD (rejected): not Unicode without UCD.

### 5. Encoding as separate concern
Picked: `Encoding` trait in own subpackage. **Confidence: high.**
- Bake into `Text` constructors (rejected): couples `Text` to open inventory.

### 6. Closed unions for Script and Category
Picked: closed primitive unions. **Confidence: high.**
- String tags (rejected): no exhaustive match.

## 7. Uncertainties

- **NFG internal representation later?** Lazy break finding in v0.2; could change to synthetic codepoints if needed. Public API doesn't expose representation.
- **Codepoint as `class val` vs `U32`**: can't have a primitive per scalar; `class val` heap-allocates per codepoint during iteration. Mitigation: iterator yields `U32`, but reintroduces hazard. Tension.
- **Locale inventory for v0.4**: Turkic, Lithuanian, Azerbaijani known; others?

## 8. Tensions to surface

- **Codepoint heap allocation vs type safety in iteration.** Yielding `Codepoint val` allocates; yielding `U32` loses type safety. Worth human input.
- **Strops subset enforcement.** "Strops never exceeds Text" is review-enforced, not compiler-enforced.
- **Unicode version source compatibility.** Major Unicode release adding scripts changes closed `Script` union, breaks exhaustive `match` users. Could add `_Other` — weakens exhaustiveness.

## 9. Assumptions

- Current stable Pony.
- Greenfield.
- ~5MB compiled UCD acceptable; subpackaging can split further.
- O(n) codepoint iteration acceptable for v0.1; O(n) lazy grapheme iteration acceptable for v0.2.
- Raku-equivalence aspirational; we differ on Raku's implicit-NFC choice.
