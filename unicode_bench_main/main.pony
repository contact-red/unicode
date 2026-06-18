use "pony_bench"
use "../unicode"
use "../unicode_bench"

actor Main is BenchmarkList
  """
  Entry point for the unicode benchmark suite. Each topic primitive
  (BenchBytes, BenchText, …) registers its benchmarks against the
  `PonyBench` actor in `create`. `benchmarks(bench)` is a no-op — all
  registration happens here in `create` because we want corpora prepared
  once and then handed to each topic.

  Run modes:
    `./unicode_bench_main`          — full suite (every size bucket)
    `./unicode_bench_main --smoke`  — single small bucket only
    `./unicode_bench_main -csv`     — machine-readable CSV (pony_bench flag)

  Recommended ponyc flag: `--ponynoyield` (see pony_bench docs). Release
  builds matter — the debug build is 10× slower and only useful for
  shaking out compile errors.
  """
  new create(env: Env) =>
    var smoke: Bool = false
    for a in env.args.values() do
      if a == "--smoke" then smoke = true end
    end
    let pb = PonyBench(env, this)
    let sizes = if smoke then BenchSizes.smoke() else BenchSizes() end

    BenchBytes.register(pb, sizes)
    BenchText.register(pb, sizes)
    BenchCodepoints.register(pb, sizes)
    BenchGraphemes.register(pb, sizes)
    BenchWords.register(pb, sizes)
    BenchSentences.register(pb, sizes)
    BenchLines.register(pb, sizes)
    BenchNormalize.register(pb, sizes)
    BenchCase.register(pb, sizes)
    BenchCompares.register(pb, sizes)
    BenchSearch.register(pb, sizes)
    BenchSplit.register(pb, sizes)
    BenchTrim.register(pb, sizes)
    BenchReplace.register(pb, sizes)
    BenchScripts.register(pb, sizes)

  fun tag benchmarks(bench: PonyBench) =>
    None
