// Internal category-code mapping for the unicode-build tool.
//
// The codegen tool is independent of the runtime `unicode` package — it
// reads UCD text, parses out two-letter category codes ("Lu", "Mn", ...),
// and emits byte indices into generated tables. The runtime package
// converts those byte indices back to `Category` primitives.
//
// IMPORTANT: this byte mapping MUST agree with `unicode/category.pony`
// `Categories._to_byte` / `_from_byte`. If you change one, change the
// other in the same commit. A test in `unicode/tests/_test.pony` would
// be the right place to verify the agreement directly.

primitive CategoryCodes
  fun to_byte(code: String box): (U8 | None) =>
    """
    Map a UCD two-letter category code (e.g., "Lu") to the byte used in
    generated tables. Returns `None` for unrecognized codes.
    """
    match code
    | "Lu" => U8(0)  | "Ll" => U8(1)  | "Lt" => U8(2)
    | "Lm" => U8(3)  | "Lo" => U8(4)
    | "Mn" => U8(5)  | "Mc" => U8(6)  | "Me" => U8(7)
    | "Nd" => U8(8)  | "Nl" => U8(9)  | "No" => U8(10)
    | "Pc" => U8(11) | "Pd" => U8(12) | "Ps" => U8(13)
    | "Pe" => U8(14) | "Pi" => U8(15) | "Pf" => U8(16)
    | "Po" => U8(17)
    | "Sm" => U8(18) | "Sc" => U8(19) | "Sk" => U8(20)
    | "So" => U8(21)
    | "Zs" => U8(22) | "Zl" => U8(23) | "Zp" => U8(24)
    | "Cc" => U8(25) | "Cf" => U8(26) | "Cs" => U8(27)
    | "Co" => U8(28) | "Cn" => U8(29)
    else
      None
    end
