use "pony_bench"
use "../unicode"

primitive BenchCompares
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)

    // Worst case for each predicate: both strings are equal under the
    // operation, so the comparison has to walk the entire length.
    let ascii_a = _Corpora.ascii(size)
    let ascii_b = _Corpora.ascii(size)
    let latin_a = _Corpora.latin_precomposed(size)
    let latin_b = _Corpora.latin_precomposed(size)

    bench(_BenchPair("Compares.bytes/ascii/" + lbl,
      ascii_a, ascii_b,
      {(a: String box, b: String box) =>
        DoNotOptimise[Compare](Compares.bytes(a, b))
        DoNotOptimise.observe()
      }, cfg))

    bench(_BenchPair("Compares.equal_bytes/ascii/" + lbl,
      ascii_a, ascii_b,
      {(a: String box, b: String box) =>
        DoNotOptimise[Bool](Compares.equal_bytes(a, b))
        DoNotOptimise.observe()
      }, cfg))

    bench(_BenchPair("Compares.equal_canonical/latin/" + lbl,
      latin_a, latin_b,
      {(a: String box, b: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Compares.equal_canonical(a, b))
        DoNotOptimise.observe()
      }, cfg))

    bench(_BenchPair("Compares.equal_compat/latin/" + lbl,
      latin_a, latin_b,
      {(a: String box, b: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Compares.equal_compat(a, b))
        DoNotOptimise.observe()
      }, cfg))

    bench(_BenchPair("Compares.equal_caseless/latin/" + lbl,
      latin_a, latin_b,
      {(a: String box, b: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Compares.equal_caseless(a, b))
        DoNotOptimise.observe()
      }, cfg))

    bench(_BenchPair("Compares.equal_caseless_canonical/latin/" + lbl,
      latin_a, latin_b,
      {(a: String box, b: String box) =>
        DoNotOptimise[(Bool | InvalidUtf8)](
          Compares.equal_caseless_canonical(a, b))
        DoNotOptimise.observe()
      }, cfg))
