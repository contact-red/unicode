use "pony_bench"
use "../unicode"

primitive BenchCodepoints
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    // Single-cp property lookups: size-independent — register once.
    _single_cp(bench)

    // Whole-string count: size-sensitive.
    for size in sizes.values() do
      _count_size(bench, size)
    end

  fun _single_cp(bench: PonyBench) =>
    let cfg = BenchSizes.default_cfg()
    let cps: Array[(U32, String)] val =
      [as (U32, String):
        (U32('A'),  "ascii")
        (U32(0xE9), "latin1")
        (U32(0x4E2D), "cjk")
        (U32(0x1F600), "emoji")
      ]
    for c in cps.values() do
      (let cp, let lbl) = c
      bench(_BenchU32("Codepoints.category/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[Category](Codepoints.category(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.script/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[Script](Codepoints.script(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.script_extensions/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[Array[Script] val](
            Codepoints.script_extensions(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.east_asian_width/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[EastAsianWidth](Codepoints.east_asian_width(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.has_binary_property/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[Bool](
            Codepoints.has_binary_property(cp, PropAlphabetic))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.name/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(String val | None)](Codepoints.name(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.combining_class/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[U8](Codepoints.combining_class(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.grapheme_break/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[GraphemeBreak](Codepoints.grapheme_break(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.canonical_decomposition/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(Array[U32] val | None)](
            Codepoints.canonical_decomposition(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.compat_decomposition/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(Array[U32] val | None)](
            Codepoints.compat_decomposition(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.simple_upper/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[U32](Codepoints.simple_upper(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.simple_lower/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[U32](Codepoints.simple_lower(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.simple_title/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[U32](Codepoints.simple_title(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.simple_casefold/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[U32](Codepoints.simple_casefold(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.full_upper/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(Array[U32] val | None)](
            Codepoints.full_upper(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.full_lower/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(Array[U32] val | None)](
            Codepoints.full_lower(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.full_title/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(Array[U32] val | None)](
            Codepoints.full_title(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.full_casefold/" + lbl, cp,
        {(cp: U32) =>
          DoNotOptimise[(Array[U32] val | None)](
            Codepoints.full_casefold(cp))
          DoNotOptimise.observe()
        }, cfg))
      bench(_BenchU32("Codepoints.is_full_composition_excluded/" + lbl,
        cp,
        {(cp: U32) =>
          DoNotOptimise[Bool](
            Codepoints.is_full_composition_excluded(cp))
          DoNotOptimise.observe()
        }, cfg))
    end

    // Binary composition — `e` + combining acute → `é`. Bench the
    // single-shot composition cost; covers the `_UcdCanonicalCompose`
    // lookup path used by `Normalize.nfc`.
    bench(_CtorBench("Codepoints.compose_canonical[hit]",
      {() =>
        DoNotOptimise[(U32 | None)](
          Codepoints.compose_canonical(0x0065, 0x0301))
        DoNotOptimise.observe()
      }, cfg))
    bench(_CtorBench("Codepoints.compose_canonical[miss]",
      {() =>
        DoNotOptimise[(U32 | None)](
          Codepoints.compose_canonical(0x0041, 0x0042))
        DoNotOptimise.observe()
      }, cfg))

    // Reverse name lookup — linear scan; the slow path.
    bench(_CtorBench("Codepoints.from_name",
      {() =>
        DoNotOptimise[(U32 | None)](
          Codepoints.from_name("LATIN CAPITAL LETTER A"))
        DoNotOptimise.observe()
      }, cfg))

  fun _count_size(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let cjk = _Corpora.cjk(size)
    let mixed = _Corpora.mixed(size)

    bench(_Bench("Codepoints.count/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Codepoints.count(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Codepoints.count/cjk/" + lbl, cjk,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Codepoints.count(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Codepoints.count/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Codepoints.count(s))
        DoNotOptimise.observe()
      }, cfg))
