// Phantom-typed indices for byte / codepoint / grapheme offsets into a
// `Text`. The kinds can never be mixed at compile time — passing a
// `ByteIndex` to a method expecting `GraphemeIndex` is a type error.
//
// Public construction goes through `Text.byte_index(n) ? `,
// `Text.codepoint_index(n) ?`, `Text.grapheme_index(n) ?` — each
// validates that the requested index is in range for the Text. The
// bare-`USize` constructor `_raw` is package-private specifically to
// prevent the footgun "I have a USize from somewhere, let me build a
// GraphemeIndex straight from it" (which would lose the unit safety
// the type provides — see Adversarial S4 in design/candidate-v3.md).

primitive _ByteIdx
primitive _CodepointIdx
primitive _GraphemeIdx

type _IndexKind is (_ByteIdx | _CodepointIdx | _GraphemeIdx)

class val Index[Kind: _IndexKind]
  let _value: USize

  new val _raw(n: USize) =>
    """
    Package-private constructor. Callers must obtain indices via the
    `Text.X_index(n) ?` methods, which range-check.
    """
    _value = n

  fun value(): USize =>
    """
    The underlying numeric offset.
    """
    _value

  fun add(n: USize): Index[Kind] =>
    """
    Add `n` to this index, producing a new index of the same kind.
    Useful for stepping forward in iteration code. The result is NOT
    range-checked against any specific Text — callers receiving an
    out-of-range index from an op (e.g., `grapheme_at`) will get
    `OutOfRange` back.
    """
    Index[Kind]._raw(_value + n)

  fun eq(that: Index[Kind] box): Bool =>
    _value == that._value

  fun lt(that: Index[Kind] box): Bool =>
    _value < that._value

  fun hash(): USize =>
    _value.hash()

type ByteIndex      is Index[_ByteIdx]
type CodepointIndex is Index[_CodepointIdx]
type GraphemeIndex  is Index[_GraphemeIdx]
