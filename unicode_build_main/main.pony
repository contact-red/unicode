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
      f.write(consume body)
      f.dispose()
    else
      error
    end
