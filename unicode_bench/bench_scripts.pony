use "pony_bench"
use "../unicode"

primitive BenchScripts
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

    bench(_Bench("Scripts.of/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[ScriptSet val](Scripts.of(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Scripts.of/cjk/" + lbl, cjk,
      {(s: String box) =>
        DoNotOptimise[ScriptSet val](Scripts.of(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Scripts.of/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[ScriptSet val](Scripts.of(s))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Scripts.dominant/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[Script](Scripts.dominant(s))
        DoNotOptimise.observe()
      }, cfg))

    let allowed = ScriptSet.create([as Script: ScriptLatin])
    bench(_Bench("Scripts.restrict_to[Latin-only]/ascii/" + lbl, ascii,
      {(s: String box)(allowed) =>
        DoNotOptimise[Bool](Scripts.restrict_to(s, allowed))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Scripts.restrict_to[Latin-only]/mixed/" + lbl, mixed,
      {(s: String box)(allowed) =>
        DoNotOptimise[Bool](Scripts.restrict_to(s, allowed))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Scripts.is_single_script/ascii/" + lbl, ascii,
      {(s: String box) =>
        DoNotOptimise[Bool](Scripts.is_single_script(s))
        DoNotOptimise.observe()
      }, cfg))
    bench(_Bench("Scripts.is_single_script/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[Bool](Scripts.is_single_script(s))
        DoNotOptimise.observe()
      }, cfg))

    bench(_Bench("Scripts.resolved_script_set/mixed/" + lbl, mixed,
      {(s: String box) =>
        DoNotOptimise[ScriptSet val](Scripts.resolved_script_set(s))
        DoNotOptimise.observe()
      }, cfg))
