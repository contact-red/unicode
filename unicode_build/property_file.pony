// Parser for the standard UCD "property file" format used by
// GraphemeBreakProperty.txt, Scripts.txt, PropList.txt,
// DerivedCoreProperties.txt, WordBreakProperty.txt, and several others.
//
// Format (UAX #44 §5.5):
//
//   # ...comment lines start with hash...
//
//   <codepoint or range> ; <Property_Name> # optional inline comment
//
// where <codepoint or range> is either `XXXX` or `XXXX..YYYY` (uppercase
// hex, no `0x` prefix).
//
// We return a list of (range_lo, range_hi, property_name) triples in
// file order. Coalescing of adjacent equal-property ranges is left to
// the table emitter — the parser stays neutral about whether the file
// uses overlapping or sorted ranges.

class val PropertyEntry
  let range_lo: U32
  let range_hi: U32
  let property: String val

  new val create(range_lo': U32, range_hi': U32, property': String val) =>
    range_lo = range_lo'
    range_hi = range_hi'
    property = property'


primitive PropertyFileParser
  fun parse_all(lines: ReadSeq[String val] box)
    : Array[PropertyEntry val] val ?
  =>
    """
    Parse every non-blank, non-comment line into a PropertyEntry.
    Raises on malformed lines.
    """
    let out = recover trn Array[PropertyEntry val] end
    for line in lines.values() do
      match parse_line(line)?
      | let e: PropertyEntry val => out.push(e)
      | None => None
      end
    end
    consume out

  fun parse_line(line: String box)
    : (PropertyEntry val | None) ?
  =>
    """
    Parse one line. Returns `None` for blank or comment-only lines.
    Raises on malformed records.
    """
    if UcdLine.is_skippable(line) then return None end
    // The format has two semicolon-separated fields, but the second
    // field may have an inline `#` comment trailer. UcdLine.fields
    // calls strip_comment first, so the trailing #-comment is gone.
    let f = UcdLine.fields(line, 2)?
    (let lo, let hi) = UcdLine.parse_codepoint_range(f(0)?)?
    PropertyEntry(lo, hi, f(1)?)
