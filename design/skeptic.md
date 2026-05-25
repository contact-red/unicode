# Skeptic — Minimal Unicode Package for Pony

## Approach (1-paragraph)

Subtraction-first. `String val` stays canonical text; the package is a set of namespaced `primitive` modules holding free functions over `String val`/`box` plus `U32` codepoints, with a small handful of iterator classes (graphemes, words, sentences, lines) and value types (`ScriptSet`, `NormForm` enum, error unions). No `Text` wrapper. No `Codepoint` newtype in hot paths (validation factory only). No `Grapheme` type — graphemes are zero-copy `String val` slices. UCD shipped as one embedded packed binary built by a separate codegen tool. Pin to one Unicode version per package release. Cut NFG, locale collation, name lookup, full property API, most decoders from v0.1.

## The actual user problems (reread without the proposed solution)

| Scenario | What the user actually wants |
|---|---|
| a. count visible characters | a function: `length(s: String box): USize` |
| b. case-insensitive normalized compare | `normalize(s).caseless_equal(normalize(t))` — functions |
| c. truncate at character N | `grapheme_offset(s, n): (USize \| None)`, then `s.trim` |
| d. validate "letters/digits" | codepoint predicates + codepoint iteration |
| e. iterate words/sentences/lines | three iterators yielding `String val` slices |
| f. read Latin-1 file as text | `decode_latin1(bytes): String iso^` |
| g. dictionary sort | `collation_key(s): Array[U8] val` plug into `Sort` |
| h. detect scripts | `scripts_of(s): ScriptSet val` |
| i. iterate codepoints/graphemes/bytes | use stdlib `runes()`, add `graphemes()` |
| j. codepoint properties | `Codepoint.is_letter(u32)` etc. |

**Nothing in this list demands a new String-like type.** Each item is a function returning `String iso^`, an iterator, a boolean, an integer, or a small value type. The pain is *missing functions*, not the absence of an encapsulating wrapper. That observation drives the whole design.

## Minimal viable design

### 1. No new `Text` / `UString` type

`String val` is the canonical text type. The package is:

- A handful of `primitive` namespaces holding free functions.
- Iterator classes (because iteration needs state).
- A few value types for things that genuinely aren't bytes / codepoints / strings.

Why: Pony's `String` is `val`-shareable, already what every other library returns. A wrapper forces every consumer to convert at the boundary, every IO library to either return `String` (and re-wrap) or duplicate APIs. The cost of universal conversion vastly exceeds "call `Unicode.length(s)` instead of `s.length()`."

What we lose: NFC-as-a-type-fact. Replaced with runtime quick-check + naming convention. (See Tension #1.)

### 2. Module layout

```
unicode/
  unicode.pony       -- top-level Unicode primitive (length, grapheme_offset, truncate, version)
  codepoint.pony     -- primitive Codepoint with U32-based queries
  grapheme.pony      -- primitive Grapheme + GraphemeIter
  word.pony          -- primitive Word + WordIter
  sentence.pony      -- primitive Sentence + SentenceIter
  line.pony          -- primitive Line + LineIter
  case.pony          -- primitive Case (lower/upper/title/fold, caseless_equal)
  normalize.pony     -- primitive Normalize + NormForm enum
  collate.pony       -- primitive Collate (key, compare) — root only in v0.1
  script.pony        -- primitive Script + ScriptSet
  decode.pony        -- primitive Decode (latin1, utf16_be/le/bom)
  _ucd.pony          -- package-private table reader; binary embedded
```

No traits. No interfaces. No inheritance hierarchy. Following pony-ref gotcha #9 (don't use marker traits to group variants), errors are union types.

### 3. Codepoint = `U32`, with a primitive `Codepoint` for queries

Argument for `U32`: Pony's stdlib already returns `U32` from `String.utf32`/`runes`. Property queries are pure functions of the integer. No boxing cost. Pony has no zero-cost newtypes — a wrapper class is a heap allocation per codepoint, lethal for hot iteration.

Argument for a newtype: type-level proof of scalar validity.

**Call**: iterators yield `U32`. Validate at the boundary only: `Codepoint.is_scalar(u32): Bool` predicate; `Codepoint.from_u32(u32): (U32 | InvalidCodepoint)` factory for the "I got this from a network protocol" case. Inside iterators that walk valid UTF-8, every yielded codepoint is by construction a scalar — no need for per-element validation tax.

What breaks if we delete the factory? Callers building codepoints from arithmetic risk passing 0xD800 to a property function. Keep it. What breaks if we wrap every iterator yield? Per-codepoint allocation. Don't.

### 4. Grapheme = `String val` slice, no type

Three candidates: `String val` slice, `Array[U32] val` of codepoints, or a `Grapheme` class.

A `Grapheme` type adds nothing over `String val` that a free function can't provide. `Grapheme.codepoints(g)` returns the array; `Grapheme.width(g)` returns east-asian width. Crucially: **"grapheme-ness" isn't preserved by any operation.** Concatenating two graphemes can produce a non-grapheme. Slicing produces a degenerate grapheme. There is no invariant a type would protect.

**Verdict**: graphemes are `String val` slices, iterators yield `String val` zero-copy.

Tension with Raku NFG: Raku encodes graphemes as synthetic codepoints so each is one integer. Cut, because:
- A new string representation breaks interop with every Pony IO API.
- The benefit (O(1) grapheme indexing) is rarely needed — most consumers iterate.
- When they want indexing, `Unicode.grapheme_offset(s, n)` gives the byte offset.

(See Tension #2.)

### 5. Case functions — free functions, don't try to fix `String`

Three options: (a) replace `String.lower()` — out of scope; (b) provide `Case.lower(s): String iso^` etc.; (c) both via a wrapper class.

**Pick (b).** Broken `String.lower()` staying broken is a real cost — callers will reach for it — but that's a docs problem, not justification for a wrapper type. We *also* recommend upstream a deprecation note on `String.lower()`.

### 6. Iteration

- Bytes: `String` already has byte iteration. **Don't duplicate.**
- Codepoints: stdlib `String.runes()` already yields `U32`. **Don't duplicate.**
- Graphemes: new. `Unicode.graphemes(s): GraphemeIter` yielding `String val`.
- Words/Sentences/Lines: new. Three more iterators. Each implements its own UAX algorithm (UAX #29 for words/sentences, UAX #14 for lines) — they cannot share an implementation.

### 7. Normalisation — runtime check, not a wrapper type

Wrapping NFC in a type forces every API to take `NFC` or `String`, which forces every caller to convert at the boundary. Cost outweighs benefit unless you have many distinct normalisation invariants in a single system.

**Decision**: `NormForm` is a `primitive` enum (`primitive NFC ... primitive NFD ...`, etc., grouped as union type). `Normalize.to(s, form: NormForm): String iso^`. `Normalize.is_nfc(s): Bool` does the UAX #15 quick-check (cheap, early-terminates on ASCII).

v0.1 ships NFC + NFD. NFKC + NFKD deferred to v0.2.

Yes, this is in tension with "make illegal states unrepresentable." See Tension #1.

### 8. Properties — only what we need + the obvious user-facing ones

Forced by other features: general category, script, east-asian width, bidi class, line break class, grapheme/word/sentence break classes, case-fold + simple case mappings, decomposition mapping, combining class.

User-facing for v0.1: GC, script, EAW, bidi class.

Cut from v0.1: name lookup (big table), alias names, formal aliases, ScriptExtensions, full property API.

### 9. Collation — root only

`Collate.key(s): Array[U8] val`, `Collate.compare(a, b): I32`. No CLDR tailoring in v0.1.

### 10. Decoders — Latin-1 + UTF-16 only

`Decode.latin1(bytes): String iso^` (total — every byte is a valid Latin-1 codepoint), `Decode.utf16_be/utf16_le/utf16(bytes): (String iso^ | DecodeError)`. Errors carry byte offset + reason. Shift-JIS / GB18030 / Big5 / Windows-1252 defer to v0.2.

### 11. Scripts + confusables

`Script.scripts_of(s): ScriptSet val`. `ScriptSet` is a small value type. `Confusable.skeleton(s): String iso^` ships v0.2 (full data is large).

### 12. UCD strategy — embed packed binary, build-tool external

Options:
- (A) Build-time codegen of `.pony` source files. Bloats source diffs.
- (B) Runtime-load from disk. Broken for embedded use, startup cost.
- (C) **Embedded packed binary** generated by a separate build tool (`unicode-build`), shipped as bytes in a `.pony` literal.

**Pick C.** Format: trie-based lookup for cp→property; CCC + decomp in a side table; break properties as range arrays (binary search); DUCET as packed weighted strings. ~1–3 MB embedded for v0.1 scope. `Unicode.version(): String val` returns the embedded version string. No runtime version switching — each release of the package is pinned to one UCD release.

### 13. Cut from Raku

- NFG synthetic codepoints
- String-as-grapheme-array indexing
- `.chars`/`.graphs`/`.codes`/`.uniprop` method profusion (replaced with namespaced free functions)
- Locale-tailored collation in v0.1
- Name-based lookup in v0.1
- Quotemeta / regex integration (regex is its own package)
- Encoding-aware IO (we ship transcoders; IO wires them)
- Lookup of every minor property

### 14. Better than Raku

- Errors as union types (`DecodeError`, `InvalidCodepoint`), not exceptions.
- Iterators producing `String val` slices that are immediately sendable across actors.
- Compile-time embedded tables — no runtime ICU dependency.
- NFC fast quick-check usable as a guard before allocating a normalised copy.

## Criticality ordering

**v0.1 — minimum that solves the listed scenarios**

| Module | Surface |
|---|---|
| Unicode | `length`, `grapheme_offset`, `truncate`, `version` |
| Codepoint | `is_scalar`, `from_u32`, `general_category`, `is_letter`, `is_digit`, `is_whitespace` |
| Grapheme | `graphemes(s)` iterator |
| Word | `words(s)` iterator |
| Sentence | `sentences(s)` iterator |
| Line | `lines(s)` iterator |
| Case | `lower`, `upper`, `title`, `fold`, `caseless_equal` |
| Normalize | `to_nfc`, `to_nfd`, `is_nfc`, `nfc_equal` |
| Collate | `key`, `compare` (root) |
| Script | `scripts_of`, `Script` enum, `ScriptSet` |
| Decode | `latin1`, `utf16_be`, `utf16_le`, `utf16` |
| _ucd | internal table reader |

**v0.2 — important but not blocking**

- NFKC/NFKD
- `Codepoint.name`, name lookup
- Confusables full data
- More properties (bidi class, east-asian width as user-facing surface)
- More decoders (Shift-JIS, Windows-1252)
- Locale-tailored collation (root + a few locales)

**v0.3+ — niche**

- Bidirectional algorithm (UAX #9)
- Full UCD property API
- Hangul/Han specifics
- Emoji segmentation refinements (UTS #51)

**Dependencies:**
- Everything → `_ucd`.
- Case + Normalize → property tables.
- Grapheme/Word/Sentence iterators → break property tables.
- Collate → DUCET.
- Script → Script property table.

## Consumer sketches

### (a) Count visible characters

```pony
use "unicode"

actor Main
  new create(env: Env) =>
    let s: String val = "café"
    let n: USize = Unicode.length(s)
    env.out.print("visible chars: " + n.string())  // 4
```

### (b) Compare usernames case-insensitively after normalisation

```pony
use "unicode"

primitive Auth
  fun same_user(a: String val, b: String val): Bool =>
    let na: String val = Normalize.to_nfc(a)
    let nb: String val = Normalize.to_nfc(b)
    Case.caseless_equal(na, nb)
```

### (c) Truncate display name at character N

```pony
use "unicode"

primitive Display
  fun truncate(s: String val, n: USize): String val =>
    match Unicode.grapheme_offset(s, n)
    | let off: USize => s.trim(0, off)  // zero-copy String val
    | None          => s
    end
```

### (d) Validate input: only letters and digits

```pony
use "unicode"

primitive Validate
  fun is_alnum(s: String val): Bool =>
    for cp in s.runes() do
      if not (Codepoint.is_letter(cp) or Codepoint.is_digit(cp)) then
        return false
      end
    end
    true
```

### (e) Iterate words

```pony
use "unicode"

actor Main
  new create(env: Env) =>
    let s: String val = "Hello, world! Привет."
    for word in Unicode.words(s) do
      env.out.print(word)
    end
```

### (f) Read a Latin-1 file as text

```pony
use "files"
use "unicode"

actor LoadLatin1
  new create(env: Env, auth: AmbientAuth, path: String val) =>
    let fp = FilePath(auth, path)
    match OpenFile(fp)
    | let f: File =>
      let bytes: Array[U8] iso = f.read(f.size())
      let text: String iso = Decode.latin1(consume bytes)
      env.out.print(consume text)
    end
```

### (g) Sort names in dictionary order

```pony
use "collections"
use "unicode"

primitive NameSort
  fun apply(names: Array[String val] ref) =>
    let pairs = Array[(Array[U8] val, String val)]
    for n in names.values() do
      pairs.push((Collate.key(n), n))
    end
    Sort[Array[(Array[U8] val, String val)], (Array[U8] val, String val)](pairs)
    names.clear()
    for (_, n) in pairs.values() do names.push(n) end
```

### (h) Detect mixed scripts

```pony
use "unicode"

primitive Domains
  fun mixed_script(s: String val): Bool =>
    Script.scripts_of(s).count_meaningful() > 1  // excludes Common/Inherited
```

### (j) Query codepoint properties

```pony
use "unicode"

let cp: U32 = 0x1F600
env.out.print(Codepoint.general_category(cp).string())  // "So"
env.out.print(Codepoint.is_emoji(cp).string())          // "true"
```

## Tensions to surface

### Tension 1 — Where does NFC live? (type vs runtime)

Cut the `NFC` newtype. "Make illegal states unrepresentable" wants a typed proof of normalisation. Counter: every Pony API returns `String`; a wrapper forces conversion at every boundary; the quick-check is ~free for ASCII; singling out NFC for typing while not typing every other string property is arbitrary.

I'd cut. Synthesizer's call.

### Tension 2 — Grapheme as `String val` vs newtype

Newtype gives documentation and a hanger for methods like `width()`. Counter: no invariant to protect (grapheme-ness isn't preserved by operations); methods can be free functions.

I'd cut. Easier to give than take away.

### Tension 3 — Decode functions vs Decoder objects

Free functions handle one-shot. Streaming chunked decode needs state. v0.1 ships functions; v0.2 adds `Decoder` objects for streaming if there's demonstrated need.

### Tension 4 — Iterator zero-copy assumption

Iterators yield `String val` slices and assume `String val.trim(...)` is zero-copy (matching the `Array[U8] val.trim()` pattern noted in pony-ref). **Verify this empirically before committing.** If `String.trim` allocates on `val`, the whole iteration design needs revising and the per-grapheme cost becomes painful.

### Tension 5 — Codepoint U32 vs wrapper

Hot iterator paths in Pony can't tolerate per-element boxing. Wrapper type would be ~50–100x slower for property scans. Stick with `U32`.

### Tension 6 — Just fix String upstream?

The most radical subtraction. Counter: stdlib governance is not ours; `String` would gain hundreds of methods; UCD data would be in the runtime even for programs that never touch text; Unicode version pinned to ponyc release cadence. Keep as a package; upstream only a tiny deprecation hint on `String.lower()`.

## UCD strategy summary

- Separate `unicode-build` codegen tool reads UCD release files, emits a packed binary `ucd.bin` + a `version.pony` constant.
- `unicode` package embeds the bytes (e.g., via a generated source containing an `Array[U8] val` literal).
- Format: trie for cp→property; CCC + decomp side table; break properties as sorted range arrays (binary search); DUCET packed weighted strings.
- One Unicode version per package release. `Unicode.version()` returns it. No runtime switching.
- ~1–3 MB embedded at v0.1 scope. Acceptable.

## Key decisions table

| Decision | Alternatives | Confidence | Reasoning |
|---|---|---|---|
| `String val` is canonical; no `Text` wrapper | New typed string; NFG-style synthetic codepoints | High | Boundary-conversion cost across all IO is the dominant force |
| Codepoint = `U32`, validation factory only | `Codepoint` newtype class everywhere | High | Pony lacks zero-cost newtypes; iterator hot paths can't afford boxing |
| Grapheme = `String val` slice | `Grapheme` class wrapping bytes or codepoints | Med-High | No invariant to protect; documentation can live in docstrings |
| Normalisation form via runtime check, not type | `NFC` newtype carrying a proof | Medium | Tension with "illegal states unrepresentable"; chose simpler surface |
| Iterators as separate classes (Grapheme/Word/Sentence/Line) | One unified iterator with mode flag | High | Different UAX algorithms, no shared implementation |
| Free functions in `primitive` namespaces, not traits | Trait-based polymorphic API | High | pony-ref gotcha #9 — closed surface, no extension points needed |
| UCD as embedded packed binary built by external tool | Codegen .pony source; runtime-load files | High | Single artifact, fast load, works in embedded, doesn't bloat source |
| One Unicode version per package release | Runtime version switching; multi-version support | High | Premature flexibility; YAGNI |
| Errors as union types | Pony `error`/partial functions throughout | High | pony-ref gotcha #9 + principle 3 (errors as data) |
| Cut NFG | Implement NFG-equivalent storage | High | Breaks every Pony IO API; benefit is rarely needed |
| Cut locale-tailored collation from v0.1 | Ship CLDR root + tailorings | Medium | Smaller audience, deferrable |
| Cut name lookup from v0.1 | Ship with full UCD names | Medium | Large table for limited use |

## Uncertainties

- Whether `String val.trim(...)` is actually zero-copy. If `String.trim` allocates on `val`, iterator design needs revisiting (Tension #4).
- Exact UCD embedded size — estimated 1–3 MB for v0.1 scope but not measured.
- Whether other personas will tolerate the runtime-normalisation-form approach.
- Whether `Unicode.words` / `.lines` / `.sentences` should live as methods on `Unicode` or as `Word.iter(s)` / `Line.iter(s)`.

## Assumptions

- Pony stdlib `String.runes()` exists and yields `U32` for codepoint iteration.
- `String val.trim` is zero-copy or close to it. (See Uncertainties.)
- Build-tool can be a separate package that consumers don't depend on at runtime.
- One Unicode version per release is acceptable.
- ICU FFI is *not* on the table — design assumes pure-Pony implementation with embedded data.
- "General text processing" doesn't include regex (separate package) or bidi rendering (UAX #9, deferred).
