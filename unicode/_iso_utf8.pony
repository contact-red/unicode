// Package-private iso UTF-8 validator.
//
// `Bytes.is_valid_utf8` takes a `(String box | Array[U8] box)` — the
// safe, public surface. Iso parameters can't be aliased as box (Pony's
// substructural rules), so the iso-adopting constructors on `Text`
// can't reuse the public Bytes function. This primitive duplicates the
// validation walk for iso inputs, consuming on success so the caller
// can store the (still-iso) result without re-allocating.
//
// Keep the rules here in lock-step with `Bytes.first_bad_utf8_offset` —
// any RFC 3629 / corrigendum update needs to land in both places.

primitive _IsoUtf8
  fun validate_string(s: String iso): String iso^ ? =>
    """
    Walk `s` validating UTF-8 byte-by-byte; raise on the first
    ill-formed sequence. Returns the iso String back on success so the
    caller can `consume` it directly into a Text field.
    """
    var i: USize = 0
    let size = s.size()
    while i < size do
      let b0 = s(i)?
      if b0 < 0x80 then
        i = i + 1
      elseif b0 < 0xC2 then
        error
      elseif b0 < 0xE0 then
        if (i + 1) >= size then error end
        let b1 = s(i + 1)?
        if not _is_cont(b1) then error end
        i = i + 2
      elseif b0 < 0xF0 then
        if (i + 2) >= size then error end
        let b1 = s(i + 1)?
        let b2 = s(i + 2)?
        let b1_ok =
          if b0 == 0xE0 then (b1 >= 0xA0) and (b1 <= 0xBF)
          elseif b0 == 0xED then (b1 >= 0x80) and (b1 <= 0x9F)
          else _is_cont(b1)
          end
        if not b1_ok then error end
        if not _is_cont(b2) then error end
        i = i + 3
      elseif b0 < 0xF5 then
        if (i + 3) >= size then error end
        let b1 = s(i + 1)?
        let b2 = s(i + 2)?
        let b3 = s(i + 3)?
        let b1_ok =
          if b0 == 0xF0 then (b1 >= 0x90) and (b1 <= 0xBF)
          elseif b0 == 0xF4 then (b1 >= 0x80) and (b1 <= 0x8F)
          else _is_cont(b1)
          end
        if not b1_ok then error end
        if not _is_cont(b2) then error end
        if not _is_cont(b3) then error end
        i = i + 4
      else
        error
      end
    end
    consume s

  fun validate_array(a: Array[U8] iso): Array[U8] iso^ ? =>
    """
    Same as `validate_string` but for `Array[U8] iso`.
    """
    var i: USize = 0
    let size = a.size()
    while i < size do
      let b0 = a(i)?
      if b0 < 0x80 then
        i = i + 1
      elseif b0 < 0xC2 then
        error
      elseif b0 < 0xE0 then
        if (i + 1) >= size then error end
        let b1 = a(i + 1)?
        if not _is_cont(b1) then error end
        i = i + 2
      elseif b0 < 0xF0 then
        if (i + 2) >= size then error end
        let b1 = a(i + 1)?
        let b2 = a(i + 2)?
        let b1_ok =
          if b0 == 0xE0 then (b1 >= 0xA0) and (b1 <= 0xBF)
          elseif b0 == 0xED then (b1 >= 0x80) and (b1 <= 0x9F)
          else _is_cont(b1)
          end
        if not b1_ok then error end
        if not _is_cont(b2) then error end
        i = i + 3
      elseif b0 < 0xF5 then
        if (i + 3) >= size then error end
        let b1 = a(i + 1)?
        let b2 = a(i + 2)?
        let b3 = a(i + 3)?
        let b1_ok =
          if b0 == 0xF0 then (b1 >= 0x90) and (b1 <= 0xBF)
          elseif b0 == 0xF4 then (b1 >= 0x80) and (b1 <= 0x8F)
          else _is_cont(b1)
          end
        if not b1_ok then error end
        if not _is_cont(b2) then error end
        if not _is_cont(b3) then error end
        i = i + 4
      else
        error
      end
    end
    consume a

  fun _is_cont(b: U8): Bool =>
    (b >= 0x80) and (b <= 0xBF)
