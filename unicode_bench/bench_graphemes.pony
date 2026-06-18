use "pony_bench"
use "../unicode"

primitive BenchGraphemes
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let latin = _Corpora.latin_precomposed(size)
    let cjk = _Corpora.cjk(size)
    let emoji = _Corpora.emoji(size)

    _count(bench, "Graphemes.count/ascii/" + lbl, ascii, cfg)
    _count(bench, "Graphemes.count/latin/" + lbl, latin, cfg)
    _count(bench, "Graphemes.count/cjk/" + lbl, cjk, cfg)
    _count(bench, "Graphemes.count/emoji/" + lbl, emoji, cfg)

    _ranges(bench, "Graphemes.ranges-walk/ascii/" + lbl, ascii, cfg)
    _ranges(bench, "Graphemes.ranges-walk/cjk/" + lbl, cjk, cfg)
    _ranges(bench, "Graphemes.ranges-walk/emoji/" + lbl, emoji, cfg)

  fun _count(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Graphemes.count(s))
        DoNotOptimise.observe()
      }, cfg))

  fun _ranges(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        match Graphemes.ranges(s)
        | let it: Iterator[(USize, USize)] =>
          var n: USize = 0
          while it.has_next() do
            try (let lo, let hi) = it.next()?; DoNotOptimise[USize](lo + hi) end
            n = n + 1
          end
          DoNotOptimise[USize](n)
        | let _: InvalidUtf8 => None
        end
        DoNotOptimise.observe()
      }, cfg))
