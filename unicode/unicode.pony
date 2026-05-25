"""
# unicode

Unicode-correct text processing for Pony — graphemes, normalization, case
folding, search, segmentation, and more.

See the package README and `design/candidate-v3.md` for the full design.
This file holds the top-level `Unicode` primitive (version reporting).
"""

primitive Unicode
  """
  Top-level package handle. Exposes the Unicode version this build is pinned
  to.
  """
  fun version(): String val =>
    """
    The Unicode version against which this package's bundled UCD tables were
    generated. Format is dotted (e.g., "16.0.0").
    """
    "0.0.0"  // M0 placeholder; populated by `unicode-build` in M1.
