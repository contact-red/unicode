use "pony_bench"
use "../unicode"

primitive BenchNormalize
  fun register(bench: PonyBench, sizes: Array[USize] val) =>
    for size in sizes.values() do
      _one(bench, size)
    end

  fun _one(bench: PonyBench, size: USize) =>
    let cfg = BenchSizes.cfg(size)
    let lbl = BenchSizes.label(size)
    let ascii = _Corpora.ascii(size)
    let latin_pre = _Corpora.latin_precomposed(size)
    let latin_dec = _Corpora.latin_decomposed(size)
    let combining = _Corpora.combining_marks(size)

    _nfd(bench, "Normalize.nfd/ascii/" + lbl, ascii, cfg)
    _nfd(bench, "Normalize.nfd/latin-pre/" + lbl, latin_pre, cfg)

    // NFC composition is the headline workload — decomposed and
    // pathological combining-marks corpora are the worst cases.
    _nfc(bench, "Normalize.nfc/ascii/" + lbl, ascii, cfg)
    _nfc(bench, "Normalize.nfc/latin-pre/" + lbl, latin_pre, cfg)
    _nfc(bench, "Normalize.nfc/latin-dec/" + lbl, latin_dec, cfg)
    _nfc(bench, "Normalize.nfc/combining/" + lbl, combining, cfg)

    _nfkd(bench, "Normalize.nfkd/latin-pre/" + lbl, latin_pre, cfg)
    _nfkc(bench, "Normalize.nfkc/latin-pre/" + lbl, latin_pre, cfg)

  fun _nfd(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Normalize.nfd(s))
        DoNotOptimise.observe()
      }, cfg))

  fun _nfc(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Normalize.nfc(s))
        DoNotOptimise.observe()
      }, cfg))

  fun _nfkd(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Normalize.nfkd(s))
        DoNotOptimise.observe()
      }, cfg))

  fun _nfkc(
    bench: PonyBench,
    name: String,
    s: String val,
    cfg: BenchConfig)
  =>
    bench(_Bench(name, s,
      {(s: String box) =>
        DoNotOptimise[(String iso | InvalidUtf8)](Normalize.nfkc(s))
        DoNotOptimise.observe()
      }, cfg))
