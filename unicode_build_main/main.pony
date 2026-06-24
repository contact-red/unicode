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
    (let cat_pony, let cat_c) = CategoryTableEmitter.emit(entries)
    _write_file(auth, out_dir + "/_ucd_general_category.pony", consume cat_pony)?
    _write_file(auth, out_dir + "/_ucd_general_category.c", consume cat_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_general_category.{pony,c}")

    // Emit combining-class table
    (let ccc_pony, let ccc_c) = DecompTableEmitter.emit_combining_class(entries)
    _write_file(auth, out_dir + "/_ucd_combining_class.pony", consume ccc_pony)?
    _write_file(auth, out_dir + "/_ucd_combining_class.c", consume ccc_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_combining_class.{pony,c}")

    // Emit canonical decomposition table
    (let decomp_pony, let decomp_c) =
      DecompTableEmitter.emit_canonical_decomposition(entries)
    _write_file(auth, out_dir + "/_ucd_canonical_decomp.pony",
      consume decomp_pony)?
    _write_file(auth, out_dir + "/_ucd_canonical_decomp.c", consume decomp_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_canonical_decomp.{pony,c}")

    // Emit compatibility decomposition table
    (let compat_pony, let compat_c) =
      DecompTableEmitter.emit_compat_decomposition(entries)
    _write_file(auth, out_dir + "/_ucd_compat_decomp.pony", consume compat_pony)?
    _write_file(auth, out_dir + "/_ucd_compat_decomp.c", consume compat_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_compat_decomp.{pony,c}")

    // Emit grapheme break property table
    let gbp_lines = _read_lines(auth,
      ucd_dir + "/auxiliary/GraphemeBreakProperty.txt")?
    let emoji_lines = _read_lines(auth,
      ucd_dir + "/emoji/emoji-data.txt")?
    env.out.print("  read " + gbp_lines.size().string()
      + " lines from GraphemeBreakProperty.txt + " + emoji_lines.size().string()
      + " from emoji-data.txt")
    (let gb_pony, let gb_c) =
      GraphemeBreakTableEmitter.emit(gbp_lines, emoji_lines)?
    _write_file(auth, out_dir + "/_ucd_grapheme_break.pony", consume gb_pony)?
    env.out.print("  wrote " + out_dir + "/_ucd_grapheme_break.pony")
    _write_file(auth, out_dir + "/_ucd_grapheme_break.c", consume gb_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_grapheme_break.c")

    // Emit word break property table (UAX #29).
    let wbp_lines = _read_lines(auth,
      ucd_dir + "/auxiliary/WordBreakProperty.txt")?
    env.out.print("  read " + wbp_lines.size().string()
      + " lines from WordBreakProperty.txt")
    (let wb_pony, let wb_c) = WordBreakTableEmitter.emit(wbp_lines, emoji_lines)?
    _write_file(auth, out_dir + "/_ucd_word_break.pony", consume wb_pony)?
    _write_file(auth, out_dir + "/_ucd_word_break.c", consume wb_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_word_break.{pony,c}")

    // Emit sentence break property table (UAX #29).
    let sbp_lines = _read_lines(auth,
      ucd_dir + "/auxiliary/SentenceBreakProperty.txt")?
    env.out.print("  read " + sbp_lines.size().string()
      + " lines from SentenceBreakProperty.txt")
    (let sb_pony, let sb_c) = SentenceBreakTableEmitter.emit(sbp_lines)?
    _write_file(auth, out_dir + "/_ucd_sentence_break.pony", consume sb_pony)?
    _write_file(auth, out_dir + "/_ucd_sentence_break.c", consume sb_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_sentence_break.{pony,c}")

    // Emit line break property table + LineBreak type (UAX #14).
    let lb_lines = _read_lines(auth, ucd_dir + "/LineBreak.txt")?
    env.out.print("  read " + lb_lines.size().string()
      + " lines from LineBreak.txt")
    (let lb_rt, let lb_pony, let lb_c) =
      LineBreakTableEmitter.emit_both(lb_lines)?
    _write_file(auth, out_dir + "/line_break.pony", consume lb_rt)?
    env.out.print("  wrote " + out_dir + "/line_break.pony")
    _write_file(auth, out_dir + "/_ucd_line_break.pony", consume lb_pony)?
    _write_file(auth, out_dir + "/_ucd_line_break.c", consume lb_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_line_break.{pony,c}")

    // Emit East_Asian_Width type + cp-range table (UAX #11).
    let eaw_lines = _read_lines(auth, ucd_dir + "/EastAsianWidth.txt")?
    env.out.print("  read " + eaw_lines.size().string()
      + " lines from EastAsianWidth.txt")
    (let eaw_rt, let eaw_pony, let eaw_c) =
      EastAsianWidthTableEmitter.emit_both(eaw_lines)?
    _write_file(auth, out_dir + "/east_asian_width.pony", consume eaw_rt)?
    env.out.print("  wrote " + out_dir + "/east_asian_width.pony")
    _write_file(auth, out_dir + "/_ucd_east_asian_width.pony",
      consume eaw_pony)?
    _write_file(auth, out_dir + "/_ucd_east_asian_width.c", consume eaw_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_east_asian_width.{pony,c}")

    // Emit full case mappings from SpecialCasing.txt (unconditional only)
    let sc_lines = _read_lines(auth, ucd_dir + "/SpecialCasing.txt")?
    env.out.print("  read " + sc_lines.size().string()
      + " lines from SpecialCasing.txt")
    let sc_entries = SpecialCasingParser.parse_all(sc_lines)?
    env.out.print("  parsed " + sc_entries.size().string()
      + " SpecialCasing entries")
    let full_upper = _full_case_pairs(sc_entries, "upper")
    (let fu_pony, let fu_c) = VarLenTableEmitter.emit(
      "_UcdFullUpper",
      "SpecialCasing.txt Uppercase_Mapping (unconditional)",
      "ucd_fu", full_upper)
    _write_file(auth, out_dir + "/_ucd_full_upper.pony", consume fu_pony)?
    _write_file(auth, out_dir + "/_ucd_full_upper.c", consume fu_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_upper.{pony,c}")
    let full_lower = _full_case_pairs(sc_entries, "lower")
    (let fl_pony, let fl_c) = VarLenTableEmitter.emit(
      "_UcdFullLower",
      "SpecialCasing.txt Lowercase_Mapping (unconditional)",
      "ucd_fl", full_lower)
    _write_file(auth, out_dir + "/_ucd_full_lower.pony", consume fl_pony)?
    _write_file(auth, out_dir + "/_ucd_full_lower.c", consume fl_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_lower.{pony,c}")
    let full_title = _full_case_pairs(sc_entries, "title")
    (let ft_pony, let ft_c) = VarLenTableEmitter.emit(
      "_UcdFullTitle",
      "SpecialCasing.txt Titlecase_Mapping (unconditional)",
      "ucd_ft", full_title)
    _write_file(auth, out_dir + "/_ucd_full_title.pony", consume ft_pony)?
    _write_file(auth, out_dir + "/_ucd_full_title.c", consume ft_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_title.{pony,c}")

    // Emit case folding tables from CaseFolding.txt
    let cf_lines = _read_lines(auth, ucd_dir + "/CaseFolding.txt")?
    env.out.print("  read " + cf_lines.size().string()
      + " lines from CaseFolding.txt")
    let cf_entries = CaseFoldingParser.parse_all(cf_lines)?
    (let simple_fold, let full_fold) = _fold_pairs(cf_entries)
    (let scf_pony, let scf_c) = SimpleCaseFoldEmitter.emit(simple_fold)
    _write_file(auth, out_dir + "/_ucd_simple_casefold.pony", consume scf_pony)?
    _write_file(auth, out_dir + "/_ucd_simple_casefold.c", consume scf_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_simple_casefold.{pony,c}")
    (let ff_pony, let ff_c) = VarLenTableEmitter.emit(
      "_UcdFullCaseFold",
      "CaseFolding.txt status C + F entries (default full folding)",
      "ucd_ff", full_fold)
    _write_file(auth, out_dir + "/_ucd_full_casefold.pony", consume ff_pony)?
    _write_file(auth, out_dir + "/_ucd_full_casefold.c", consume ff_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_full_casefold.{pony,c}")

    // Emit simple case mappings (UnicodeData.txt fields 12/13/14)
    (let su_pony, let su_c) = CaseTableEmitter.emit_simple_upper(entries)
    _write_file(auth, out_dir + "/_ucd_simple_upper.pony", consume su_pony)?
    _write_file(auth, out_dir + "/_ucd_simple_upper.c", consume su_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_simple_upper.{pony,c}")
    (let sl_pony, let sl_c) = CaseTableEmitter.emit_simple_lower(entries)
    _write_file(auth, out_dir + "/_ucd_simple_lower.pony", consume sl_pony)?
    _write_file(auth, out_dir + "/_ucd_simple_lower.c", consume sl_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_simple_lower.{pony,c}")
    (let st_pony, let st_c) = CaseTableEmitter.emit_simple_title(entries)
    _write_file(auth, out_dir + "/_ucd_simple_title.pony", consume st_pony)?
    _write_file(auth, out_dir + "/_ucd_simple_title.c", consume st_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_simple_title.{pony,c}")

    // Emit Codepoint name table.
    (let name_pony, let name_c) = NameTableEmitter.emit(entries)
    _write_file(auth, out_dir + "/_ucd_name.pony", consume name_pony)?
    _write_file(auth, out_dir + "/_ucd_name.c", consume name_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_name.{pony,c}")

    // Read PropList + DerivedCoreProperties once; used by InCB and
    // BinaryProperty emitters below.
    let prop_lines = _read_lines(auth, ucd_dir + "/PropList.txt")?
    let dcp_lines = _read_lines(auth, ucd_dir + "/DerivedCoreProperties.txt")?
    env.out.print("  read " + prop_lines.size().string()
      + " lines from PropList.txt + "
      + dcp_lines.size().string() + " from DerivedCoreProperties.txt")

    // Emit Indic_Conjunct_Break table (DerivedCoreProperties.txt InCB).
    // Hand-written runtime types live in unicode/indic_conjunct_break.pony;
    // here we just generate the lookup table.
    (let incb_pony, let incb_c) = IncbTableEmitter.emit(dcp_lines)
    _write_file(auth, out_dir + "/_ucd_indic_conjunct_break.pony",
      consume incb_pony)?
    _write_file(auth, out_dir + "/_ucd_indic_conjunct_break.c", consume incb_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_indic_conjunct_break.{pony,c}")

    // Emit BinaryProperty type + per-property tables (PropList +
    // DerivedCoreProperties + emoji-data).
    (let bp_rt, let bp_pony, let bp_c) = BinaryPropsTableEmitter.emit_both(
      prop_lines, dcp_lines, emoji_lines)?
    _write_file(auth, out_dir + "/binary_property.pony", consume bp_rt)?
    env.out.print("  wrote " + out_dir + "/binary_property.pony")
    _write_file(auth, out_dir + "/_ucd_binary_props.pony", consume bp_pony)?
    _write_file(auth, out_dir + "/_ucd_binary_props.c", consume bp_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_binary_props.{pony,c}")

    // Emit Script type + cp-range table (Scripts.txt).
    let scripts_lines = _read_lines(auth, ucd_dir + "/Scripts.txt")?
    env.out.print("  read " + scripts_lines.size().string()
      + " lines from Scripts.txt")
    (let script_rt, let script_pony, let script_c) =
      ScriptTableEmitter.emit_both(scripts_lines)?
    _write_file(auth, out_dir + "/script.pony", consume script_rt)?
    env.out.print("  wrote " + out_dir + "/script.pony")
    _write_file(auth, out_dir + "/_ucd_script.pony", consume script_pony)?
    _write_file(auth, out_dir + "/_ucd_script.c", consume script_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_script.{pony,c}")

    // Emit Script_Extensions cp → Array[Script] table (UAX #24).
    let scx_lines = _read_lines(auth,
      ucd_dir + "/ScriptExtensions.txt")?
    let pva_lines = _read_lines(auth,
      ucd_dir + "/PropertyValueAliases.txt")?
    env.out.print("  read " + scx_lines.size().string()
      + " lines from ScriptExtensions.txt + "
      + pva_lines.size().string() + " from PropertyValueAliases.txt")
    let script_entries = PropertyFileParser.parse_all(scripts_lines)?
    let script_names = ScriptTableEmitter.collect_names(
      script_entries)
    (let scx_pony, let scx_c) = ScriptExtensionsTableEmitter.emit(
      scx_lines, pva_lines, script_names)?
    _write_file(auth, out_dir + "/_ucd_script_extensions.pony",
      consume scx_pony)?
    _write_file(auth, out_dir + "/_ucd_script_extensions.c", consume scx_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_script_extensions.{pony,c}")

    // Emit composition tables (Full_Composition_Exclusion + canonical compose).
    let dnp_lines = _read_lines(auth,
      ucd_dir + "/DerivedNormalizationProps.txt")?
    env.out.print("  read " + dnp_lines.size().string()
      + " lines from DerivedNormalizationProps.txt")
    (let excl_pony, let excl_c) = CompositionTableEmitter.emit_exclusion(
      dnp_lines)?
    _write_file(auth, out_dir + "/_ucd_composition_exclusion.pony",
      consume excl_pony)?
    _write_file(auth, out_dir + "/_ucd_composition_exclusion.c",
      consume excl_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_composition_exclusion.{pony,c}")
    (let comp_pony, let comp_c) = CompositionTableEmitter.emit_canonical_compose(
      entries, dnp_lines)?
    _write_file(auth, out_dir + "/_ucd_canonical_compose.pony",
      consume comp_pony)?
    _write_file(auth, out_dir + "/_ucd_canonical_compose.c", consume comp_c)?
    env.out.print("  wrote " + out_dir + "/_ucd_canonical_compose.{pony,c}")

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
