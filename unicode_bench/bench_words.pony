use "pony_bench"
use "../unicode"

primitive BenchWords
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let mixed = _Corpora.mixed(size)
    let cjk = _Corpora.cjk(size)

    bench(_Bench("Words.count/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Words.count(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Words.count/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Words.count(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Words.count/cjk/" + lbl, cjk,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Words.count(s))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Words.ranges-walk/ascii/" + lbl, ascii,
      {(s: String box) =>
        match Words.ranges(s)
        | let it: Iterator[(USize, USize)] =>
          var n: USize = 0
          while it.has_next() do
            try (let lo, let hi) = it.next()?; DoNotOptimise[USize](lo + hi) end
            n = n + 1
          end
          DoNotOptimise[USize](n)
        end
        DoNotOptimise.observe()
      }, cfg))
