primitive _Corpora
  """
  Sample text generators for the benchmarks. Each generator returns a
  `String val` whose byte length is at least the requested `size` (and
  at most `size + pattern.size()` — never trimmed mid-codepoint).

  All patterns are valid UTF-8. The patterns are picked to exercise
  different bytes-per-cp distributions and (where relevant) different
  normalization / segmentation states:

    * `ascii`            — 1-byte cps, ASCII only
    * `latin_precomposed` — Latin-1 / 2-byte cps in NFC
    * `latin_decomposed` — same text in NFD; stresses NFC composition
    * `cjk`              — 3-byte cps, Han ideographs
    * `mixed`            — ASCII + Latin + CJK in alternation
    * `emoji`            — 4-byte cps + ZWJ sequences (multi-cp graphemes)
    * `combining_marks`  — pathological: base + 5 combining marks per cluster
  """

  fun ascii(size: USize): String val =>
    _repeat(_ascii_pattern(), size)

  fun latin_precomposed(size: USize): String val =>
    _repeat(_latin_precomposed_pattern(), size)

  fun latin_decomposed(size: USize): String val =>
    _repeat(_latin_decomposed_pattern(), size)

  fun cjk(size: USize): String val =>
    _repeat(_cjk_pattern(), size)

  fun mixed(size: USize): String val =>
    _repeat(_mixed_pattern(), size)

  fun emoji(size: USize): String val =>
    _repeat(_emoji_pattern(), size)

  fun combining_marks(size: USize): String val =>
    _repeat(_combining_pattern(), size)

  fun _ascii_pattern(): String val =>
    "The quick brown fox jumps over the lazy dog.  "

  fun _latin_precomposed_pattern(): String val =>
    "café déjà naïve résumé schöne Straße über Hände  "

  fun _latin_decomposed_pattern(): String val =>
    recover val
      let s = String
      s.append("cafe"); s.push_utf32(0x0301); s.push(' ')      // café
      s.append("deja"); s.push_utf32(0x0300); s.push(' ')      // déjà (à)
      s.append("naive"); s.push_utf32(0x0308); s.push(' ')     // naïve (ï)
      s.append("resume"); s.push_utf32(0x0301); s.push(' ')    // résumé
      s.append("schone"); s.push_utf32(0x0308); s.push(' ')    // schöne
      s.append("Strasse"); s.push_utf32(0x0301); s.push(' ')   // (placeholder)
      s.append("uber"); s.push_utf32(0x0308); s.push(' ')      // über
      s.append("Hande"); s.push_utf32(0x0308); s.push(' ')     // Hände
      s
    end

  fun _cjk_pattern(): String val =>
    "中国汉字测试样本日本語サンプル  "

  fun _mixed_pattern(): String val =>
    "Hello 世界 café 中国 résumé 日本 World  "

  fun _emoji_pattern(): String val =>
    recover val
      let s = String
      s.push_utf32(0x1F600); s.push(' ')        // 😀 (single cp grapheme)
      s.push_utf32(0x1F389); s.push(' ')        // 🎉
      // Flag of France — Regional_Indicator pair = 1 grapheme.
      s.push_utf32(0x1F1EB); s.push_utf32(0x1F1F7); s.push(' ')
      // Family ZWJ sequence (man + ZWJ + woman + ZWJ + girl) — 1 grapheme.
      s.push_utf32(0x1F468); s.push_utf32(0x200D)
      s.push_utf32(0x1F469); s.push_utf32(0x200D)
      s.push_utf32(0x1F467); s.push(' ')
      s.push_utf32(0x1F680); s.push(' ')        // 🚀
      s
    end

  fun _combining_pattern(): String val =>
    """
    Pathological case for NFC composition / canonical-ordering: each
    base letter is followed by FIVE combining marks. NFC must read
    them all, canonical-order them, then re-compose where possible.
    """
    recover val
      let s = String
      var i: USize = 0
      while i < 8 do
        // Latin letter 'a' + 5 combining marks (each above/below).
        s.push('a')
        s.push_utf32(0x0301)  // combining acute (Above)
        s.push_utf32(0x0308)  // combining diaeresis (Above)
        s.push_utf32(0x0323)  // combining dot below (Below)
        s.push_utf32(0x0327)  // combining cedilla (Below_Attached)
        s.push_utf32(0x0316)  // combining grave below (Below)
        i = i + 1
      end
      s.push(' ')
      s
    end

  fun _repeat(pattern: String val, target: USize): String val =>
    """
    Append `pattern` repeatedly until the buffer reaches at least
    `target` bytes. Boundaries are always at codepoint boundaries
    because we only append whole patterns.
    """
    recover val
      let out = String(target + pattern.size())
      while out.size() < target do out.append(pattern) end
      out
    end
