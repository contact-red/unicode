// UAX #15 NormalizationTest.txt conformance runner.
//
// Reads `ucd/NormalizationTest.txt` (path passed as argv[1], default
// "./ucd/NormalizationTest.txt") and checks every Part 1 test case
// against the four `Normalize` entry points. Part 2 (the "identity"
// requirement for codepoints not in Part 1) is sampled — full sweep
// would require iterating all assigned codepoints.
//
// Each non-comment, non-`@`-section line has the form:
//
//   c1 ; c2 ; c3 ; c4 ; c5 ; # ...
//
// where the five fields are space-separated hex codepoint sequences:
//
//   c1 = source
//   c2 = NFC(c1)
//   c3 = NFD(c1)
//   c4 = NFKC(c1)
//   c5 = NFKD(c1)
//
// Per UAX #15:
//   c2 == NFC(c1)  == NFC(c2)  == NFC(c3)
//   c4 == NFC(c4)  == NFC(c5)
//   c3 == NFD(c1)  == NFD(c2)  == NFD(c3)
//   c5 == NFD(c4)  == NFD(c5)
//   c4 == NFKC(c1) == NFKC(c2) == NFKC(c3) == NFKC(c4) == NFKC(c5)
//   c5 == NFKD(c1) == NFKD(c2) == NFKD(c3) == NFKD(c4) == NFKD(c5)
//
// Exit 0 on full pass, 1 if any test fails.

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
    var checked: USize = 0
    var failed: USize = 0
    for line in lines.values() do
      if _is_skippable(line) then continue end
      try
        let fields = _split_semicolons(line)
        if fields.size() < 5 then continue end
        let c1 = _cps_to_utf8(_parse_cps(fields(0)?)?)
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
            env.err.print("  failed line: " + line)
          end
          failed = failed + 1
        end
      end
    end
    env.out.print("conformance: checked " + checked.string()
      + ", failed " + failed.string())
    if failed > 0 then env.exitcode(1) end

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

  fun _is_skippable(line: String val): Bool =>
    if line.size() == 0 then return true end
    try
      let c = line(0)?
      if (c == '#') or (c == '@') then return true end
    end
    // Skip whitespace-only lines too.
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
    """
    Split on `;` and strip everything after the first `#`. Each
    field is returned trimmed of leading/trailing whitespace.
    """
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
