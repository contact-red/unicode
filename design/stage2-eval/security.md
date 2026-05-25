# Security Evaluation — Pony Unicode Package Candidate v1

**Evaluator:** Security persona
**Target:** `/home/red/tmp/unicode-design-20260525-103015/candidate-v1.md`
**Date:** 2026-05-25
**Scope:** Security properties baked into the design artifacts. Not implementation bugs.

## 1. Trust-boundary map

| Boundary | API | Validation owner | Fail-closed? |
|---|---|---|---|
| String → Text (strict) | `Text.from_string(s)` | Text constructor | Yes — `(Text val \| InvalidUtf8)` |
| String → Text (lossy) | `Text.from_string_lossy(s)` | Text constructor after substitution | **No** — silent U+FFFD |
| Bytes → Text | `Text.from_utf8_bytes(b)` | Text constructor | Yes |
| Bytes (iso, zero-copy) → Text | `Text.from_utf8_iso(consume b)` | Text constructor | Yes — `?` partial |
| Scalars → Text | `Text.from_codepoint_scalars(scalars)` | Text constructor | Yes — `InvalidScalar` |
| Codepoint val → Text | `Text.from_codepoint(cp)` | Codepoint already validated | N/A (total) |
| Decoded bytes → Text | `Text.decode(bytes, enc, policy, indexed)` | Encoding impl per policy | **Depends on policy** |
| U32 → Codepoint (strict) | `Codepoint.from_u32(u)` | Codepoint constructor | Yes — `InvalidScalar` |
| U32 → Codepoint (replacing) | `Codepoint.from_u32_or_replacement(u)` | Codepoint constructor after substitution | **No** — silent U+FFFD |
| Bytes → predicates | `Bytes.is_valid_utf8(s)` etc. | pure predicates | N/A |
| Internal `_create(scalar)` | package-private | trusts caller within package | underscore-audit-able |

Structural picture is healthy: every boundary has a named owner; strict factories are fail-closed; errors are unions (compile-enforced exhaustive matching via Pony gotcha #9).

## 2. Findings (ordered by impact)

### F1 — Identifier matching primitive is unsafe for its stated use case (Structural)

**Design element:** §5 — `eq_caseless_normalized` described as "the identifier-matching default; one call, one decision, no chance to forget a step." Default normalization is `NFCForm`.

**Concern:** The primitive recommended for identifier matching is missing two of three pieces required to be safe:
1. **Wrong normalization form.** UTS #39 §3 (Identifier Comparison) and RFC 8264 (PRECIS) prescribe NFKC, not NFC. With NFC, "ﬃ" (U+FB03) ≠ "ffi", "Ⅻ" ≠ "XII", "①" ≠ "1". Attacker registers `admin`; another user registers `adﬃin` (ligature) — both look identical, compare unequal under `eq_caseless_normalized(_, NFCForm, _)`.
2. **No confusables check.** Cyrillic "а" U+0430 vs Latin "a" U+0061, Cherokee letters resembling Latin, full-width forms, IPA letters — compare unequal at every level (codepoint, NFC, NFKC, case-fold). Look identical. This is THE canonical Unicode identifier attack. Deferred to v0.7.

The phrasing "no chance to forget a step" is actively misleading — the most important step is being forgotten.

**Impact:** Structural. Vulnerability window v0.1–v0.6 (five releases). Anyone following the design's own recommended identifier primitive ships vulnerable code.

**Evidence:**
- §5 declarative: "the identifier-matching default; one call, one decision, no chance to forget a step"
- §9: confusables in v0.7
- UTS #39 §3 + RFC 8264 §5: prescribe NFKC + case-fold + restricted-script + confusables

**Suggested change:** Stop framing `eq_caseless_normalized` as "the identifier-matching default." Introduce `eq_identifier` gated on v0.7 (or fail-closed before that). If a v0.1 identifier primitive is required, force an explicit `IdentifierProfile` argument *now* — incomplete profile, but the type forces callers to confront the choice. Default normalization for any identifier-shaped equality is NFKC, not NFC. Update consumer sketch B.

---

### F2 — `IgnorePolicy` on decode is a known anti-pattern; design does not steer callers away (Significant)

**Design element:** §1 — `DecodePolicy = StrictPolicy | ReplacePolicy | IgnorePolicy`.

**Concern:** `IgnorePolicy` silently drops invalid sequences. UTR #36 §3.1 and WHATWG Encoding Standard warn against this for security. Payload `admin\xC0\x80` decoded with `IgnorePolicy` → `admin`, bypassing byte-level filters. The design specifies no default (good — forces choice) but provides no guidance on when each policy is appropriate. The asymmetry between encode (Strict|Replace) and decode (+Ignore) is itself unjustified in the design.

**Impact:** Significant.

**Suggested change:** Drop `IgnorePolicy` from v0.4. Caller wanting ignore-behavior uses `ReplacePolicy` + post-filter on U+FFFD. If retained, rename to `DropInvalidPolicy` and isolate behind `decode_dropping(...)` factory — distinct semantics deserve distinct representation (principle 12).

---

### F3 — `from_string_lossy` substitution policy is invisible after the fact (Significant)

**Design element:** §1 — `Text.from_string_lossy(s, indexed = false): Text val`. Returns `Text val` with no indicator that substitution occurred.

**Concern:** A `Text val` from `from_string_lossy` is indistinguishable from one from `from_string`. Two attack shapes:
1. **Filter bypass via substitution.** Byte-level filter precedes lossy decode. Attacker crafts invalid bytes that would match if interpreted; substitution produces a different form; filter never sees malicious form.
2. **Identity confusion.** Different invalid sequences both produce identical lossy `Text`. `alice\xC0\xC0` and `alice\xFF\xFF` both → `alice����`. Storage layer sees distinct; display layer sees collision.

**Impact:** Significant.

**Suggested change:** Either rename to `from_string_with_replacement` requiring an explicit `ReplacePolicy` arg parallel to `decode(...)`; or return `(Text val, USize)` with substitution count; or add `was_substituted(): Bool` on `Text` with an internal flag. Whichever, document substitution as a security-relevant boundary on par with `IgnorePolicy`.

---

### F4 — Confusables staging creates a multi-release vulnerability window (Significant)

**Design element:** §9 — confusables in v0.7. §11 T1–T7 do not flag this gap.

**Concern:** v0.1–v0.2 ships with identifier-relevant predicates and the package's own recommendation (§5, §8H) to use existing primitives for identifier matching. Username systems get built and deployed before v0.7. No design element signals "incomplete for identifier matching." Mixed-script detection in v0.3 catches only single-script-impersonation attacks; pure-Latin confusables (Latin small letter turned f U+025F) pass.

**Impact:** Significant. Compounds F1.

**Suggested change:** Add §11 tension: identifier matching is not security-complete until v0.7; users must not deploy security-sensitive identifier matching on v0.1–v0.6. Consider promoting `Confusables` to v0.3 (after Scripts lands). Make v0.2 `eq_caseless_normalized` explicitly *non-identifier* (rename / re-document as "display equality").

---

### F5 — `EncodeError.codepoint` exposes potentially-sensitive content; not flagged (Significant)

**Design element:** §6 — `class val EncodeError { let codepoint: Codepoint val; let encoding_name: String val; fun string(): String iso^ }`.

**Concern:** Encoding sensitive text (passphrase, message, key) to Latin-1/ASCII/CP1252; encoder fails on a non-representable codepoint; error string leaks that codepoint when logged, displayed, or propagated. Task brief asserts "the candidate flags this" — security evaluator cannot find such a flag. §6 defines the field with no commentary. §11 T1–T7 do not mention error-content leakage. Principle 7 (handle sensitive data deliberately) is not invoked.

**Impact:** Significant.

**Suggested change:** Replace `codepoint: Codepoint val` with `offset: USize`. Callers needing the codepoint read from input at the offset. Alternatively keep `codepoint` but make `string()` redacted by default with an opt-in `unsafe_string_with_codepoint()`. Add §11 tension.

---

### F6 — Resource bounds not specified for normalization / case mapping / grapheme clustering (Significant)

**Design element:** §3.5 (bitmap), §5 (normalize), v0.2 case mapping, v0.1 grapheme clustering.

**Concern:** Output sizes can exceed input sizes; design specifies no bound mechanism.
1. **Normalization expansion** (UAX #15): NFD/NFKD up to ~18×.
2. **Case mapping expansion**: ß → SS, special-casing per locale.
3. **Combining mark storms / Zalgo**: single base + thousands of marks is a valid cluster under UAX #29; cluster length is unbounded; iterating/normalizing/rendering the slice is unbounded work.
4. **Bitmap index size**: bounded — OK.
5. **Decode-replace expansion**: each invalid byte → 3 bytes (U+FFFD UTF-8). Bounded factor 3.

**Impact:** Significant for DoS-exposed services. Mitigations don't require accepting fixed bounds — the design just needs to acknowledge expansion and offer bounded variants where useful.

**Suggested change:** Add §11 tension: "Normalize/case-map output may exceed input length; DoS-exposed callers must bound input size." Consider `normalize_bounded(form, max_output_bytes): (Text val | OutputTooLarge | InvalidUtf8)` in v0.2. Document worst-case expansion factor per operation.

---

### F7 — UCD trust gate is described but not enforced (Minor)

**Design element:** §7 — `unicode-build` generates UCD at library release time. §9 lists conformance gates per release.

**Concern:** Gates named but not specified as part of the release process. A `unicode-build` regression could ship wrong tables if conformance is not pipeline-enforced.

**Impact:** Minor in the design; could become Structural with informal gating.

**Suggested change:** Add §11 tension stating conformance suite must run before tagging. Consider a runtime `Unicode.self_check()` for opt-in startup verification.

---

### F8 — `Codepoint.from_u32_or_replacement` parallels F3 at codepoint granularity (Minor)

**Design element:** §1, §4.1 — `Codepoint.from_u32_or_replacement(u): Codepoint val`.

**Concern:** Silent substitution at codepoint level. A binary protocol carrying codepoint U32s decoded with this loses distinction between "sender sent U+FFFD" and "sender sent garbage."

**Impact:** Minor (less ergonomically prominent than `from_string_lossy`).

**Suggested change:** Rename to `from_u32_substituting` (more deliberate). Optionally return `(Codepoint val, Bool)` with substitution flag.

---

### F9 — Bitmap index correctness invariant rests on internal discipline only (Minor)

**Design element:** §3.5 — `Text val { _utf8: String val; _form: NormalForm; _index: (_TextIndex val | None) }`.

**Concern:** Pony caps + package privacy + val immutability make user-controlled inconsistency structurally impossible. The invariant ("if `_index = Some(idx)` then `idx._gr_starts` is UAX-#29-consistent with `_utf8`") is implied, not stated. Future maintainer adding a constructor or mutation could violate silently. Principle 11.

**Impact:** Minor.

**Suggested change:** Add the invariant statement at the `_TextIndex` definition (point of breakage). Consider debug-only `_invariant_check()`.

---

### F10 — `Codepoint._create` validation discipline sound; one audit cost (Minor)

**Design element:** §4.1 — `new val _create(scalar: U32)` is package-private.

**Concern:** Within-package code can bypass validation via `_create`. Underscore convention surfaces this for code review but the design states no invariant ("any `_create` call must be preceded by proof that `u` is a valid scalar").

**Impact:** Minor.

**Suggested change:** State the invariant at `_create`.

---

### F11 — `Text.codepoint_scalars()` invariant claim is correct, with caveat (Minor)

**Design element:** §4.2 — "every U32 yielded is a valid scalar by construction."

**Concern:** Audited every Text constructor:

| Constructor | Validation? |
|---|---|
| `from_string(s)` | yes |
| `from_string_lossy(s)` | yes (substituted bytes are valid UTF-8) |
| `from_utf8_bytes(b)` | yes |
| `from_utf8_iso(consume b)` | yes |
| `from_codepoint_scalars(scalars)` | yes |
| `from_codepoint(cp)` | yes |
| `decode(bytes, enc, policy, indexed)` | yes for all policies (IgnorePolicy produces valid UTF-8 by dropping) |

Invariant holds. Concern is purely about future maintenance — invariant not stated on `Text val`.

**Impact:** Minor.

**Suggested change:** State the invariant on `Text val`.

---

### F12 — Offset leakage in errors is bounded; likely acceptable (Minor)

**Design element:** §6 — `_InvalidUtf8At { offset }`, `DecodeError { offset }`.

**Concern:** Weak side-channel; offset granularity is right for debuggability.

**Impact:** Minor. Acknowledged trade-off; no redesign.

**Suggested change:** Mention in §11 alongside F5 acknowledgement.

---

### F13 — `Bytes.first_bad_utf8_offset(s)` return semantics for valid input not specified (Minor)

**Design element:** §1 — `Bytes` primitive.

**Concern:** If `s` is valid UTF-8, what is returned? Sentinel? `s.size()`? Union? Design favors unions over sentinels elsewhere. Bare USize violates principle 1.

**Impact:** Minor.

**Suggested change:** Spec as `(USize | AllValid)`.

---

## 3. Passes

1. Errors-as-data with closed unions of primitives — compile-enforced exhaustive matching.
2. Phantom-typed indices — security-relevant correctness mechanism.
3. Strict-by-default construction — fail-closed.
4. Capability discipline — all public types val, no actor smuggling, no FFI boundary, UCD tables val.
5. Codepoint validation centralized; `_create` package-private.
6. Build-time UCD generation, version-pinned.
7. NormalForm `UnknownForm` default — no silent normalization.
8. Public/internal split via underscore methods — auditable.
9. Grapheme slices zero-copy and val — no mutability shortcuts (subject to T3 verification).

## 4. Uncertainties

1. **Decode policy default** — `Text.decode(..., policy, ...)` with no default; I read this as forced choice. Flag if changed.
2. **Substitution algorithm** in `from_string_lossy` — §10 #8 says W3C maximal-subpart; implementation-level verification required.
3. **Slice type for Words/Sentences/Lines** — §1 and §8E disagree. Assuming `Text val`; if `String val`, F6 grapheme-storm analysis applies identically.
4. **Confusables data trust path** — UTS #39 conformance gate listed; skeleton transform composition not specified in design.
5. **`IdentifierProfile` interaction with equality primitives** — §9 v0.7 lists the profile; relationship to existing primitives unspecified. F1 suggested fix depends on this.
6. **Names subpackage trust** — §11 T4's tentative option 3 (names lives in subpackage) is sound. Option 1 (global hook) would introduce mutable global state — significant for capability reasoning. Analysis assumes option 3.

## 5. Impact summary

- **Structural:** F1.
- **Significant:** F2, F3, F4, F5, F6.
- **Minor:** F7, F8, F9, F10, F11, F12, F13.

F1 + F4 are tightly coupled and should be addressed together. F3 + F5 + F8 are a silent-substitution / leakage family — unified §11 tension treatment.
