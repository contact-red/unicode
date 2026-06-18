use "pony_bench"
use "../unicode"

primitive BenchText
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
    let emoji = _Corpora.emoji(size)

    _from_string(bench, "Text.from_string/ascii/" + lbl, ascii, cfg)
    _from_string(bench, "Text.from_string/cjk/" + lbl, cjk, cfg)
    _from_string(bench, "Text.from_string/mixed/" + lbl, mixed, cfg)
    _from_string(bench, "Text.from_string/emoji/" + lbl, emoji, cfg)

    _from_string_indexed(bench,
      "Text.from_string[indexed]/ascii/" + lbl, ascii, cfg)
    _from_string_indexed(bench,
      "Text.from_string[indexed]/cjk/" + lbl, cjk, cfg)
    _from_string_indexed(bench,
      "Text.from_string[indexed]/emoji/" + lbl, emoji, cfg)

  fun _from_string(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) ? =>
        DoNotOptimise[Text val](Text.from_string(s.clone())?)
        DoNotOptimise.observe()
      }, cfg))

  fun _from_string_indexed(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) ? =>
        DoNotOptimise[Text val](
          Text.from_string(s.clone() where indexed = true)?)
        DoNotOptimise.observe()
      }, cfg))
