use "pony_bench"
use "../unicode"

primitive BenchTrim
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)

    // Construct a padded input: whitespace at both ends, content in middle.
    let padded = recover val
      let out = String(size + 64)
      out.append("\t\n   ")
      out.append(_Corpora.ascii(size))
      out.append("   \n\t")
      out
    end

    bench(_Bench("Trim.trim/" + lbl, padded,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Trim.trim(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Trim.trim_start/" + lbl, padded,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Trim.trim_start(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Trim.trim_end/" + lbl, padded,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Trim.trim_end(s))
        DoNotOptimise.observe()
      }, cfg))
