// UAX #29 SentenceBreakTest.txt conformance runner.
//
// Reads `ucd/auxiliary/SentenceBreakTest.txt` (path passed as argv[1])
// and verifies our `Sentences._ranges` iterator places cluster
// boundaries at the same positions as the standard.
//
// Each non-comment line has the form:
//
//   ÷ <hex> {× or ÷ <hex>}+ ÷    # comment
//
// where:
//   ÷ (U+00F7)  = grapheme sentence boundary
//   × (U+00D7)  = NO boundary
//   <hex>       = a Unicode codepoint
//
// The line implicitly defines:
//   - a sequence of N codepoints
//   - which of the N+1 positions (before, between, after) are
//     cluster boundaries
//
// The first and last positions are always `÷` (start/end of text).
// Our iterator yields sentence start byte offsets; we translate
// expected codepoint-position boundaries to byte-position boundaries
// (via the byte_offsets we accumulate when building the UTF-8 string)
// and compare.
//
// Exit 0 on full pass, 1 if any case fails.

use "collections"
use "files"
use "../unicode"

actor Main
  new create(env: Env) =>
    let auth = FileAuth(env.root)
    let path: String val =
      try env.args(1)?
      else "./ucd/auxiliary/SentenceBreakTest.txt"
      end
    env.out.print("sentence conformance: reading " + path)
    let lines = try _read_lines(auth, path)?
      else
        env.err.print("cannot read " + path)
        env.exitcode(1)
        return
      end
    env.out.print(
      "sentence conformance: " + lines.size().string() + " lines")

    var checked: USize = 0
    var failed: USize = 0
    for line in lines.values() do
      let body = _strip_comment(line)
      if _is_blank(body) then continue end
      try
        (let cps, let expected_breaks_cp) = _parse(body)?
        // Build the UTF-8 string + byte offsets per cp.
        let buf = recover trn String(cps.size() * 4) end
        let cp_to_byte = Array[USize](cps.size() + 1)
        for cp in cps.values() do
          cp_to_byte.push(buf.size())
          buf.push_utf32(cp)
        end
        cp_to_byte.push(buf.size())
        let utf8: String val = consume buf
        // Translate expected cp-position breaks → byte offsets.
        let expected_byte = HashSet[USize, HashEq[USize]]
        for pos in expected_breaks_cp.values() do
          expected_byte.set(cp_to_byte(pos)?)
        end
        // Collect actual cluster boundaries from our iterator.
        let actual_byte = HashSet[USize, HashEq[USize]]
        actual_byte.set(0)
        actual_byte.set(utf8.size())  // end is always a boundary
        match Sentences.ranges(utf8)
        | let it: Iterator[(USize, USize)] =>
          while it.has_next() do
            try
              (let lo: USize, let hi: USize) = it.next()?
              actual_byte.set(lo)
              actual_byte.set(hi)
            end
          end
        | let _: InvalidUtf8 => None  // unreachable: we built valid UTF-8
        end
        checked = checked + 1
        let ok = _set_eq(expected_byte, actual_byte)
        if not ok then
          if failed < 10 then
            env.err.print("  failed line: " + line)
            env.err.print("    expected breaks (byte): "
              + _set_string(expected_byte))
            env.err.print("    actual breaks (byte):   "
              + _set_string(actual_byte))
          end
          failed = failed + 1
        end
      end
    end
    env.out.print("sentence conformance: checked " + checked.string()
      + ", failed " + failed.string())
    if failed > 0 then env.exitcode(1) end

  fun _parse(body: String val)
    : (Array[U32] val, Array[USize] val) ?
  =>
    """
    Parse a body line (already comment-stripped). Returns
    (cps, break_positions) where break_positions is the set of
    codepoint indices [0..N] at which a `÷` appears (0 = before
    first cp; N = after last cp).
    """
    let cps = recover trn Array[U32] end
    let breaks = recover trn Array[USize] end
    var pos_in_cps: USize = 0
    var i: USize = 0
    let n = body.size()
    while i < n do
      // Skip whitespace
      while (i < n) and _is_ws(body(i)?) do i = i + 1 end
      if i >= n then break end
      // Detect marker (÷ = 0xC3 0xB7, × = 0xC3 0x97) or hex digit
      if (body(i)? == 0xC3) and ((i + 1) < n) then
        let next = body(i + 1)?
        if next == 0xB7 then
          breaks.push(pos_in_cps)
          i = i + 2
          continue
        elseif next == 0x97 then
          // × — explicitly NO boundary, but we still consume.
          i = i + 2
          continue
        end
      end
      // Hex codepoint
      var j: USize = i
      while (j < n) and (not _is_ws(body(j)?)) do j = j + 1 end
      let tok: String val = recover val
        body.substring(ISize.from[USize](i), ISize.from[USize](j))
      end
      cps.push(_parse_hex(tok)?)
      pos_in_cps = pos_in_cps + 1
      i = j
    end
    (consume cps, consume breaks)

  fun _is_ws(b: U8): Bool =>
    (b == ' ') or (b == '\t') or (b == '\r') or (b == '\n')

  fun _is_blank(s: String val): Bool =>
    var i: USize = 0
    while i < s.size() do
      try
        let c = s(i)?
        if not _is_ws(c) then return false end
      end
      i = i + 1
    end
    true

  fun _strip_comment(line: String val): String val =>
    var i: USize = 0
    let n = line.size()
    while i < n do
      try if line(i)? == '#' then break end end
      i = i + 1
    end
    recover val line.substring(0, ISize.from[USize](i)) end

  fun _parse_hex(s: String val): U32 ? =>
    var acc: U32 = 0
    if s.size() == 0 then error end
    for c in s.values() do
      let d: U32 =
        if (c >= '0') and (c <= '9') then U32.from[U8](c - '0')
        elseif (c >= 'A') and (c <= 'F') then U32.from[U8]((c - 'A') + 10)
        elseif (c >= 'a') and (c <= 'f') then U32.from[U8]((c - 'a') + 10)
        else error
        end
      acc = (acc * 16) + d
    end
    acc

  fun _set_eq(
    a: HashSet[USize, HashEq[USize]] box,
    b: HashSet[USize, HashEq[USize]] box): Bool
  =>
    if a.size() != b.size() then return false end
    for v in a.values() do
      if not b.contains(v) then return false end
    end
    true

  fun _set_string(s: HashSet[USize, HashEq[USize]] box): String iso^ =>
    let sorted = Array[USize]
    for v in s.values() do sorted.push(v) end
    let n = sorted.size()
    var i: USize = 1
    while i < n do
      try
        var j = i
        let cur = sorted(j)?
        while (j > 0) and (sorted(j - 1)? > cur) do
          sorted(j)? = sorted(j - 1)?
          j = j - 1
        end
        sorted(j)? = cur
      end
      i = i + 1
    end
    let out = recover iso String end
    out.append("{")
    var first: Bool = true
    for v in sorted.values() do
      if not first then out.append(", ") end
      first = false
      out.append(v.string())
    end
    out.append("}")
    consume out

  fun _read_lines(auth: FileAuth, path_str: String val)
    : Array[String val] val ?
  =>
    let path = FilePath(auth, path_str)
    let file = OpenFile(path)
    match file
    | let f: File =>
      let out = recover trn Array[String val] end
      for line in FileLines(f) do
        out.push(consume line)
      end
      consume out
    else
      error
    end
