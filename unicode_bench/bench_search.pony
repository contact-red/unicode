use "pony_bench"
use "../unicode"

primitive BenchSearch
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let cjk = _Corpora.cjk(size)

    // Three cases per op: needle absent (worst-case for `contains`/
    // `index_of`), present early, present at the very end.
    bench(_Bench("Search.contains[absent]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Search.contains(s, "NOMATCH_XYZ_123"))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Search.contains[present]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Search.contains(s, "quick"))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Search.index_of[absent]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(USize | None | InvalidUtf8)](
          Search.index_of(s, "NOMATCH"))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Search.last_index_of[absent]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(USize | None | InvalidUtf8)](
          Search.last_index_of(s, "NOMATCH"))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Search.count[dense]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(USize | InvalidUtf8)](Search.count(s, "the"))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Search.starts_with/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Search.starts_with(s, "The"))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Search.ends_with/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Search.ends_with(s, "  "))
        DoNotOptimise.observe()
      }, cfg))

    // Multi-byte needle search.
    bench(_Bench("Search.contains[present]/cjk/" + lbl, cjk,
      {(s: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Search.contains(s, "中国"))
        DoNotOptimise.observe()
      }, cfg))
