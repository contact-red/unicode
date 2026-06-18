use "pony_bench"

primitive BenchSizes
  """
  Size buckets every size-sensitive benchmark is run across, plus helpers
  for labelling and tuning the per-bucket iteration budget. Same layout
  as the sibling `string_benchmark` project so cross-comparisons line up.
  """
  fun apply(): Array[USize] val =>
    [as USize: 16; 160; 1_600; 16_000; 160_000; 1_600_000; 16_000_000; 160_000_000]

  fun smoke(): Array[USize] val =>
    """
    Single small bucket — used by the smoke build to confirm the harness
    boots and a benchmark completes before exercising the full size range.
    """
    [as USize: 1_600]

  fun label(size: USize): String =>
    if size >= 1_048_576 then (size / 1_048_576).string() + "M"
    elseif size >= 1_024 then (size / 1_024).string() + "K"
    else size.string() + "B"
    end

  fun samples(): USize => 20
  fun sample_ns(): U64 => 30_000_000

  fun heavy_op_cap(): USize =>
    """
    Maximum input size for "heavy" operations — ones whose per-byte cost
    is high enough that a single iteration at 160M takes minutes
    (`Text.from_string[indexed]` builds an O(n) grapheme bitmap;
    `Normalize.nfc` over `combining_marks` runs the canonical reorder
    over a 6-cp combining run per base letter, then composes). Gate
    such registrations with `if size <= BenchSizes.heavy_op_cap()`.
    Tighten this if even 16M takes too long; loosen once the
    implementations are fast enough that the top bucket is tractable.
    """
    16_000_000

  fun default_cfg(): BenchConfig =>
    BenchConfig(where samples' = samples(), max_sample_time' = sample_ns())

  fun cfg(size: USize): BenchConfig =>
    """
    Allocating benchmarks accumulate per-iteration garbage inside a single
    sample. Bound iterations so large sizes don't generate gigabytes of
    garbage before GC runs. Mirrors the string_benchmark calibration.
    """
    let max_it: U64 =
      if size >= 1_048_576 then 1_024
      elseif size >= 65_536 then 4_096
      elseif size >= 4_096 then 100_000
      else 1_000_000
      end
    let s: USize =
      if size >= 1_048_576 then samples().min(5)
      elseif size >= 65_536 then samples().min(10)
      else samples()
      end
    BenchConfig(where
      samples' = s,
      max_iterations' = max_it,
      max_sample_time' = sample_ns())

class iso _Overhead is MicroBenchmark
  """
  Overhead benchmark sized to the actual benchmark's config so the
  subtraction uses the same sample budget. pony_bench's built-in
  `OverheadBenchmark` always uses the default 20-sample/100ms config,
  which is far larger than the smallest buckets need.
  """
  let _config: BenchConfig
  new iso create(config': BenchConfig) => _config = config'
  fun name(): String => "Benchmark Overhead"
  fun config(): BenchConfig => _config
  fun overhead(): MicroBenchmark^ => _Overhead(_config)
  fun ref apply() =>
    DoNotOptimise[None](None)
    DoNotOptimise.observe()

class iso _Bench is MicroBenchmark
  """
  Read-only benchmark (box-receiver). The subject is built once and never
  mutated, so no per-iteration reset is needed.
  """
  let _name: String
  let _s: String val
  let _op: {(String box) ?} val
  let _config: BenchConfig

  new iso create(
    name': String,
    s: String val,
    op: {(String box) ?} val,
    config': BenchConfig = BenchSizes.default_cfg())
  =>
    _name = name'
    _s = s
    _op = op
    _config = config'

  fun name(): String => _name
  fun config(): BenchConfig => _config
  fun overhead(): MicroBenchmark^ => _Overhead(_config)
  fun ref apply() ? => _op(_s)?

class iso _ValBench is MicroBenchmark
  """
  Val-receiver benchmark — for ops that take `String val` (e.g.
  `Text.from_iso_string` returns iso but most ops want box; this is for
  the cases where the iso input is consumed).
  """
  let _name: String
  let _s: String val
  let _op: {(String val) ?} val
  let _config: BenchConfig

  new iso create(
    name': String,
    s: String val,
    op: {(String val) ?} val,
    config': BenchConfig = BenchSizes.default_cfg())
  =>
    _name = name'
    _s = s
    _op = op
    _config = config'

  fun name(): String => _name
  fun config(): BenchConfig => _config
  fun overhead(): MicroBenchmark^ => _Overhead(_config)
  fun ref apply() ? => _op(_s)?

class iso _CtorBench is MicroBenchmark
  """
  Constructor benchmark. The op captures whatever (val) inputs it needs
  and builds + observes a fresh result each iteration.
  """
  let _name: String
  let _op: {() ?} val
  let _config: BenchConfig

  new iso create(
    name': String,
    op: {() ?} val,
    config': BenchConfig = BenchSizes.default_cfg())
  =>
    _name = name'
    _op = op
    _config = config'

  fun name(): String => _name
  fun config(): BenchConfig => _config
  fun overhead(): MicroBenchmark^ => _Overhead(_config)
  fun ref apply() ? => _op()?

class iso _BenchPair is MicroBenchmark
  """
  Pair-input benchmark for binary ops like `Compares.equal_*(a, b)` or
  `Search.contains(haystack, needle)`. Both strings are built once.
  """
  let _name: String
  let _a: String val
  let _b: String val
  let _op: {(String box, String box) ?} val
  let _config: BenchConfig

  new iso create(
    name': String,
    a: String val,
    b: String val,
    op: {(String box, String box) ?} val,
    config': BenchConfig = BenchSizes.default_cfg())
  =>
    _name = name'
    _a = a
    _b = b
    _op = op
    _config = config'

  fun name(): String => _name
  fun config(): BenchConfig => _config
  fun overhead(): MicroBenchmark^ => _Overhead(_config)
  fun ref apply() ? => _op(_a, _b)?

class iso _BenchU32 is MicroBenchmark
  """
  Single-codepoint benchmark for property lookups (`category`, `script`,
  etc.). Carries a U32 directly so the op doesn't pay String boxing.
  """
  let _name: String
  let _cp: U32
  let _op: {(U32)} val
  let _config: BenchConfig

  new iso create(
    name': String,
    cp: U32,
    op: {(U32)} val,
    config': BenchConfig = BenchSizes.default_cfg())
  =>
    _name = name'
    _cp = cp
    _op = op
    _config = config'

  fun name(): String => _name
  fun config(): BenchConfig => _config
  fun overhead(): MicroBenchmark^ => _Overhead(_config)
  fun ref apply() => _op(_cp)
