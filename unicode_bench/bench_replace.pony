use "pony_bench"
use "../unicode"

primitive BenchReplace
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)

    // Dense matches: "the" appears many times in the ascii corpus.
    bench(_Bench("Replace.all[dense]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](
          Replace.all(s, "the", "THE"))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Replace.first[dense]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](
          Replace.first(s, "the", "THE"))
        DoNotOptimise.observe()
      }, cfg))

    // No matches: must walk the whole string for a needle that isn't
    // there.
    bench(_Bench("Replace.all[absent]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](
          Replace.all(s, "NOMATCH_XYZ", "anything"))
        DoNotOptimise.observe()
      }, cfg))

    // Same-size replacement vs growing replacement (different copying
    // strategies in Replace.all).
    bench(_Bench("Replace.all[grow]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](
          Replace.all(s, "the", "th_e_"))
        DoNotOptimise.observe()
      }, cfg))
