// `_TextIndex` — placeholder for M4's optional bitmap index.
//
// At M2, `Text._index` is always `None`. This class is defined so the
// field's type (`(_TextIndex val | None)`) can compile. M4 will add the
// actual grapheme-start bitmap, popcount caches, and index-construction
// machinery.

class val _TextIndex
  new val create() => None
