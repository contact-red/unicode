use "pony_bench"
use "../unicode"

primitive BenchLines
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let cjk = _Corpora.cjk(size)
    let mixed = _Corpora.mixed(size)

    bench(_Bench("Lines.count/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Lines.count(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Lines.count/cjk/" + lbl, cjk,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Lines.count(s))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Lines.ranges-walk/ascii/" + lbl, ascii,
      {(s: String box) =>
        match Lines.ranges(s)
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
    bench(_Bench("Lines.ranges-walk/mixed/" + lbl, mixed,
      {(s: String box) =>
        match Lines.ranges(s)
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
