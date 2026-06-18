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
    end

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
