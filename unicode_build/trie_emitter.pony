use "collections"

// Shared two-stage trie emitter for cp-range -> single-byte tables.
//
// Replaces the older two-level `match cp >> 12` dispatch for tables
// whose value is one byte per codepoint. The match form costs a linear
// `c <= bound` scan within each 4096-cp bucket (up to a few hundred
// comparisons for dense scripts); a trie is two array loads regardless.
//
// Output is a pair of files:
//   - a C file with two `static const` blobs (stage1 + stage2) and a
//     `<prefix>_lookup(cp)` function that does the two-load index. ponyc's
//     bundled C compiler compiles co-located `.c` files; the blobs land in
//     `.rodata` (mmap'd, zero startup decode, full 0..255 byte range).
//   - a Pony file whose `of(cp)` calls the C lookup via FFI and maps the
//     byte to the runtime variant.
//
// stage1[cp >> shift] selects a `block`-byte run in stage2; identical
// blocks are deduplicated so the all-default runs (most of the codepoint
// space) collapse to one shared block. The block size is chosen per table
// to minimise total bytes. stage1 is uint8_t when the unique-block count
// fits in a byte, else uint16_t.
//
// Why a C blob and not a Pony literal: a Pony `Array[U8]` literal of this
// size sends ponyc's typechecker into a multi-hour spin (one AST node per
// element); a `"\xNN"` String literal corrupts bytes >= 0x80 (Pony reads
// `\xNN` as a Unicode codepoint escape). See category_table.pony history.

primitive _TrieEmitter
  fun emit(
    header: String val,
    prim_name: String val,
    ret_type: String val,
    value_open: String val,
    value_close: String val,
    c_prefix: String val,
    ranges: Array[(U32, U32, U8)] val,
    default_byte: U8,
    extra_body: String val = "")
    : (String iso^, String iso^)
  =>
    """
    Generate (pony_source, c_source) for a cp -> byte trie table.
    `extra_body` is appended verbatim after `of` (e.g. a `byte_of`
    accessor for callers that want the raw stage byte).

    `ranges` MUST be sorted by range_lo and non-overlapping; they hold the
    non-default entries (codepoints outside any range get `default_byte`).
    `value_open`/`value_close` wrap the FFI call in the Pony `of` body:
    e.g. ("GraphemeBreaks._from_byte(", ")") yields
    `GraphemeBreaks._from_byte(@<prefix>_lookup(cp))`; ("", "") yields the
    raw `@<prefix>_lookup(cp)` for tables whose value is the byte itself.
    """
    let maxcp: USize = 0x110000

    // 1. Expand ranges into a full cp -> byte map.
    let v = Array[U8].init(default_byte, maxcp)
    for r in ranges.values() do
      var cp = r._1.usize()
      let hi = r._2.usize()
      while (cp <= hi) and (cp < maxcp) do
        try v(cp)? = r._3 end
        cp = cp + 1
      end
    end

    // 2. Choose the block size that minimises total bytes.
    var best_total = USize.max_value()
    var best_block: USize = 256
    var best_shift: USize = 8
    var best_s1: Array[USize] val = recover val Array[USize] end
    var best_s2: Array[U8] val = recover val Array[U8] end
    for shift in [as USize: 6; 7; 8; 9; 10].values() do
      let block = USize(1) << shift
      (let s1, let s2) = _build_trie(v, maxcp, block)
      let nblocks = s2.size() / block
      let s1w: USize = if nblocks <= 256 then 1 else 2 end
      let total = (s1.size() * s1w) + s2.size()
      if total < best_total then
        best_total = total
        best_block = block
        best_shift = shift
        best_s1 = s1
        best_s2 = s2
      end
    end

    let nblocks = best_s2.size() / best_block
    let s1_ctype: String val = if nblocks > 256 then "uint16_t" else "uint8_t"
      end
    let prefix = c_prefix
    let dflt: String val = default_byte.string()
    let blk: String val = best_block.string()
    let shf: String val = best_shift.string()
    let msk: String val = (best_block - 1).string()

    // Widen stage2 to USize for the shared array writer.
    let s2_usize = recover val
      let a = Array[USize](best_s2.size())
      for b in best_s2.values() do a.push(b.usize()) end
      a
    end

    // 3. C source.
    let c =
      recover iso
        let s = String(best_total * 5)
        s.append(header)
        s.append("\n#include <stdint.h>\n#include <stddef.h>\n\n")
        _TrieEmitter._emit_c_array(s, s1_ctype, prefix + "_stage1", best_s1)
        s.append("\n")
        _TrieEmitter._emit_c_array(s, "uint8_t", prefix + "_stage2", s2_usize)
        s.append("\nuint8_t " + prefix + "_lookup(uint32_t cp) {\n")
        s.append("  if (cp >= 0x110000u) return " + dflt + "u;\n")
        s.append("  return " + prefix + "_stage2[(size_t)" + prefix
          + "_stage1[cp >> " + shf + "] * " + blk + "u + (cp & " + msk
          + "u)];\n}\n")
        s
      end

    // 4. Pony source.
    let p =
      recover iso
        let s = String(512)
        s.append(header)
        s.append("\nuse @" + prefix + "_lookup[U8](cp: U32)\n\n")
        s.append("primitive " + prim_name + "\n")
        s.append("  fun of(cp: U32): " + ret_type + " =>\n")
        s.append("    " + value_open + "@" + prefix + "_lookup(cp)"
          + value_close + "\n")
        s.append(extra_body)
        s
      end

    (consume p, consume c)

  fun _build_trie(v: Array[U8] box, maxcp: USize, block: USize)
    : (Array[USize] val, Array[U8] val)
  =>
    """
    Split the cp -> byte map into `block`-sized runs, deduplicating
    identical runs. Returns (stage1, stage2): stage1[i] is the index of
    the unique block covering codepoints [i*block, (i+1)*block);
    stage2 is those unique blocks laid end to end.
    """
    let nb = maxcp / block
    let stage1 = recover iso Array[USize](nb) end
    let stage2 = recover iso Array[U8] end
    let seen = Map[String, USize]
    var b: USize = 0
    while b < nb do
      let key = _block_key(v, b * block, block)
      let idx =
        try
          seen(key)?
        else
          let ni = stage2.size() / block
          var j: USize = 0
          while j < block do
            try stage2.push(v((b * block) + j)?) end
            j = j + 1
          end
          seen(key) = ni
          ni
        end
      stage1.push(idx)
      b = b + 1
    end
    (consume stage1, consume stage2)

  fun _block_key(v: Array[U8] box, start: USize, block: USize): String val =>
    let s = String(block)
    var j: USize = 0
    while j < block do
      try s.push(v(start + j)?) end
      j = j + 1
    end
    s.clone()

  fun _emit_c_array(
    out: String ref, ctype: String, name: String, data: Array[USize] box)
  =>
    out.append("static const " + ctype + " " + name + "["
      + data.size().string() + "] = {\n")
    var i: USize = 0
    while i < data.size() do
      if (i % 20) == 0 then out.append("  ") end
      try out.append(data(i)?.string()) end
      out.append(",")
      if (i % 20) == 19 then out.append("\n") end
      i = i + 1
    end
    if (data.size() % 20) != 0 then out.append("\n") end
    out.append("};\n")

  // ---- U64-valued variant (binary-property bitmask trie) ------------------

  fun emit_u64(
    header: String val,
    prim_name: String val,
    c_prefix: String val,
    masks: Array[U64] val,
    pony_body: String val)
    : (String iso^, String iso^)
  =>
    """
    Like `emit`, but stage2 holds a U64 bitmask per codepoint (default 0).
    The C lookup returns the mask; `pony_body` supplies the primitive's
    methods (e.g. `has`/`mask`/`_bit` for binary properties). `masks` is
    the full cp -> U64 map (size 0x110000).
    """
    let maxcp: USize = 0x110000
    var best_total = USize.max_value()
    var best_block: USize = 256
    var best_shift: USize = 8
    var best_s1: Array[USize] val = recover val Array[USize] end
    var best_s2: Array[U64] val = recover val Array[U64] end
    for shift in [as USize: 6; 7; 8; 9; 10].values() do
      let block = USize(1) << shift
      (let s1, let s2) = _build_trie_u64(masks, maxcp, block)
      let nblocks = s2.size() / block
      let s1w: USize = if nblocks <= 256 then 1 else 2 end
      let total = (s1.size() * s1w) + (s2.size() * 8)
      if total < best_total then
        best_total = total
        best_block = block
        best_shift = shift
        best_s1 = s1
        best_s2 = s2
      end
    end

    let nblocks = best_s2.size() / best_block
    let s1_ctype: String val = if nblocks > 256 then "uint16_t" else "uint8_t"
      end
    let prefix = c_prefix
    let blk: String val = best_block.string()
    let shf: String val = best_shift.string()
    let msk: String val = (best_block - 1).string()

    let c =
      recover iso
        let s = String(best_total * 3)
        s.append(header)
        s.append("\n#include <stdint.h>\n#include <stddef.h>\n\n")
        _TrieEmitter._emit_c_array(s, s1_ctype, prefix + "_stage1", best_s1)
        s.append("\n")
        _TrieEmitter._emit_c_array_u64(s, prefix + "_stage2", best_s2)
        s.append("\nuint64_t " + prefix + "_lookup(uint32_t cp) {\n")
        s.append("  if (cp >= 0x110000u) return 0ull;\n")
        s.append("  return " + prefix + "_stage2[(size_t)" + prefix
          + "_stage1[cp >> " + shf + "] * " + blk + "u + (cp & " + msk
          + "u)];\n}\n")
        s
      end

    let p =
      recover iso
        let s = String(8192)
        s.append(header)
        s.append("\nuse @" + prefix + "_lookup[U64](cp: U32)\n\n")
        s.append("primitive " + prim_name + "\n")
        s.append(pony_body)
        s
      end

    (consume p, consume c)

  // ---- U32-valued variant (cp -> U32, e.g. simple case mappings) ----------

  fun emit_u32(
    header: String val,
    prim_name: String val,
    c_prefix: String val,
    values: Array[U32] val,
    pony_body: String val)
    : (String iso^, String iso^)
  =>
    """
    Like `emit`, but stage2 holds a U32 per codepoint (default 0). The C
    lookup returns the value; `pony_body` supplies the primitive's methods
    (e.g. `of` that treats 0 as "identity, return cp").
    """
    let maxcp: USize = 0x110000
    var best_total = USize.max_value()
    var best_block: USize = 256
    var best_shift: USize = 8
    var best_s1: Array[USize] val = recover val Array[USize] end
    var best_s2: Array[U32] val = recover val Array[U32] end
    for shift in [as USize: 6; 7; 8; 9; 10].values() do
      let block = USize(1) << shift
      (let s1, let s2) = _build_trie_u32(values, maxcp, block)
      let nblocks = s2.size() / block
      let s1w: USize = if nblocks <= 256 then 1 else 2 end
      let total = (s1.size() * s1w) + (s2.size() * 4)
      if total < best_total then
        best_total = total
        best_block = block
        best_shift = shift
        best_s1 = s1
        best_s2 = s2
      end
    end

    let nblocks = best_s2.size() / best_block
    let s1_ctype: String val = if nblocks > 256 then "uint16_t" else "uint8_t"
      end
    let prefix = c_prefix
    let blk: String val = best_block.string()
    let shf: String val = best_shift.string()
    let msk: String val = (best_block - 1).string()

    let c =
      recover iso
        let s = String(best_total * 3)
        s.append(header)
        s.append("\n#include <stdint.h>\n#include <stddef.h>\n\n")
        _TrieEmitter._emit_c_array(s, s1_ctype, prefix + "_stage1", best_s1)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_stage2", best_s2)
        s.append("\nuint32_t " + prefix + "_lookup(uint32_t cp) {\n")
        s.append("  if (cp >= 0x110000u) return 0u;\n")
        s.append("  return " + prefix + "_stage2[(size_t)" + prefix
          + "_stage1[cp >> " + shf + "] * " + blk + "u + (cp & " + msk
          + "u)];\n}\n")
        s
      end

    let p =
      recover iso
        let s = String(4096)
        s.append(header)
        s.append("\nuse @" + prefix + "_lookup[U32](cp: U32)\n\n")
        s.append("primitive " + prim_name + "\n")
        s.append(pony_body)
        s
      end

    (consume p, consume c)

  // ---- variable-length variant (cp -> Array[U32] | None) ------------------

  fun emit_varlen(
    header: String val,
    prim_name: String val,
    c_prefix: String val,
    entries: Array[(U32, Array[U32] val)] val,
    elem_type: String val = "U32",
    push_open: String val = "",
    push_close: String val = "")
    : (String iso^, String iso^)
  =>
    """
    Emit a cp -> (Array[elem_type] val | None) table. The trie maps cp to
    a U32 offset into a payload blob (offset 0 = None); at `off` the
    payload holds [length, v0, v1, ...]. `of` reads the length then each
    element via cheap FFI indexes into the static blob, wrapping each in
    `push_open` ... `push_close` (e.g. to map a script byte to a Script).
    `entries` is (cp, sequence) for every codepoint with a value.
    """
    let maxcp: USize = 0x110000
    let offsets = Array[U32].init(0, maxcp)
    let payload_iso = recover iso Array[U32] end
    payload_iso.push(0)  // index 0 reserved so offset 0 means "None"
    // Deduplicate identical sequences so codepoints that share a value
    // (common for Script_Extensions) point at the same payload offset.
    let seen = Map[String, U32]
    for e in entries.values() do
      let key = _seq_key(e._2)
      let off =
        try
          seen(key)?
        else
          let o = payload_iso.size().u32()
          payload_iso.push(e._2.size().u32())
          for c in e._2.values() do payload_iso.push(c) end
          seen(key) = o
          o
        end
      try offsets(e._1.usize())? = off end
    end
    let payload_val: Array[U32] val = consume payload_iso

    var best_total = USize.max_value()
    var best_block: USize = 256
    var best_shift: USize = 8
    var best_s1: Array[USize] val = recover val Array[USize] end
    var best_s2: Array[U32] val = recover val Array[U32] end
    for shift in [as USize: 6; 7; 8; 9; 10].values() do
      let block = USize(1) << shift
      (let s1, let s2) = _build_trie_u32(offsets, maxcp, block)
      let nblocks = s2.size() / block
      let s1w: USize = if nblocks <= 256 then 1 else 2 end
      let total = (s1.size() * s1w) + (s2.size() * 4)
      if total < best_total then
        best_total = total
        best_block = block
        best_shift = shift
        best_s1 = s1
        best_s2 = s2
      end
    end

    let nblocks = best_s2.size() / best_block
    let s1_ctype: String val = if nblocks > 256 then "uint16_t" else "uint8_t"
      end
    let prefix = c_prefix
    let blk: String val = best_block.string()
    let shf: String val = best_shift.string()
    let msk: String val = (best_block - 1).string()

    let c =
      recover iso
        let s = String((best_total + (payload_val.size() * 4)) * 3)
        s.append(header)
        s.append("\n#include <stdint.h>\n#include <stddef.h>\n\n")
        _TrieEmitter._emit_c_array(s, s1_ctype, prefix + "_stage1", best_s1)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_stage2", best_s2)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_payload", payload_val)
        s.append("\nuint32_t " + prefix + "_lookup(uint32_t cp) {\n")
        s.append("  if (cp >= 0x110000u) return 0u;\n")
        s.append("  return " + prefix + "_stage2[(size_t)" + prefix
          + "_stage1[cp >> " + shf + "] * " + blk + "u + (cp & " + msk
          + "u)];\n}\n")
        s.append("uint32_t " + prefix + "_at(uint32_t i) { return " + prefix
          + "_payload[i]; }\n")
        s
      end

    let p =
      recover iso
        let s = String(1024)
        s.append(header)
        s.append("\nuse @" + prefix + "_lookup[U32](cp: U32)\n")
        s.append("use @" + prefix + "_at[U32](i: U32)\n\n")
        s.append("primitive " + prim_name + "\n")
        s.append("  fun of(cp: U32): (Array[" + elem_type + "] val | None) =>\n")
        s.append("    let off = @" + prefix + "_lookup(cp)\n")
        s.append("    if off == 0 then return None end\n")
        s.append("    let n = @" + prefix + "_at(off)\n")
        s.append("    recover val\n")
        s.append("      let a = Array[" + elem_type + "](n.usize())\n")
        s.append("      var i: U32 = 1\n")
        s.append("      while i <= n do a.push(" + push_open + "@" + prefix
          + "_at(off + i)" + push_close + "); i = i + 1 end\n")
        s.append("      a\n")
        s.append("    end\n")
        s
      end

    (consume p, consume c)

  // ---- pair-keyed compose table ((lhs, rhs) -> cp | None) -----------------

  fun emit_compose(
    header: String val,
    prim_name: String val,
    c_prefix: String val,
    entries: Array[(U32, U32, U32)] val)
    : (String iso^, String iso^)
  =>
    """
    Emit `(lhs, rhs) -> (U32 | None)`. A trie maps `lhs` to a U32 offset
    into a payload (offset 0 = lhs composes with nothing → instant miss,
    like the old `match`); at `off` the payload holds [count, rhs0, res0,
    rhs1, res1, ...] for that lhs, linearly scanned. This avoids the
    branch-mispredicting global binary search. `entries` sorted by
    (lhs, rhs). A result of 0 means "no composition".
    """
    let maxcp: USize = 0x110000
    let offsets = Array[U32].init(0, maxcp)
    let payload_iso = recover iso Array[U32] end
    payload_iso.push(0)  // index 0 reserved so offset 0 means "no compositions"
    var i: USize = 0
    let sz = entries.size()
    while i < sz do
      (let lhs, _, _) = try entries(i)? else (U32(0), U32(0), U32(0)) end
      var j = i
      while j < sz do
        (let l2, _, _) = try entries(j)? else (U32(0), U32(0), U32(0)) end
        if l2 != lhs then break end
        j = j + 1
      end
      let off = payload_iso.size().u32()
      payload_iso.push((j - i).u32())  // count of (rhs, res) pairs
      var k = i
      while k < j do
        (_, let rhs, let res) = try entries(k)? else (U32(0), U32(0), U32(0))
          end
        payload_iso.push(rhs)
        payload_iso.push(res)
        k = k + 1
      end
      try offsets(lhs.usize())? = off end
      i = j
    end
    let payload_val: Array[U32] val = consume payload_iso

    var best_total = USize.max_value()
    var best_block: USize = 256
    var best_shift: USize = 8
    var best_s1: Array[USize] val = recover val Array[USize] end
    var best_s2: Array[U32] val = recover val Array[U32] end
    for shift in [as USize: 6; 7; 8; 9; 10].values() do
      let block = USize(1) << shift
      (let s1, let s2) = _build_trie_u32(offsets, maxcp, block)
      let nblocks = s2.size() / block
      let s1w: USize = if nblocks <= 256 then 1 else 2 end
      let total = (s1.size() * s1w) + (s2.size() * 4)
      if total < best_total then
        best_total = total
        best_block = block
        best_shift = shift
        best_s1 = s1
        best_s2 = s2
      end
    end
    let nblocks = best_s2.size() / best_block
    let s1_ctype: String val = if nblocks > 256 then "uint16_t" else "uint8_t"
      end
    let prefix = c_prefix
    let blk: String val = best_block.string()
    let shf: String val = best_shift.string()
    let msk: String val = (best_block - 1).string()

    let c =
      recover iso
        let s = String((payload_val.size() * 12) + (best_total * 4) + 1024)
        s.append(header)
        s.append("\n#include <stdint.h>\n#include <stddef.h>\n\n")
        _TrieEmitter._emit_c_array(s, s1_ctype, prefix + "_stage1", best_s1)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_stage2", best_s2)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_payload", payload_val)
        s.append("\nuint32_t " + prefix
          + "_compose(uint32_t lhs, uint32_t rhs) {\n")
        s.append("  if (lhs >= 0x110000u) return 0u;\n")
        s.append("  uint32_t off = " + prefix + "_stage2[(size_t)" + prefix
          + "_stage1[lhs >> " + shf + "] * " + blk + "u + (lhs & " + msk
          + "u)];\n")
        s.append("  if (off == 0u) return 0u;\n")
        s.append("  uint32_t count = " + prefix + "_payload[off];\n")
        s.append("  for (uint32_t k = 0; k < count; k++) {\n")
        s.append("    if (" + prefix + "_payload[off + 1u + (2u * k)] == rhs)\n")
        s.append("      return " + prefix + "_payload[off + 2u + (2u * k)];\n")
        s.append("  }\n  return 0u;\n}\n")
        s
      end

    let p =
      recover iso
        let s = String(512)
        s.append(header)
        s.append("\nuse @" + prefix + "_compose[U32](lhs: U32, rhs: U32)\n\n")
        s.append("primitive " + prim_name + "\n")
        s.append("  fun of(lhs: U32, rhs: U32): (U32 | None) =>\n")
        s.append("    let r = @" + prefix + "_compose(lhs, rhs)\n")
        s.append("    if r == 0 then None else r end\n")
        s
      end

    (consume p, consume c)

  // ---- name table (cp -> String | None, plus reverse from_name) -----------

  fun emit_name(
    header: String val,
    c_prefix: String val,
    entries: Array[(U32, String val)] val)
    : (String iso^, String iso^)
  =>
    """
    Emit `_UcdName`: cp -> (String val | None) as an offset trie over a
    byte payload (at `off`: [len, b0, b1, ...]). Also emits a sorted list
    of named codepoints so `from_name` (linear reverse lookup) can walk
    them. `entries` must be sorted by cp ascending.
    """
    let maxcp: USize = 0x110000
    let offsets = Array[U32].init(0, maxcp)
    let payload_iso = recover iso Array[USize] end
    payload_iso.push(0)  // index 0 reserved so offset 0 means "None"
    let cplist_iso = recover iso Array[U32] end
    for e in entries.values() do
      let off = payload_iso.size().u32()
      payload_iso.push(e._2.size())
      for b in e._2.values() do payload_iso.push(b.usize()) end
      try offsets(e._1.usize())? = off end
      cplist_iso.push(e._1)
    end
    let payload_val: Array[USize] val = consume payload_iso
    let cplist_val: Array[U32] val = consume cplist_iso

    var best_total = USize.max_value()
    var best_block: USize = 256
    var best_shift: USize = 8
    var best_s1: Array[USize] val = recover val Array[USize] end
    var best_s2: Array[U32] val = recover val Array[U32] end
    for shift in [as USize: 6; 7; 8; 9; 10].values() do
      let block = USize(1) << shift
      (let s1, let s2) = _build_trie_u32(offsets, maxcp, block)
      let nblocks = s2.size() / block
      let s1w: USize = if nblocks <= 256 then 1 else 2 end
      let total = (s1.size() * s1w) + (s2.size() * 4)
      if total < best_total then
        best_total = total
        best_block = block
        best_shift = shift
        best_s1 = s1
        best_s2 = s2
      end
    end

    let nblocks = best_s2.size() / best_block
    let s1_ctype: String val = if nblocks > 256 then "uint16_t" else "uint8_t"
      end
    let prefix = c_prefix
    let blk: String val = best_block.string()
    let shf: String val = best_shift.string()
    let msk: String val = (best_block - 1).string()
    let cpcount: String val = cplist_val.size().string()

    let c =
      recover iso
        let s = String((best_total + payload_val.size()) * 4)
        s.append(header)
        s.append("\n#include <stdint.h>\n#include <stddef.h>\n\n")
        _TrieEmitter._emit_c_array(s, s1_ctype, prefix + "_stage1", best_s1)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_stage2", best_s2)
        s.append("\n")
        _TrieEmitter._emit_c_array(s, "uint8_t", prefix + "_payload",
          payload_val)
        s.append("\n")
        _TrieEmitter._emit_c_array_u32(s, prefix + "_cps", cplist_val)
        s.append("\nuint32_t " + prefix + "_lookup(uint32_t cp) {\n")
        s.append("  if (cp >= 0x110000u) return 0u;\n")
        s.append("  return " + prefix + "_stage2[(size_t)" + prefix
          + "_stage1[cp >> " + shf + "] * " + blk + "u + (cp & " + msk
          + "u)];\n}\n")
        s.append("uint8_t " + prefix + "_at(uint32_t i) { return " + prefix
          + "_payload[i]; }\n")
        s.append("uint32_t " + prefix + "_count(void) { return " + cpcount
          + "u; }\n")
        s.append("uint32_t " + prefix + "_cpat(uint32_t i) { return " + prefix
          + "_cps[i]; }\n")
        s
      end

    let p =
      recover iso
        let s = String(1024)
        s.append(header)
        s.append("\nuse @" + prefix + "_lookup[U32](cp: U32)\n")
        s.append("use @" + prefix + "_at[U8](i: U32)\n")
        s.append("use @" + prefix + "_count[U32]()\n")
        s.append("use @" + prefix + "_cpat[U32](i: U32)\n\n")
        s.append("primitive _UcdName\n")
        s.append("  fun of(cp: U32): (String val | None) =>\n")
        s.append("    let off = @" + prefix + "_lookup(cp)\n")
        s.append("    if off == 0 then return None end\n")
        s.append("    let n = @" + prefix + "_at(off)\n")
        s.append("    recover val\n")
        s.append("      let s = String(n.usize())\n")
        s.append("      var i: U32 = 1\n")
        s.append("      while i <= n.u32() do s.push(@" + prefix
          + "_at(off + i)); i = i + 1 end\n")
        s.append("      s\n")
        s.append("    end\n\n")
        s.append("  fun from_name(name: String box): (U32 | None) =>\n")
        s.append("    // Linear-scan reverse lookup over named codepoints.\n")
        s.append("    var i: U32 = 0\n")
        s.append("    let count = @" + prefix + "_count()\n")
        s.append("    while i < count do\n")
        s.append("      let cp = @" + prefix + "_cpat(i)\n")
        s.append("      match of(cp) | let nm: String val if nm == name "
          + "=> return cp end\n")
        s.append("      i = i + 1\n")
        s.append("    end\n")
        s.append("    None\n")
        s
      end

    (consume p, consume c)

  fun _seq_key(seq: Array[U32] box): String val =>
    let s = String((seq.size() * 4) + 1)
    for x in seq.values() do
      var k: U32 = 0
      while k < 4 do
        s.push(U8.from[U32]((x >> (k * 8)) and 0xFF))
        k = k + 1
      end
    end
    s.clone()

  fun _build_trie_u32(v: Array[U32] box, maxcp: USize, block: USize)
    : (Array[USize] val, Array[U32] val)
  =>
    let nb = maxcp / block
    let stage1 = recover iso Array[USize](nb) end
    let stage2 = recover iso Array[U32] end
    let seen = Map[String, USize]
    var b: USize = 0
    while b < nb do
      let key = _block_key_u32(v, b * block, block)
      let idx =
        try
          seen(key)?
        else
          let ni = stage2.size() / block
          var j: USize = 0
          while j < block do
            try stage2.push(v((b * block) + j)?) end
            j = j + 1
          end
          seen(key) = ni
          ni
        end
      stage1.push(idx)
      b = b + 1
    end
    (consume stage1, consume stage2)

  fun _block_key_u32(v: Array[U32] box, start: USize, block: USize): String val
  =>
    let s = String(block * 4)
    var j: USize = 0
    while j < block do
      try
        let x = v(start + j)?
        var k: U32 = 0
        while k < 4 do
          s.push(U8.from[U32]((x >> (k * 8)) and 0xFF))
          k = k + 1
        end
      end
      j = j + 1
    end
    s.clone()

  fun _emit_c_array_u32(
    out: String ref, name: String, data: Array[U32] box)
  =>
    out.append("static const uint32_t " + name + "["
      + data.size().string() + "] = {\n")
    var i: USize = 0
    while i < data.size() do
      if (i % 12) == 0 then out.append("  ") end
      try
        out.append(data(i)?.string())
        out.append("u,")
      end
      if (i % 12) == 11 then out.append("\n") end
      i = i + 1
    end
    if (data.size() % 12) != 0 then out.append("\n") end
    out.append("};\n")

  fun _build_trie_u64(v: Array[U64] box, maxcp: USize, block: USize)
    : (Array[USize] val, Array[U64] val)
  =>
    let nb = maxcp / block
    let stage1 = recover iso Array[USize](nb) end
    let stage2 = recover iso Array[U64] end
    let seen = Map[String, USize]
    var b: USize = 0
    while b < nb do
      let key = _block_key_u64(v, b * block, block)
      let idx =
        try
          seen(key)?
        else
          let ni = stage2.size() / block
          var j: USize = 0
          while j < block do
            try stage2.push(v((b * block) + j)?) end
            j = j + 1
          end
          seen(key) = ni
          ni
        end
      stage1.push(idx)
      b = b + 1
    end
    (consume stage1, consume stage2)

  fun _block_key_u64(v: Array[U64] box, start: USize, block: USize): String val
  =>
    let s = String(block * 8)
    var j: USize = 0
    while j < block do
      try
        let x = v(start + j)?
        var k: U64 = 0
        while k < 8 do
          s.push(U8.from[U64]((x >> (k * 8)) and 0xFF))
          k = k + 1
        end
      end
      j = j + 1
    end
    s.clone()

  fun _emit_c_array_u64(
    out: String ref, name: String, data: Array[U64] box)
  =>
    out.append("static const uint64_t " + name + "["
      + data.size().string() + "] = {\n")
    var i: USize = 0
    while i < data.size() do
      if (i % 8) == 0 then out.append("  ") end
      try
        out.append(data(i)?.string())
        out.append("ull,")
      end
      if (i % 8) == 7 then out.append("\n") end
      i = i + 1
    end
    if (data.size() % 8) != 0 then out.append("\n") end
    out.append("};\n")
