use "pony_bench"
use "../unicode"

primitive BenchBytes
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)

    _is_valid(bench, "Bytes.is_valid_utf8/ascii/" + lbl,
      _Corpora.ascii(size), cfg)
    _is_valid(bench, "Bytes.is_valid_utf8/cjk/" + lbl,
      _Corpora.cjk(size), cfg)
    _is_valid(bench, "Bytes.is_valid_utf8/emoji/" + lbl,
      _Corpora.emoji(size), cfg)
    _is_valid(bench, "Bytes.is_valid_utf8/mixed/" + lbl,
      _Corpora.mixed(size), cfg)

    _first_bad(bench, "Bytes.first_bad_utf8_offset/ascii/" + lbl,
      _Corpora.ascii(size), cfg)
    _first_bad(bench, "Bytes.first_bad_utf8_offset/cjk/" + lbl,
      _Corpora.cjk(size), cfg)

  fun _is_valid(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[Bool](Bytes.is_valid_utf8(s))
        DoNotOptimise.observe()
      }, cfg))

  fun _first_bad(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[(AllValid | USize)](Bytes.first_bad_utf8_offset(s))
        DoNotOptimise.observe()
      }, cfg))
