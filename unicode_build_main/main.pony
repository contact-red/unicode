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
