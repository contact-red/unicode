// UAX #15 NormalizationTest.txt conformance runner.
//
// Reads `ucd/NormalizationTest.txt` (path passed as argv[1], default
// "./ucd/NormalizationTest.txt") and runs both UAX #15 conformance
// clauses:
//
// Part 1 — explicit cases. Each non-comment, non-`@`-section line has
//          5 semicolon-separated fields:
//
//   c1 = source     c2 = NFC(c1)   c3 = NFD(c1)
//   c4 = NFKC(c1)   c5 = NFKD(c1)
//
//   The standard requires 20 invariants per line:
//     c2 == NFC(c1)  == NFC(c2)  == NFC(c3)
//     c4 == NFC(c4)  == NFC(c5)
//     c3 == NFD(c1)  == NFD(c2)  == NFD(c3)
//     c5 == NFD(c4)  == NFD(c5)
//     c4 == NFKC(c1) == NFKC(c2) == NFKC(c3) == NFKC(c4) == NFKC(c5)
//     c5 == NFKD(c1) == NFKD(c2) == NFKD(c3) == NFKD(c4) == NFKD(c5)
//
// Part 2 — identity for codepoints not "specifically listed in Part 1".
//          For every assigned cp X not appearing as c1 in the
//          `@Part1` section, the standard requires:
//             X == NFC(X) == NFD(X) == NFKC(X) == NFKD(X)
//
// Exit 0 if both parts pass; exit 1 on any failure.

use "collections"
use "files"
use "../unicode"

actor Main
  new create(env: Env) =>
    let auth = FileAuth(env.root)
    let path: String val =
      try env.args(1)? else "./ucd/NormalizationTest.txt" end
    env.out.print("conformance: reading " + path)
    let lines = try _read_lines(auth, path)?
      else
        env.err.print("conformance: cannot read " + path)
        env.exitcode(1)
        return
      end
    env.out.print("conformance: " + lines.size().string() + " lines")

    // Part 1 — run explicit checks; collect cps from @Part1 lines.
    let part1_cps = HashSet[U32, HashEq[U32]]
    var section: String val = ""
    var checked: USize = 0
    var failed: USize = 0
    for line in lines.values() do
      if line.size() == 0 then continue end
      try
        if line(0)? == '@' then
          section = _section_of(line)
          continue
        end
      end
      if _is_skippable(line) then continue end
      try
        let fields = _split_semicolons(line)
        if fields.size() < 5 then continue end
        let cps_c1 = _parse_cps(fields(0)?)?
        if (section == "@Part1") and (cps_c1.size() == 1) then
          part1_cps.set(cps_c1(0)?)
        end
        let c1 = _cps_to_utf8(cps_c1)
        let c2 = _cps_to_utf8(_parse_cps(fields(1)?)?)
        let c3 = _cps_to_utf8(_parse_cps(fields(2)?)?)
        let c4 = _cps_to_utf8(_parse_cps(fields(3)?)?)
        let c5 = _cps_to_utf8(_parse_cps(fields(4)?)?)
        checked = checked + 1
        var ok: Bool = true
        ok = ok and (_nfc(c1) == c2)
        ok = ok and (_nfc(c2) == c2)
        ok = ok and (_nfc(c3) == c2)
        ok = ok and (_nfc(c4) == c4)
        ok = ok and (_nfc(c5) == c4)
        ok = ok and (_nfd(c1) == c3)
        ok = ok and (_nfd(c2) == c3)
        ok = ok and (_nfd(c3) == c3)
        ok = ok and (_nfd(c4) == c5)
        ok = ok and (_nfd(c5) == c5)
        ok = ok and (_nfkc(c1) == c4)
        ok = ok and (_nfkc(c2) == c4)
        ok = ok and (_nfkc(c3) == c4)
        ok = ok and (_nfkc(c4) == c4)
        ok = ok and (_nfkc(c5) == c4)
        ok = ok and (_nfkd(c1) == c5)
        ok = ok and (_nfkd(c2) == c5)
        ok = ok and (_nfkd(c3) == c5)
        ok = ok and (_nfkd(c4) == c5)
        ok = ok and (_nfkd(c5) == c5)
        if not ok then
          if failed < 10 then
            env.err.print("  Part 1 failed line: " + line)
          end
          failed = failed + 1
        end
      end
    end
    env.out.print("Part 1: checked " + checked.string()
      + ", failed " + failed.string()
      + " (@Part1 cps tracked: " + part1_cps.size().string() + ")")

    // Part 2 — identity for assigned cps NOT in part1_cps.
    var p2_checked: USize = 0
    var p2_failed: USize = 0
    var cp: U32 = 0
    while cp <= 0x10FFFF do
      if Codepoints.is_assigned(cp) and (not part1_cps.contains(cp)) then
        let s: String val =
          recover val
            let b = String(4)
            b.push_utf32(cp)
            b
          end
        p2_checked = p2_checked + 1
        let ok =
          (s == _nfc(s)) and (s == _nfd(s))
            and (s == _nfkc(s)) and (s == _nfkd(s))
        if not ok then
          if p2_failed < 10 then
            env.err.print("  Part 2 failed cp: U+"
              + _to_hex(cp))
          end
          p2_failed = p2_failed + 1
        end
      end
      cp = cp + 1
    end
    env.out.print("Part 2: checked " + p2_checked.string()
      + ", failed " + p2_failed.string())

    if (failed > 0) or (p2_failed > 0) then env.exitcode(1) end

  fun _nfc(s: String val): String val =>
    match Normalize.nfc(s)
    | let r: String iso => consume r
    | let _: InvalidUtf8 => ""
    end

  fun _nfd(s: String val): String val =>
    match Normalize.nfd(s)
    | let r: String iso => consume r
    | let _: InvalidUtf8 => ""
    end

  fun _nfkc(s: String val): String val =>
    match Normalize.nfkc(s)
    | let r: String iso => consume r
    | let _: InvalidUtf8 => ""
    end

  fun _nfkd(s: String val): String val =>
    match Normalize.nfkd(s)
    | let r: String iso => consume r
    | let _: InvalidUtf8 => ""
    end

  fun _section_of(line: String val): String val =>
    """
    Extract `@PartN` from a section-header line. The line starts with
    `@` and the token runs until whitespace or `#`.
    """
    var i: USize = 0
    let n = line.size()
    while i < n do
      try
        let c = line(i)?
        if (c == ' ') or (c == '\t') or (c == '#') then break end
      end
      i = i + 1
    end
    recover val line.substring(0, ISize.from[USize](i)) end

  fun _is_skippable(line: String val): Bool =>
    if line.size() == 0 then return true end
    try
      let c = line(0)?
      if (c == '#') or (c == '@') then return true end
    end
    var i: USize = 0
    while i < line.size() do
      try
        let c = line(i)?
        if (c != ' ') and (c != '\t') and (c != '\r') and (c != '\n') then
          return false
        end
      end
      i = i + 1
    end
    true

  fun _split_semicolons(line: String val): Array[String val] val =>
    var end_idx: USize = line.size()
    var i: USize = 0
    while i < line.size() do
      try if line(i)? == '#' then end_idx = i; break end end
      i = i + 1
    end
    let out = recover trn Array[String val] end
    var start: USize = 0
    var j: USize = 0
    while j < end_idx do
      try
        if line(j)? == ';' then
          out.push(_trim(line, start, j))
          start = j + 1
        end
      end
      j = j + 1
    end
    out.push(_trim(line, start, end_idx))
    consume out

  fun _trim(s: String box, start: USize, stop: USize): String val =>
    var a = start
    var b = stop
    while a < b do
      try
        let c = s(a)?
        if (c == ' ') or (c == '\t') then a = a + 1 else break end
      end
    end
    while b > a do
      try
        let c = s(b - 1)?
        if (c == ' ') or (c == '\t') then b = b - 1 else break end
      end
    end
    recover val s.substring(ISize.from[USize](a), ISize.from[USize](b)) end

  fun _parse_cps(field: String val): Array[U32] val ? =>
    let out = recover trn Array[U32] end
    var i: USize = 0
    let n = field.size()
    while i < n do
      while (i < n) and (field(i)? == ' ') do i = i + 1 end
      if i >= n then break end
      var j = i
      while (j < n) and (field(j)? != ' ') do j = j + 1 end
      let tok: String val = recover val
        field.substring(ISize.from[USize](i), ISize.from[USize](j))
      end
      out.push(_parse_hex(tok)?)
      i = j
    end
    consume out

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

  fun _to_hex(cp: U32): String val =>
    let digits = "0123456789ABCDEF"
    let out = recover trn String(6) end
    var i: U32 = 24
    var leading: Bool = true
    while true do
      let nibble = (cp >> i) and 0xF
      if leading and (nibble == 0) and (i > 0) then
        i = i - 4
        continue
      end
      leading = false
      try out.push(digits(USize.from[U32](nibble))?) end
      if i == 0 then break end
      i = i - 4
    end
    consume out

  fun _cps_to_utf8(cps: Array[U32] val): String val =>
    let out = recover trn String(cps.size() * 4) end
    for cp in cps.values() do
      out.push_utf32(cp)
    end
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
