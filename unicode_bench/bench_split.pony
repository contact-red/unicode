use "pony_bench"
use "../unicode"

primitive BenchSplit
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)

    bench(_Bench("Split.on[space]/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(Array[String val] val | InvalidUtf8)](
          Split.on(s, " "))
        DoNotOptimise.observe()
      }, cfg))

    // Lines: build a corpus with explicit \n separators.
    let with_nl = recover val
      let out = String(size + 64)
      out.append(ascii)
      out.append("\nsecond line\nthird line\r\nfourth\r\n")
      out
    end
    bench(_Bench("Split.lines/" + lbl, with_nl,
      {(s: String box) =>
        DoNotOptimise[(Array[String val] val | InvalidUtf8)](
          Split.lines(s))
        DoNotOptimise.observe()
      }, cfg))
