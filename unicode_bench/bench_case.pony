use "pony_bench"
use "../unicode"

primitive BenchCase
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let latin = _Corpora.latin_precomposed(size)
    let mixed = _Corpora.mixed(size)

    _op(bench, "Case.upper/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Case.upper(s))
        DoNotOptimise.observe()
      }, cfg)
    _op(bench, "Case.upper/latin/" + lbl, latin,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Case.upper(s))
        DoNotOptimise.observe()
      }, cfg)
    _op(bench, "Case.lower/latin/" + lbl, latin,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Case.lower(s))
        DoNotOptimise.observe()
      }, cfg)
    _op(bench, "Case.title/latin/" + lbl, latin,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Case.title(s))
        DoNotOptimise.observe()
      }, cfg)
    _op(bench, "Case.fold/latin/" + lbl, latin,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Case.fold(s))
        DoNotOptimise.observe()
      }, cfg)
    _op(bench, "Case.fold/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Case.fold(s))
        DoNotOptimise.observe()
      }, cfg)

  fun _op(
    bench: PonyBench,
    name: String,
    s: String val,
    op: {(String box) ?} val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s, op, cfg))
