// Runnable codegen tool: regenerates per-property tables in `unicode/`
// from UCD source files. Run from the project root:
//
//   make ucd-generate
//   # or directly:
//   corral run -- ponyc unicode_build_main/ && ./unicode_build_main UCD_DIR
//
// UCD_DIR is the path to a directory containing the UCD text files
// (UnicodeData.txt, GraphemeBreakProperty.txt, etc.). Default is `./ucd`.
//
// On success, writes regenerated files into `unicode/_ucd_*.pony` and
// prints a summary of what was emitted.

use "files"
use "../unicode_build"

actor Main
  new create(env: Env) =>
    let args = env.args
    let ucd_dir: String val =
      try args(1)? else "./ucd" end
    let out_dir: String val =
      try args(2)? else "./unicode" end

    env.out.print("unicode-build")
    env.out.print("  UCD source : " + ucd_dir)
    env.out.print("  Output dir : " + out_dir)
    env.out.print("")

    try
      _generate(env, ucd_dir, out_dir)?
    else
      env.err.print("unicode-build: failed")
      env.exitcode(1)
    end

  fun _generate(env: Env, ucd_dir: String val, out_dir: String val) ? =>
    let auth = FileAuth(env.root)

    // Read UnicodeData.txt
    let unicode_data_path: String val = ucd_dir + "/UnicodeData.txt"
    let unicode_data_lines = _read_lines(auth, unicode_data_path)?
    env.out.print("  read " + unicode_data_lines.size().string()
      + " lines from " + unicode_data_path)

    let entries = UnicodeDataReader.parse_all(unicode_data_lines)?
    env.out.print("  parsed " + entries.size().string() + " UnicodeData entries")

    // Emit general category table
    let cat_body = CategoryTableEmitter.emit(entries)
    let cat_path: String val = out_dir + "/_ucd_general_category.pony"
    _write_file(auth, cat_path, consume cat_body)?
    env.out.print("  wrote " + cat_path)

    // Emit combining-class table
    let ccc_body = DecompTableEmitter.emit_combining_class(entries)
    let ccc_path: String val = out_dir + "/_ucd_combining_class.pony"
    _write_file(auth, ccc_path, consume ccc_body)?
    env.out.print("  wrote " + ccc_path)

    // Emit canonical decomposition table
    let decomp_body = DecompTableEmitter.emit_canonical_decomposition(entries)
    let decomp_path: String val = out_dir + "/_ucd_canonical_decomp.pony"
    _write_file(auth, decomp_path, consume decomp_body)?
    env.out.print("  wrote " + decomp_path)

    // Emit compatibility decomposition table
    let compat_body = DecompTableEmitter.emit_compat_decomposition(entries)
    let compat_path: String val = out_dir + "/_ucd_compat_decomp.pony"
    _write_file(auth, compat_path, consume compat_body)?
    env.out.print("  wrote " + compat_path)

    // Emit grapheme break property table
    let gbp_lines = _read_lines(auth,
      ucd_dir + "/auxiliary/GraphemeBreakProperty.txt")?
    let emoji_lines = _read_lines(auth,
      ucd_dir + "/emoji/emoji-data.txt")?
    env.out.print("  read " + gbp_lines.size().string()
      + " lines from GraphemeBreakProperty.txt + " + emoji_lines.size().string()
      + " from emoji-data.txt")
    let gb_body = GraphemeBreakTableEmitter.emit(gbp_lines, emoji_lines)?
    let gb_path: String val = out_dir + "/_ucd_grapheme_break.pony"
    _write_file(auth, gb_path, consume gb_body)?
    env.out.print("  wrote " + gb_path)

    // Emit full case mappings from SpecialCasing.txt (unconditional only)
    let sc_lines = _read_lines(auth, ucd_dir + "/SpecialCasing.txt")?
    env.out.print("  read " + sc_lines.size().string()
      + " lines from SpecialCasing.txt")
    let sc_entries = SpecialCasingParser.parse_all(sc_lines)?
    env.out.print("  parsed " + sc_entries.size().string()
      + " SpecialCasing entries")
    let full_upper = _full_case_pairs(sc_entries, "upper")
    let full_upper_body = VarLenTableEmitter.emit(
      "_UcdFullUpper",
      "SpecialCasing.txt Uppercase_Mapping (unconditional)",
      full_upper)
    _write_file(auth, out_dir + "/_ucd_full_upper.pony",
      consume full_upper_body)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_upper.pony")
    let full_lower = _full_case_pairs(sc_entries, "lower")
    let full_lower_body = VarLenTableEmitter.emit(
      "_UcdFullLower",
      "SpecialCasing.txt Lowercase_Mapping (unconditional)",
      full_lower)
    _write_file(auth, out_dir + "/_ucd_full_lower.pony",
      consume full_lower_body)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_lower.pony")
    let full_title = _full_case_pairs(sc_entries, "title")
    let full_title_body = VarLenTableEmitter.emit(
      "_UcdFullTitle",
      "SpecialCasing.txt Titlecase_Mapping (unconditional)",
      full_title)
    _write_file(auth, out_dir + "/_ucd_full_title.pony",
      consume full_title_body)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_title.pony")

    // Emit case folding tables from CaseFolding.txt
    let cf_lines = _read_lines(auth, ucd_dir + "/CaseFolding.txt")?
    env.out.print("  read " + cf_lines.size().string()
      + " lines from CaseFolding.txt")
    let cf_entries = CaseFoldingParser.parse_all(cf_lines)?
    (let simple_fold, let full_fold) = _fold_pairs(cf_entries)
    let simple_fold_body = SimpleCaseFoldEmitter.emit(simple_fold)
    _write_file(auth, out_dir + "/_ucd_simple_casefold.pony",
      consume simple_fold_body)?
    env.out.print("  wrote " + out_dir + "/_ucd_simple_casefold.pony")
    let full_fold_body = VarLenTableEmitter.emit(
      "_UcdFullCaseFold",
      "CaseFolding.txt status C + F entries (default full folding)",
      full_fold)
    _write_file(auth, out_dir + "/_ucd_full_casefold.pony",
      consume full_fold_body)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_casefold.pony")

    // Emit simple case mappings (UnicodeData.txt fields 12/13/14)
    let upper_body = CaseTableEmitter.emit_simple_upper(entries)
    let upper_path: String val = out_dir + "/_ucd_simple_upper.pony"
    _write_file(auth, upper_path, consume upper_body)?
    env.out.print("  wrote " + upper_path)
    let lower_body = CaseTableEmitter.emit_simple_lower(entries)
    let lower_path: String val = out_dir + "/_ucd_simple_lower.pony"
    _write_file(auth, lower_path, consume lower_body)?
    env.out.print("  wrote " + lower_path)
    let title_body = CaseTableEmitter.emit_simple_title(entries)
    let title_path: String val = out_dir + "/_ucd_simple_title.pony"
    _write_file(auth, title_path, consume title_body)?
    env.out.print("  wrote " + title_path)

    // Emit Codepoint name table.
    let name_body = NameTableEmitter.emit(entries)
    _write_file(auth, out_dir + "/_ucd_name.pony", consume name_body)?
    env.out.print("  wrote " + out_dir + "/_ucd_name.pony")

    // Emit BinaryProperty type + per-property tables (PropList +
    // DerivedCoreProperties + emoji-data).
    let prop_lines = _read_lines(auth, ucd_dir + "/PropList.txt")?
    let dcp_lines = _read_lines(auth, ucd_dir + "/DerivedCoreProperties.txt")?
    env.out.print("  read " + prop_lines.size().string()
      + " lines from PropList.txt + "
      + dcp_lines.size().string() + " from DerivedCoreProperties.txt")
    (let bp_rt, let bp_tbl) = BinaryPropsTableEmitter.emit_both(
      prop_lines, dcp_lines, emoji_lines)?
    _write_file(auth, out_dir + "/binary_property.pony", consume bp_rt)?
    env.out.print("  wrote " + out_dir + "/binary_property.pony")
    _write_file(auth, out_dir + "/_ucd_binary_props.pony", consume bp_tbl)?
    env.out.print("  wrote " + out_dir + "/_ucd_binary_props.pony")

    // Emit Script type + cp-range table (Scripts.txt).
    let scripts_lines = _read_lines(auth, ucd_dir + "/Scripts.txt")?
    env.out.print("  read " + scripts_lines.size().string()
      + " lines from Scripts.txt")
    (let script_rt, let script_tbl) = ScriptTableEmitter.emit_both(scripts_lines)?
    _write_file(auth, out_dir + "/script.pony", consume script_rt)?
    env.out.print("  wrote " + out_dir + "/script.pony")
    _write_file(auth, out_dir + "/_ucd_script.pony", consume script_tbl)?
    env.out.print("  wrote " + out_dir + "/_ucd_script.pony")

    // Emit composition tables (Full_Composition_Exclusion + canonical compose).
    let dnp_lines = _read_lines(auth,
      ucd_dir + "/DerivedNormalizationProps.txt")?
    env.out.print("  read " + dnp_lines.size().string()
      + " lines from DerivedNormalizationProps.txt")
    let excl_body = CompositionTableEmitter.emit_exclusion(dnp_lines)?
    let excl_path: String val = out_dir + "/_ucd_composition_exclusion.pony"
    _write_file(auth, excl_path, consume excl_body)?
    env.out.print("  wrote " + excl_path)
    let comp_body = CompositionTableEmitter.emit_canonical_compose(
      entries, dnp_lines)?
    let comp_path: String val = out_dir + "/_ucd_canonical_compose.pony"
    _write_file(auth, comp_path, consume comp_body)?
    env.out.print("  wrote " + comp_path)

    env.out.print("")
    env.out.print("Done.")

  fun _read_lines(
    auth: FileAuth, path_str: String val)
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

  fun _write_file(
    auth: FileAuth, path_str: String val, body: String iso) ?
  =>
    let path = FilePath(auth, path_str)
    let file = CreateFile(path)
    match file
    | let f: File =>
      f.set_length(0)
      f.write(consume body)
      f.dispose()
    else
      error
    end

  fun _full_case_pairs(
    entries: ReadSeq[SpecialCasingEntry val] box,
    kind: String val)
    : Array[(U32, Array[U32] val)] val
  =>
    """
    Collect cp → mapping pairs for the requested case direction
    (`"upper"`, `"lower"`, or `"title"`), skipping conditional
    entries (those with a non-empty `conditions` field) and
    identity-only mappings. Sorts by codepoint so the runtime
    binary search is valid.
    """
    let out = recover trn Array[(U32, Array[U32] val)] end
    for e in entries.values() do
      if e.conditions.size() != 0 then continue end
      let mapping: Array[U32] val =
        if kind == "upper" then e.upper
        elseif kind == "lower" then e.lower
        else e.title
        end
      let is_identity: Bool =
        try (mapping.size() == 1) and (mapping(0)? == e.codepoint)
        else false
        end
      if not is_identity then
        out.push((e.codepoint, mapping))
      end
    end
    _sort_pairs(consume out)

  fun _fold_pairs(
    entries: ReadSeq[CaseFoldingEntry val] box)
    : (Array[(U32, U32)] val, Array[(U32, Array[U32] val)] val)
  =>
    """
    From CaseFolding.txt, build sorted simple-fold (C+S) and
    full-fold (C+F) tables.
    """
    let simple = recover trn Array[(U32, U32)] end
    let full = recover trn Array[(U32, Array[U32] val)] end
    for e in entries.values() do
      match e.status
      | 'C' =>
        try simple.push((e.codepoint, e.mapping(0)?)) end
        full.push((e.codepoint, e.mapping))
      | 'S' =>
        try simple.push((e.codepoint, e.mapping(0)?)) end
      | 'F' =>
        full.push((e.codepoint, e.mapping))
      end
    end
    (_sort_simple(consume simple), _sort_pairs(consume full))

  fun _sort_simple(raw: Array[(U32, U32)] trn): Array[(U32, U32)] val =>
    let n = raw.size()
    var i: USize = 1
    while i < n do
      try
        var j = i
        let cur = raw(j)?
        while (j > 0) and (raw(j - 1)?._1 > cur._1) do
          raw(j)? = raw(j - 1)?
          j = j - 1
        end
        raw(j)? = cur
      end
      i = i + 1
    end
    let out = recover trn Array[(U32, U32)](n) end
    for x in raw.values() do out.push(x) end
    consume out

  fun _sort_pairs(raw: Array[(U32, Array[U32] val)] trn)
    : Array[(U32, Array[U32] val)] val
  =>
    let n = raw.size()
    var i: USize = 1
    while i < n do
      try
        var j = i
        let cur = raw(j)?
        while (j > 0) and (raw(j - 1)?._1 > cur._1) do
          raw(j)? = raw(j - 1)?
          j = j - 1
        end
        raw(j)? = cur
      end
      i = i + 1
    end
    let out = recover trn Array[(U32, Array[U32] val)](n) end
    for x in raw.values() do out.push(x) end
    consume out
