// Shared two-level `match` emitter for cp-range → variant tables.
//
// Replaces the older hex-blob-plus-binary-search lookup with a code-
// generated nested match:
//
//     match cp >> 12          // 4096-cp bucket index (no guards)
//     | 0x0000 =>
//       match cp              // linear chain of upper-bound arms
//       | let c: U32 if c <= 0x0009 => GBControl
//       | ...
//       else GBOther
//       end
//     | 0x0001 => ...
//     ...
//     else GBOther
//     end
//
// The top-level `match cp >> 12` has no guards — the patterns are
// plain integer literals — so LLVM lowers it to a switch / jump
// table. Inner per-bucket matches have at most a few dozen arms, so
// even a linear scan inside one bucket is cheap.
//
// Ranges that span more than one 4096-cp bucket are split at bucket
// boundaries before emission so every emitted arm lives inside
// exactly one bucket.

primitive _RangeMatchEmitter
  fun emit(
    out: String ref,
    ranges: Array[(U32, U32, U8)] val,
    byte_to_variant: {(U8): String val} val,
    default_variant: String val)
  =>
    """
    Emit the body of an `of(cp: U32): X => …` lookup as a two-level
    match. `ranges` MUST be sorted by `range_lo` ascending and
    non-overlapping. `byte_to_variant` maps each property byte to the
    runtime variant name (e.g., `U8(1) => "GBCR"`). `default_variant`
    is the variant returned for codepoints outside any range
    (e.g., `"GBOther"`, `"Cn"`).
    """
    let split = _split_at_buckets(ranges)
    out.append("    match cp >> 12\n")
    var prev_bucket: U32 = 0xFFFFFFFF
    var bucket_open: Bool = false
    var prev_hi_plus_1: U32 = 0
    for r in split.values() do
      let bucket = r._1 >> 12
      if bucket != prev_bucket then
        if bucket_open then
          out.append("      else ")
          out.append(default_variant)
          out.append("\n      end\n")
        end
        out.append("    | 0x")
        emit_hex_u32(out, bucket)
        out.append(" =>\n")
        out.append("      match cp\n")
        prev_hi_plus_1 = bucket << 12
        bucket_open = true
        prev_bucket = bucket
      end
      if r._1 > prev_hi_plus_1 then
        out.append("      | let c: U32 if c <= 0x")
        emit_hex_u32(out, r._1 - 1)
        out.append(" => ")
        out.append(default_variant)
        out.append("\n")
      end
      out.append("      | let c: U32 if c <= 0x")
      emit_hex_u32(out, r._2)
      out.append(" => ")
      out.append(byte_to_variant(r._3))
      out.append("\n")
      prev_hi_plus_1 = r._2 + 1
    end
    if bucket_open then
      out.append("      else ")
      out.append(default_variant)
      out.append("\n      end\n")
    end
    out.append("    else\n")
    out.append("      ")
    out.append(default_variant)
    out.append("\n")
    out.append("    end\n")

  fun _split_at_buckets(
    ranges: Array[(U32, U32, U8)] val): Array[(U32, U32, U8)] val
  =>
    """
    Split every input range so each output sub-range stays inside one
    4096-cp bucket. The split preserves ordering so the result is
    still sorted by `range_lo`.
    """
    recover val
      let out = Array[(U32, U32, U8)]
      for r in ranges.values() do
        var lo = r._1
        while lo <= r._2 do
          let bucket = lo >> 12
          let bucket_end = ((bucket + 1) << 12) - 1
          let hi = if r._2 < bucket_end then r._2 else bucket_end end
          out.push((lo, hi, r._3))
          lo = hi + 1
        end
      end
      out
    end

  fun emit_hex_u32(out: String ref, value: U32) =>
    """
    Emit `value` as 4+ uppercase hex digits (no `0x` prefix), padded
    to at least 4 chars for readability.
    """
    let digits = "0123456789ABCDEF"
    let nibbles = recover ref Array[U8](8) end
    var n = value
    if n == 0 then nibbles.push('0') end
    while n > 0 do
      try nibbles.push(digits(USize.from[U32](n and 0xF))?) end
      n = n >> 4
    end
    while nibbles.size() < 4 do nibbles.push('0') end
    var i = nibbles.size()
    while i > 0 do
      try out.push(nibbles(i - 1)?) end
      i = i - 1
    end
