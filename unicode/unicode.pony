"""
# `unicode` — End-User Guide (0.2.0)

This document is the user-facing reference for the `unicode` package as
of the 0.2.0 release. It assumes a working knowledge of Pony's
reference capabilities (val / iso / box / ref) — see the
[Pony tutorial](https://tutorial.ponylang.io/) if those are new.

Conformance baseline: **Unicode 16.0.0**. All five UCD conformance
suites pass at 100% (NormalizationTest Part 1 + Part 2,
GraphemeBreakTest, WordBreakTest, SentenceBreakTest, LineBreakTest).

## Contents

1. [Getting started](#1-getting-started)
2. [The dual surface — `Text` and topical primitives](#2-the-dual-surface--text-and-topical-primitives)
3. [Constructing a `Text`](#3-constructing-a-text)
4. [Iterating: bytes, codepoints, graphemes, words, sentences, lines](#4-iterating-bytes-codepoints-graphemes-words-sentences-lines)
5. [Codepoint properties](#5-codepoint-properties)
6. [Normalization — UAX #15](#6-normalization--uax-15)
7. [Case operations](#7-case-operations)
8. [Comparison — UAX #21](#8-comparison--uax-21)
9. [Searching, splitting, trimming, replacing](#9-searching-splitting-trimming-replacing)
10. [Script analysis and mixed-script detection — UAX #24 / UAX #39](#10-script-analysis-and-mixed-script-detection--uax-24--uax-39)
11. [Indices — phantom-typed positions](#11-indices--phantom-typed-positions)
12. [Error types](#12-error-types)
13. [Cheat sheet — "I want to…"](#13-cheat-sheet--i-want-to)

---

## 1. Getting started

Install via [corral](https://github.com/ponylang/corral):

```sh
corral add github.com/contact-red/unicode.git --version 0.2.0
corral fetch
```

```pony
use "unicode"

actor Main
  new create(env: Env) =>
    try
      let t = Text.from_string("Hello, world!")?
      env.out.print("bytes: " + t.size_bytes().string())
      env.out.print("graphemes: " + t.size_graphemes().string())
    else
      env.out.print("invalid UTF-8 input")
    end
```

Every constructor that validates UTF-8 is a partial method (`?`). The
caller decides what "invalid input" means — there is no silent
substitution of replacement characters.

---

## 2. The dual surface — `Text` and topical primitives

The package exposes the same operations through two surfaces:

- **`Text`** (`class val`) — the typed entry point. Construction
  validates UTF-8 once; every subsequent method on the resulting
  `Text val` can assume the invariant.
- **Topical primitives** (`Words`, `Sentences`, `Lines`, `Normalize`,
  `Case`, `Compares`, `Search`, `Split`, `Trim`, `Replace`, `Scripts`,
  `Graphemes`, `Codepoints`, `Bytes`) — free-function-style operations
  on `String box`. They validate UTF-8 on entry and return either a
  result or an `InvalidUtf8` error.

Internally both surfaces delegate to the same package-private
underscore-prefixed methods, so behavior cannot drift between them.

```pony
// These two are equivalent — pick whichever fits the call site.

// Surface A: Text
let t = Text.from_string("café")?
for g in t.graphemes() do env.out.print(g) end

// Surface B: topical primitive on a String box
match Graphemes.iter("café")
| let it: Iterator[String val] =>
  while it.has_next() do try env.out.print(it.next()?) end end
| let _: InvalidUtf8 => env.err.print("bad UTF-8")
end
```

The two surfaces have complementary strengths:

| Use `Text` when… | Use a topical primitive when… |
|---|---|
| You'll perform many operations on the same string | One-shot operation on a `String box` parameter |
| You want O(1) `size_graphemes` (with `indexed=true`) | You don't want to allocate a `Text` wrapper |
| You're holding the validated invariant across a boundary | You want to handle `InvalidUtf8` at the call site |

---

## 3. Constructing a `Text`

```pony
// From a String val. The default capability for a Pony string
// literal is val, so this is the common case.
let t1: Text val = Text.from_string("hello")?

// From an existing iso String, consuming it (zero copy).
let s: String iso = "hello".clone()
let t2: Text val = Text.from_iso_string(consume s)?

// From a UTF-8 byte array (val).
let bytes: Array[U8] val = recover val [as U8: 'h'; 'i'] end
let t3: Text val = Text.from_array(bytes)?

// From an iso byte array, consuming it (zero copy).
let buf: Array[U8] iso = recover iso Array[U8] end
buf.push('h'); buf.push('i')
let t4: Text val = Text.from_iso_array(consume buf)?
```

### Optional grapheme bitmap index

Each constructor accepts an `indexed: Bool` flag (default `false`).
With `indexed = true`, the `Text` carries a bitmap marking grapheme
boundaries. This makes `size_graphemes()`, `size_codepoints()`,
`grapheme_at(i)`, and `slice_graphemes(lo, hi)` O(1) at the cost of
~12.5% extra memory.

```pony
let t = Text.from_string("こんにちは", where indexed = true)?
// O(1) now:
let n: USize = t.size_graphemes()
match t.grapheme_index(2)
| let gi: GraphemeIndex =>
  match t.grapheme_at(gi)
  | let s: String val => env.out.print(s)
  | let _: OutOfRange => None
  end
end
```

You can flip the index on or off after construction:

```pony
let with_index = t.with_index()?
let without = t.without_index()?
```

Construction failure is signalled by Pony's `?` partial-method
mechanism. The runtime never raises with a typed error from
construction; the caller's `try` block catches an untyped error. Use
the topical primitives if you need to know **where** the bad byte was
— `Bytes.first_bad_utf8_offset` returns either `AllValid` or the byte
offset of the first invalid sequence:

```pony
match Bytes.first_bad_utf8_offset(some_string)
| AllValid => env.out.print("valid")
| let off: USize =>
  env.out.print("invalid byte at offset " + off.string())
end
```

---

## 4. Iterating: bytes, codepoints, graphemes, words, sentences, lines

Five segmentation levels are exposed, each with three shapes (count,
ranges, iter). Pick the shape that fits your performance budget:

| Shape | Allocates per element | Best for |
|---|---|---|
| `count(s)` | nothing | "how many?" |
| `ranges(s)` | nothing | walk byte offsets without materializing slices |
| `iter(s)` | a `String val` slice wrapper per element | callers that want a `String` per segment |

```pony
// Count — minimal cost
let n_words: (USize | InvalidUtf8) = Words.count("Hello there friend.")

// Ranges — zero per-yield allocation
match Sentences.ranges(some_text)
| let it: Iterator[(USize, USize)] =>
  while it.has_next() do
    try (let lo, let hi) = it.next()? end
  end
end

// Iter — String slice per element (zero byte copy)
match Lines.iter(some_text)
| let it: Iterator[String val] =>
  for line in it do env.out.print(line) end
end
```

### From `Text`

`Text` exposes the same five levels with the validated invariant
already in hand — no error variant:

```pony
let t = Text.from_string("Hi there. Bye now.")?

t.size_bytes()         // USize
t.size_codepoints()    // USize  (O(1) on indexed Text)
t.size_graphemes()     // USize  (O(1) on indexed Text)

for g in t.graphemes() do env.out.print(g) end
for w in t.words() do env.out.print(w) end
for s in t.sentences() do env.out.print(s) end
for ln in t.lines() do env.out.print(ln) end

// Byte-range variants (Pony for-each doesn't tuple-destructure;
// pull the components off `r._1` / `r._2`).
for r in t.grapheme_ranges() do
  env.out.print(r._1.string() + ".." + r._2.string())
end
```

### What does each segmentation level mean?

- **Bytes** — UTF-8 bytes. Use `t.size_bytes()` or
  `t.utf8_bytes()` (the latter returns an `iso` clone).
- **Codepoints** — Unicode scalar values. `t.codepoint_at(idx)`
  returns a `Codepoint val`. The hot iteration path uses the
  underlying `String.runes()` for bare `U32`.
- **Graphemes** — UAX #29 extended grapheme clusters. The
  user-perceived characters: `"é"` is one grapheme,
  `"🇫🇷"` (two regional indicators) is one grapheme,
  `"👨‍👩‍👧"` (a ZWJ sequence) is one grapheme.
- **Words** — UAX #29 word boundaries. Each yielded segment is a
  boundary-delimited run; **punctuation and whitespace get their own
  segments too**. Filter on the first cp of each segment if you want
  only words-as-text:
  ```pony
  for w in t.words() do
    try
      let first_cp = w.runes().next()?
      if Codepoints.is_letter(first_cp) or
        Codepoints.is_digit(first_cp) then
        env.out.print("word: " + w)
      end
    end
  end
  ```
- **Sentences** — UAX #29 sentence boundaries. Each segment ends at
  a sentence break; punctuation that ends a sentence is included in
  the preceding sentence segment.
- **Lines** — UAX #14 line-break opportunities. Each yielded segment
  ends where a line break **could** occur (either a mandatory break
  — LF, CR, NEL — or a soft opportunity).

---

## 5. Codepoint properties

The `Codepoint val` typed wrapper carries instance-method ergonomics;
the `Codepoints` primitive offers the same operations on bare `U32`.

### Constructing a `Codepoint`

```pony
match Codepoints.from_u32(0x1F600)  // 😀
| let cp: Codepoint val => env.out.print(cp.string())  // "U+1F600"
| let err: InvalidScalar =>
  env.err.print("not a scalar: " + err.string())
end
```

`InvalidScalar` is raised for surrogates (U+D800..U+DFFF) and values
above U+10FFFF.

### Instance methods on `Codepoint val`

```pony
try
  let cp = Codepoints.from_u32(0xE9) as Codepoint val  // 'é'

  cp.scalar()                  // U32 = 0xE9
  cp.category()                // Category = Ll
  cp.is_letter()               // Bool = true
  cp.is_digit()                // Bool = false
  cp.is_whitespace()           // Bool = false
  cp.is_assigned()             // Bool = true (i.e. category != Cn)
  cp.combining_class()         // U8  = 0 (precomposed é)
  cp.canonical_decomposition() // Array[U32] val = [0x65, 0x301]
  cp.script()                  // Script = ScriptLatin
  cp.script_extensions()       // Array[Script] val
  cp.has_property(PropAlphabetic) // Bool
  cp.east_asian_width()        // EastAsianWidth = EAWA
  cp.string()                  // "U+00E9"

  // Equality / comparison (structural Equatable[Codepoint] etc.)
  let a = Codepoints.from_u32(0x41) as Codepoint val
  let b = Codepoints.from_u32(0x42) as Codepoint val
  a.eq(b)                      // false
  a.lt(b)                      // true
  a.hash()                     // USize
end
```

The `as Codepoint val` cast is partial — it raises if the cp turned
out to be an `InvalidScalar`. Wrap in `try`, or use the `match`
pattern below when you want to handle the error case explicitly.

### Primitive equivalents (on bare `U32`)

When you don't want to construct a typed `Codepoint`, every method
above has a `Codepoints.*(u: U32, …)` form:

```pony
Codepoints.category(U32('A'))                  // Lu
Codepoints.script(0x4E2D)                      // ScriptHan
Codepoints.script_extensions(0x0640)           // many scripts
Codepoints.east_asian_width(0xFF09)            // EAWF
Codepoints.has_binary_property(0x0041,
  PropAlphabetic)                              // true
Codepoints.combining_class(0x0301)             // 230 (Above)
Codepoints.canonical_decomposition(0xE9)       // [0x65, 0x301]
Codepoints.compat_decomposition(0xFB01)        // [0x66, 0x69]
Codepoints.is_letter(U32('A'))                 // true
Codepoints.is_digit(U32('5'))                  // true
Codepoints.is_whitespace(U32(' '))             // true
Codepoints.is_assigned(0x50005)                // false (reserved)
```

### Codepoint names

```pony
// Forward lookup
Codepoints.name(0x0041)              // "LATIN CAPITAL LETTER A"
Codepoints.name(0x10000)             // None (algorithmic — CJK ideograph)

// Reverse lookup (linear scan over ~30k entries — for interactive
// use, not hot paths)
Codepoints.from_name("LATIN CAPITAL LETTER A")  // 0x0041
Codepoints.from_name("NOT A REAL NAME")         // None
```

### Closed-union types

The following types are **closed unions** — every variant is a
distinct primitive, and `match \exhaustive\` is compile-checked. New
Unicode versions that add variants are semver-significant breaks.

| Union | Variants | Source |
|---|---|---|
| `Category` | 30 General_Category codes | UnicodeData.txt |
| `Script` | 163 scripts | Scripts.txt |
| `BinaryProperty` | ~58 binary properties | PropList + DerivedCore + emoji-data |
| `EastAsianWidth` | `EAWA`, `EAWF`, `EAWH`, `EAWN`, `EAWNa`, `EAWW` | EastAsianWidth.txt |
| `GraphemeBreak` | UAX #29 grapheme-break values | GraphemeBreakProperty.txt |
| `WordBreak` | UAX #29 word-break values | WordBreakProperty.txt |
| `SentenceBreak` | UAX #29 sentence-break values | SentenceBreakProperty.txt |
| `LineBreak` | 48 UAX #14 line-break values | LineBreak.txt |
| `IndicConjunctBreak` | `InCBNone`, `InCBConsonant`, `InCBLinker`, `InCBExtend` | DerivedCoreProperties.txt |
| `NormalForm` | `NFC`, `NFD`, `NFKC`, `NFKD` | UAX #15 |

Each variant is a `primitive`. Match by primitive type:

```pony
match Codepoints.category(some_cp)
| Ll => env.out.print("lowercase letter")
| Lu => env.out.print("uppercase letter")
| Nd => env.out.print("decimal digit")
| Cn => env.out.print("unassigned")
else env.out.print("other")
end
```

To go from a name string to a closed-union variant, use the
`*s.from_iso` helpers:

```pony
Scripts.from_iso("Latin")     // ScriptLatin (or None)
EastAsianWidths.from_iso("W") // EAWW (or None)
BinaryProperties.from_iso("Alphabetic") // PropAlphabetic
```

---

## 6. Normalization — UAX #15

Four normal forms are available. All four take a `String box` and
return either an `iso` string or `InvalidUtf8`:

```pony
match Normalize.nfd("café")            // canonical decomposition
| let s: String iso => env.out.print(consume s)
| let _: InvalidUtf8 => None
end

Normalize.nfc("café")    // canonical composition
Normalize.nfkd("ﬁ")      // compatibility decomposition: "ﬁ" → "fi"
Normalize.nfkc("ﬁ")      // compatibility composition
```

Picking a form:

| Form | What it does | Use case |
|---|---|---|
| **NFD** | Decompose to constituent codepoints | Visual layout, combining-mark analysis |
| **NFC** | Decompose then recompose | **The web default; storage / interchange** |
| **NFKD** | Compatibility decompose | Search, identifier folding, "look like the same character?" |
| **NFKC** | Compatibility decompose then recompose | Identifier normalization with composed output |

A worked example: combining marks compare equal under NFC.

```pony
let precomposed = "café"   // 'é' = U+00E9
let decomposed  = "café"   // 'e' + U+0301 combining acute
// Same Unicode text; different byte sequences:
Compares.equal_bytes(precomposed, decomposed)      // false
Compares.equal_canonical(precomposed, decomposed)  // true
```

Algorithmic Hangul decomposition / composition is implemented (the
table is the Hangul block; the work is the algorithm in UAX #15
§16). NFKD also handles ligature compatibility decompositions (e.g.
`ﬁ` U+FB01 → `f` + `i`).

---

## 7. Case operations

`Case` provides four operations with full multi-codepoint expansions:

```pony
Case.upper("Maße")        // "MASSE"  (ß → SS expansion)
Case.lower("CAFÉ")        // "café"
Case.title("hello world") // "Hello World"
Case.fold("Maße")         // "masse"  (UAX #21 case folding)
```

Each method returns `(String iso^ | InvalidUtf8)`.

Worth knowing:

- **Eszett (`ß` → `SS`)** — uppercase is a two-character expansion.
  `Case.upper("Maße")` returns `"MASSE"`, not `"MAßE"`. The full
  case mapping table from `SpecialCasing.txt` handles this.
- **Ligature `ﬁ` (U+FB01)** — case mappings preserve the ligature.
  `Case.upper("ﬁ")` is `"FI"` (a two-cp expansion). NFKD also
  decomposes it.
- **Greek final sigma (`ς` ↔ `Σ`)** — context-dependent special
  casing is NOT implemented (it's marked conditional in
  `SpecialCasing.txt`). The bundled tables cover the
  unconditional entries only. For now, `Case.lower("ΣΟΦΟΣ")` yields
  `"σοφοσ"`, not `"σοφος"`.
- **Turkish "I"** — Turkish `i ↔ İ` and `ı ↔ I` mappings are also
  conditional and not currently applied. Plain `Case.lower("I")` →
  `"i"` regardless of locale.

For case-insensitive **comparison** (rather than transformation),
prefer `Compares.equal_caseless` — see the next section.

---

## 8. Comparison — UAX #21

There is no single "correct" string equality for Unicode. `Compares`
exposes five flavours, each with different normative behavior:

| Operation | What it ignores | When to use |
|---|---|---|
| `equal_bytes(a, b)` | nothing | Exact byte equality |
| `equal_canonical(a, b)` | canonical-equivalent differences (precomposed vs decomposed `é`) | "is this the same Unicode text?" |
| `equal_compat(a, b)` | compatibility-equivalent differences (e.g. `ﬁ` ≅ `fi`) | Identifier matching, fuzzy match |
| `equal_caseless(a, b)` | case differences (fold-then-byte) | Case-insensitive search/comparison |
| `equal_caseless_canonical(a, b)` | case + canonical equivalence | **UAX #21 D146 — the recommended caseless+canonical default** |

```pony
Compares.equal_canonical("café", "café")           // true
Compares.equal_compat("ﬁre", "fire")               // true
Compares.equal_caseless("Maße", "MASSE")           // true
Compares.equal_caseless_canonical("CAFÉ", "café")  // true
```

`Compares.bytes(a, b): Compare` returns the standard `Less | Equal |
Greater` triple for byte-order sorting. For *user-visible* sort
(locale-aware collation per UAX #10), wait for the `0.4.0` release.

**Security note**: `equal_caseless_canonical` is good for general
case-insensitive matching, but is **not safe** for security-critical
identifier matching against homograph attacks. Use the script-based
predicates in §10 to detect mixed-script input first, or wait for
the `0.5.0` `eq_identifier` primitive.

---

## 9. Searching, splitting, trimming, replacing

These ops all work at the **byte** level (no grapheme-aware variants
yet). The string-level inputs must be valid UTF-8.

### Search

```pony
Search.contains("hello world", "world")     // true
Search.starts_with("hello", "he")           // true
Search.ends_with("hello", "lo")             // true
Search.index_of("hello world", "world")     // 6  (or None)
Search.last_index_of("aabbab", "ab")        // 4
Search.count("ababa", "ab")                 // 2
```

Each method returns either the matching result or
`InvalidUtf8(offset)`.

### Split

```pony
// Split on a separator. Returns Array[String val] val.
match Split.on("a,b,c", ",")
| let parts: Array[String val] val =>
  for p in parts.values() do env.out.print(p) end  // a, b, c
end

// Split on line terminators (LF, CR, CR+LF — UAX #14 mandatory breaks).
match Split.lines("first\r\nsecond\nthird")
| let lines: Array[String val] val =>
  // ["first", "second", "third"]
end
```

For *line-break opportunities* (soft breaks too), use `Lines` /
`Text.lines` from §4 instead.

### Trim

`Trim` operates over the UCD `White_Space` binary property:

```pony
Trim.trim("  hello  ")        // "hello"
Trim.trim_start("\n\thello")  // "hello"
Trim.trim_end("hello\n")      // "hello"
```

### Replace

```pony
Replace.all("foo bar foo", "foo", "qux")  // "qux bar qux"
Replace.first("foo bar foo", "foo", "qux") // "qux bar foo"
```

---

## 10. Script analysis and mixed-script detection — UAX #24 / UAX #39

This is the main 0.2.0 addition for security and identifier work.

### Per-codepoint script

Every codepoint has a primary `Script` and (optionally) a
`Script_Extensions` set of additional scripts it's used in.

```pony
Codepoints.script(U32('A'))              // ScriptLatin
Codepoints.script(0x4E2D)                // ScriptHan
Codepoints.script(0x0640)                // ScriptArabic

// Script_Extensions — extra scripts a cp is shared across.
// For cps not in ScriptExtensions.txt, this returns [script(u)].
Codepoints.script_extensions(0x0640).size()   // many
Codepoints.script_extensions(U32('A')).size() // 1 (just Latin)
```

`Codepoint.script()` and `Codepoint.script_extensions()` are the
instance-method versions on a typed `Codepoint val`.

### The `ScriptSet` value type

`ScriptSet` is a `class val` carrying a sorted, deduplicated set of
`Script`s. It supports the four ops you'd expect:

```pony
// Construct from a list of scripts (any order, any duplicates).
let s: ScriptSet val = ScriptSet.create([
  as Script: ScriptLatin; ScriptCyrillic; ScriptLatin
])

s.size()                  // 2 (deduped)
s.contains(ScriptLatin)   // true
s.contains(ScriptGreek)   // false
s.to_array()              // Array[Script] val

// Empty set
let none: ScriptSet val = ScriptSet.empty()

// Drop Common / Inherited (digits, punctuation, combining marks fit
// any script — `resolved` strips them).
let with_common = ScriptSet.create([
  as Script: ScriptLatin; ScriptCommon; ScriptInherited
])
let just_real = with_common.resolved()  // {ScriptLatin}
```

### String-level analysis: the `Scripts` primitive

```pony
// Union of script(cp) across every cp in the string.
Scripts.of("abc")             // {Latin}
Scripts.of("abc123")          // {Latin, Common}
Scripts.of("abc123").resolved() // {Latin}  (Common dropped)

// Most-frequent non-Common/Inherited script. Ties broken by
// first-seen. Returns ScriptCommon for empty / all-Common input.
Scripts.dominant("hello world")   // ScriptLatin
Scripts.dominant("Aбвг")          // ScriptCyrillic (3 vs 1)
Scripts.dominant("")              // ScriptCommon
Scripts.dominant("12345")         // ScriptCommon

// from_iso — script-name lookup
Scripts.from_iso("Latin")         // ScriptLatin
Scripts.from_iso("Cyrillic")      // ScriptCyrillic
Scripts.from_iso("NotAScript")    // None
```

### Mixed-script detection (UAX #39 §5.1)

The classic homograph-attack shape: Latin `A` (U+0041) and Cyrillic
`А` (U+0410) look identical. `Scripts.is_single_script` flags them.

```pony
Scripts.is_single_script("hello world")     // true   (Latin)
Scripts.is_single_script("123 + 456")       // true   (all Common)
Scripts.is_single_script("")                // true   (empty)
Scripts.is_single_script("AА")              // false  (homograph)
Scripts.is_single_script("abc мир")         // false  (Latin + Cyrillic)
```

The underlying algorithm intersects `Script_Extensions` across all
non-Common/non-Inherited codepoints. To see the resolved set
directly:

```pony
let r = Scripts.resolved_script_set("abc123")
r.size()                  // 1
r.contains(ScriptLatin)   // true

let mixed = Scripts.resolved_script_set("AА")
mixed.size()              // 0 (intersection collapsed)
```

A string of only Common / Inherited codepoints (`"12345"`,
`""`) yields an empty `ScriptSet` from `resolved_script_set`, but
`is_single_script` still returns `true` — empty input is trivially
single-script. Use `is_single_script` if that's the answer you want;
use `resolved_script_set` if you want the candidate scripts.

### Identifier allowlist policies

`Scripts.restrict_to(s, allowed)` answers "does every codepoint in
`s` fit inside the `allowed` script set?" — the predicate for
identifier-policy enforcement.

```pony
// Latin-only identifier policy.
let latin_only: ScriptSet val = ScriptSet.create([as Script: ScriptLatin])

Scripts.restrict_to("hello", latin_only)         // true
Scripts.restrict_to("hello, world!", latin_only) // true  (',' is Common)
Scripts.restrict_to("abc123", latin_only)        // true  (digits are Common)
Scripts.restrict_to("AА", latin_only)            // false (Cyrillic А)
Scripts.restrict_to("ｐassword", latin_only)     // false (fullwidth ｐ)
```

The predicate uses `Script_Extensions` (not the bare `Script`), so a
codepoint that's commonly used in multiple scripts passes when *any*
of its extensions is in the allowlist.

### The `Text` shortcuts

```pony
let t = Text.from_string("hello мир")?

t.scripts()                       // ScriptSet val {Latin, Cyrillic, Common}
t.scripts().resolved()            // {Latin, Cyrillic}
t.dominant_script()               // ScriptLatin (5 vs 3)
t.contains_unassigned_codepoint() // false
```

`contains_unassigned_codepoint()` is a quick filter: any codepoint
with `General_Category = Cn` (unassigned, reserved) in user input is
usually a sign of bad data or someone exploiting Unicode-version skew
between systems.

```pony
let buf = recover trn String end
buf.push_utf32(0x50005)  // a reserved cp
let t = Text.from_string(consume buf)?
t.contains_unassigned_codepoint()  // true
```

---

## 11. Indices — phantom-typed positions

The package distinguishes byte / codepoint / grapheme positions at
compile time via a phantom-typed `Index[Kind]`. You can't accidentally
pass a byte offset where a grapheme index was expected.

```pony
let t = Text.from_string("café 🇫🇷", where indexed = true)?

// Construct indices by position number.
let b: (ByteIndex      | OutOfRange) = t.byte_index(3)
let c: (CodepointIndex | OutOfRange) = t.codepoint_index(2)
let g: (GraphemeIndex  | OutOfRange) = t.grapheme_index(1)

// Lookups consume the typed index.
match t.grapheme_index(1)
| let gi: GraphemeIndex =>
  match t.grapheme_at(gi)
  | let s: String val => env.out.print(s)
  | let _: OutOfRange => None
  end
end

// Convert between coordinate systems when you need to.
match t.codepoint_index(2)
| let ci: CodepointIndex =>
  match t.codepoint_byte_index(ci)
  | let bi: ByteIndex => env.out.print("byte: " + bi.value().string())
  end
end
```

The index types are `val`. `OutOfRange` carries the requested index
and the actual size of the dimension, so you can build useful error
messages.

---

## 12. Error types

Every error is a `class val` (so it can carry data) and structurally
satisfies `Stringable`. All are explicit return values — none are
raised via Pony's exception channel.

| Type | Fields | Where |
|---|---|---|
| `InvalidUtf8` | `offset: USize` | Returned from primitive-surface ops on invalid input |
| `InvalidScalar` | `value: U32` | `Codepoints.from_u32` for surrogates / out-of-range |
| `OutOfRange` | `index: USize`, `size: USize` | Any indexed accessor on `Text` |

```pony
match Codepoints.from_u32(0xD800)
| let _: Codepoint val => None
| let err: InvalidScalar =>
  env.err.print("not a scalar: U+"
    + err.value.string() + " (surrogate or out of range)")
end

match t.codepoint_index(9999)
| let ci: CodepointIndex =>
  match t.codepoint_at(ci)
  | let cp: Codepoint val => None
  | let err: OutOfRange => env.err.print(err.string())
  end
| let err: OutOfRange => env.err.print(err.string())
end
```

Construction (`Text.from_string`, `Text.from_array`, etc.) does
raise via `?` — the failure type isn't carried in a union because the
constructor's only failure mode is "invalid UTF-8". Use
`Bytes.first_bad_utf8_offset` first if you need the offset.

---

## 13. Cheat sheet — "I want to…"

| Goal | Call |
|---|---|
| Validate UTF-8 | `Bytes.is_valid_utf8(s)` or `Bytes.first_bad_utf8_offset(s)` |
| Construct a Text | `Text.from_string(s)?` |
| Count user-visible characters | `t.size_graphemes()` (O(1) on indexed Text) |
| Iterate graphemes | `for g in t.graphemes()` |
| Split into words / sentences / lines | `t.words()` / `t.sentences()` / `t.lines()` |
| Get a codepoint's properties | `cp.category()`, `cp.script()`, `cp.has_property(p)`, … |
| Normalize for storage / interchange | `Normalize.nfc(s)` |
| Normalize for identifier matching | `Normalize.nfkc(s)` |
| Compare "is the same text?" | `Compares.equal_canonical(a, b)` |
| Compare case-insensitively | `Compares.equal_caseless_canonical(a, b)` |
| Search for a substring | `Search.contains(haystack, needle)` |
| Replace all occurrences | `Replace.all(s, needle, replacement)` |
| Trim whitespace | `Trim.trim(s)` |
| Uppercase / lowercase | `Case.upper(s)` / `Case.lower(s)` |
| Detect homograph mixes | `not Scripts.is_single_script(s)` |
| Enforce a script allowlist | `Scripts.restrict_to(s, allowed)` |
| Reject input with reserved cps | `t.contains_unassigned_codepoint()` |
| Convert between byte / cp / grapheme positions | `t.codepoint_byte_index(ci)`, `t.grapheme_byte_index(gi)` |

---

## See also

- [`CHANGELOG.md`](../CHANGELOG.md) — release notes
- [`design/candidate-v3.md`](../design/candidate-v3.md) — the design document this implementation derives from
- The auto-generated docs (`make docs`) — every public docstring rendered by `pony-doc`
"""

primitive Unicode
  """
  Top-level package handle. Exposes the Unicode version this build is pinned
  to.
  """
  fun version(): String val =>
    """
    The Unicode version against which this package's bundled UCD tables were
    generated. Format is dotted (e.g., "16.0.0").
    """
    "0.0.0"  // M0 placeholder; populated by `unicode-build` in M1.
