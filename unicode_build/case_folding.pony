// Parser for CaseFolding.txt.
//
// Format (UAX #44):
//
//   <cp>; <status>; <mapping>; # comment
//
// Where <status> is one of:
//   C  — common: single-cp mapping, used by both simple and full folding
//   F  — full: multi-cp mapping, only for full folding
//   S  — simple: single-cp, only for simple folding (an alternative
//        to a matching F entry on the same cp)
//   T  — turkic: single-cp, locale-specific
//   I  — used for some derivations only; ignore here
//
// Simple folding uses C + S entries (drop F when there's a C on same cp).
// Full folding uses C + F entries (drop S when there's an F on same cp).

class val CaseFoldingEntry
  let codepoint: U32
  let status:    U8           // 'C', 'F', 'S', 'T', 'I'
  let mapping:   Array[U32] val

  new val create(cp: U32, s: U8, m: Array[U32] val) =>
    codepoint = cp
    status = s
    mapping = m


primitive CaseFoldingParser
  fun parse_all(lines: ReadSeq[String val] box)
    : Array[CaseFoldingEntry val] val ?
  =>
    let out = recover trn Array[CaseFoldingEntry val] end
    for line in lines.values() do
      match parse_line(line)?
      | let e: CaseFoldingEntry val => out.push(e)
      | None => None
      end
    end
    consume out

  fun parse_line(line: String box)
    : (CaseFoldingEntry val | None) ?
  =>
    if UcdLine.is_skippable(line) then return None end
    let f = UcdLine.fields(line, 3)?
    let cp = UcdLine.parse_codepoint(f(0)?)?
    let status_str = f(1)?
    if status_str.size() != 1 then error end
    let status = status_str(0)?
    let mapping = _parse_seq(f(2)?)?
    CaseFoldingEntry(cp, status, mapping)

  fun _parse_seq(field: String box): Array[U32] val ? =>
    let out = recover trn Array[U32] end
    var i: USize = 0
    let n = field.size()
    while i < n do
      while (i < n) and (field(i)? == ' ') do i = i + 1 end
      if i >= n then break end
      var j = i
      while (j < n) and (field(j)? != ' ') do j = j + 1 end
      let tok: String val = recover val
        field.substring(ISize.from[USize](i), ISize.from[USize](j)) end
      out.push(UcdLine.parse_codepoint(tok)?)
      i = j
    end
    consume out
