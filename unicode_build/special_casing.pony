// Parser for SpecialCasing.txt.
//
// Format (UAX #44):
//
//   <cp>; <full_lower>; <full_title>; <full_upper>; [<conditions>]; # comment
//
// Where each mapping field is a space-separated sequence of cps and
// <conditions> is optional. M1.D scope: emit tables for the
// UNCONDITIONAL entries only. The ~16 conditional entries (Turkic
// I-dot, Greek final sigma, Lithuanian dot-above) are deferred until
// M6 actually exercises locale-aware case operations.

class val SpecialCasingEntry
  let codepoint: U32
  let lower: Array[U32] val
  let title: Array[U32] val
  let upper: Array[U32] val
  let conditions: String val  // empty = unconditional

  new val create(
    cp: U32, l: Array[U32] val, t: Array[U32] val, u: Array[U32] val,
    cond: String val)
  =>
    codepoint = cp
    lower = l
    title = t
    upper = u
    conditions = cond


primitive SpecialCasingParser
  fun parse_all(lines: ReadSeq[String val] box)
    : Array[SpecialCasingEntry val] val ?
  =>
    let out = recover trn Array[SpecialCasingEntry val] end
    for line in lines.values() do
      match parse_line(line)?
      | let e: SpecialCasingEntry val => out.push(e)
      | None => None
      end
    end
    consume out

  fun parse_line(line: String box)
    : (SpecialCasingEntry val | None) ?
  =>
    if UcdLine.is_skippable(line) then return None end
    let f = UcdLine.fields(line, 4)?
    let cp = UcdLine.parse_codepoint(f(0)?)?
    let lower = _parse_seq(f(1)?)?
    let title = _parse_seq(f(2)?)?
    let upper = _parse_seq(f(3)?)?
    let cond: String val =
      if f.size() >= 5 then f(4)?
      else ""
      end
    SpecialCasingEntry(cp, lower, title, upper, cond)

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
