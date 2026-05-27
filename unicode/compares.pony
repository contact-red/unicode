// `Compares` — text comparison primitives.
//
// Provides four equality relations on UTF-8 text:
//
//   bytes        : raw byte sequence (cheap, code-point-precise but
//                  sensitive to NFC vs NFD differences and to case)
//   canonical    : NFC-equal — "café" precomposed == "café" decomposed
//   compat       : NFKC-equal — also folds compatibility variants
//   caseless     : default-folded equality — "MAß" == "maSS"
//   caseless_canonical : UAX #21 D146 — case-AND-canonical-insensitive
//
// All composite forms return `(Bool | InvalidUtf8)`; the `bytes`
// variant is total over `String box`.
//
// Ordering uses Pony stdlib's `Compare` type (`Less | Equal | Greater`).

primitive Compares
  fun bytes(a: String box, b: String box): Compare =>
    """
    Lexicographic byte comparison. Total. Result is in the codepoint
    order if both inputs are well-formed UTF-8, since UTF-8's
    byte-sort order matches codepoint order.
    """
    let na = a.size()
    let nb = b.size()
    let n = if na < nb then na else nb end
    var i: USize = 0
    while i < n do
      try
        let ba = a(i)?
        let bb = b(i)?
        if ba < bb then return Less end
        if ba > bb then return Greater end
      end
      i = i + 1
    end
    if na < nb then Less
    elseif na > nb then Greater
    else Equal
    end

  fun equal_bytes(a: String box, b: String box): Bool =>
    """
    True iff `a` and `b` are byte-for-byte equal. Distinct from
    `equal_canonical`: "café" precomposed (5 bytes) and "café"
    decomposed (6 bytes) are NOT byte-equal but ARE canonically
    equal.
    """
    match bytes(a, b) | Equal => true else false end

  fun equal_canonical(a: String box, b: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    NFC-equality: true iff `NFC(a) == NFC(b)` byte-for-byte.
    """
    match _both_valid(a, b)
    | let err: InvalidUtf8 => err
    | None =>
      let na = Normalize._nfc(a)
      let nb = Normalize._nfc(b)
      (consume na) == (consume nb)
    end

  fun equal_compat(a: String box, b: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    NFKC-equality. Folds compatibility variants (e.g., ﬁ ligature
    equals 'fi'; full-width digits equal ASCII digits).
    """
    match _both_valid(a, b)
    | let err: InvalidUtf8 => err
    | None =>
      let na = Normalize._nfkc(a)
      let nb = Normalize._nfkc(b)
      (consume na) == (consume nb)
    end

  fun equal_caseless(a: String box, b: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    Default caseless equality: fold(a) == fold(b). Ignores case
    differences but NOT canonical differences.
    """
    match _both_valid(a, b)
    | let err: InvalidUtf8 => err
    | None =>
      let fa = Case._fold(a)
      let fb = Case._fold(b)
      (consume fa) == (consume fb)
    end

  fun equal_caseless_canonical(a: String box, b: String box)
    : (Bool | InvalidUtf8)
  =>
    """
    UAX #21 D146 default caseless matching:
    `NFD(fold(NFD(a))) == NFD(fold(NFD(b)))`. Ignores both case and
    canonical differences. The double-NFD is required because case
    folding can produce non-NFD output.
    """
    match _both_valid(a, b)
    | let err: InvalidUtf8 => err
    | None =>
      let a' = Normalize._nfd(Case._fold(Normalize._nfd(a)))
      let b' = Normalize._nfd(Case._fold(Normalize._nfd(b)))
      (consume a') == (consume b')
    end

  // ============================================================
  // Internals
  // ============================================================

  fun _both_valid(a: String box, b: String box): (InvalidUtf8 | None) =>
    match Bytes.first_bad_utf8_offset(a)
    | let off: USize => return InvalidUtf8(off)
    end
    match Bytes.first_bad_utf8_offset(b)
    | let off: USize => return InvalidUtf8(off)
    end
    None
