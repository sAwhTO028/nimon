# Nimon Language System

**Purpose:** Define four distinct language layers so UI, pedagogy, AI bridging, and Japanese content do not collide in schema or UX.  
**Related:** `docs/NIMON_STRING_LOCALIZATION_PLAN.md` (Flutter UI strings), `docs/NIMON_AI_FEATURE_PLAN.md` (English as AI bridge).

---

## 1. App System Language

**Definition:** The locale used for **application chrome only**—buttons, labels, tabs, settings titles, empty states, snackbars, validation messages **about the app**, etc.

**Rules:**
- Controlled by **`Locale`** / Material localization (and persisted settings such as `appLocaleSettingProvider` where applicable).
- **Must be centralized** via ARB / `AppStrings` / generated lints—see localization plan.
- **Never** store App System Language inside story content rows.

**Examples:** “Save draft”, “Publish”, “Settings”, “Network error”.

---

## 2. Learn Language / Source Language

**Definition:** The language the **learner or writer uses for explanations** tied to Japanese learning content—**Source Meaning**, **Source Usage**, **Source Explanation**, **Source Notes**, and similar pedagogy fields.

**Rules:**
- This is **not** the same as App System Language (e.g. UI in English but explanations in Myanmar).
- Writers/learners may choose this explicitly where the product allows (see Settings / creator panels).
- Persist as **explicit fields** (or locale codes) on entities—do not infer from device locale alone.

**Example:** A Myanmar learner writes **Source Meaning** in **Myanmar** while the app UI stays Japanese or English.

---

## 3. English Meaning

**Definition:** The **canonical AI bridge language** for machine-assisted generation, validation, deduplication, and cross-language tooling.

**Rules:**
- Used for **OpenAI/API prompts**, structured extraction, glossaries, and **fallback** explanations when product policy allows.
- **Stored separately** from Source Meaning—never overwrite Source Meaning with English unless the user confirms or product rules say so.
- **User-facing display** of English Meaning is **opt-in** via settings or field-level toggles (wireframe + product).

**Examples:** Normalized gloss string sent to the model; standardized quiz distractor text for NLP.

---

## 4. Japanese Content Language

**Definition:** The **story’s Japanese sentences** including **furigana** (ruby), readings, and Japanese punctuation conventions.

**Rules:**
- This is **content**, not UI chrome.
- Furigana attaches to **Japanese text**—do not store furigana as App System Language strings.
- Translation lines (if present) belong to their own fields per wireframe—not mixed into `flutter_localizations`.

---

## Product Decisions

### Default Learn / Source Language

- On first launch or first creator setup, the user should **explicitly choose** Learn / Source Language.
- If the user skips that step, **fallback to App System Language** as a **temporary** default until they choose.
- Do **not** permanently infer Learn / Source Language from device locale **without** user confirmation.
- The user can change Learn / Source Language later in **Settings**.
- **Existing content fields** must **not** be automatically rewritten when this setting changes (copy stays as authored; only defaults or new fields follow the new preference—exact UX follows wireframe).

### English Meaning Display Policy

- **English Meaning** is **hidden** from normal reader view **by default**.
- **English Meaning** may appear in **creator/editor review** mode.
- **English Meaning** may appear when the user enables a setting such as **“Show English Meaning”**.
- **English Meaning** remains available **internally** for AI/backend even when hidden from UI.
- **Source Meaning** remains the **primary** learner-facing explanation.

---

## 5. How These Fields Differ (Summary)

| Layer | What it controls | Typical storage | UI driven by |
|------|-------------------|-----------------|--------------|
| App System Language | Buttons, settings, errors | ARB / string table | `Locale` + l10n |
| Learn / Source Language | Learner-facing explanations | Per-field text + optional locale metadata | Writer/learn settings |
| English Meaning | AI + canonical bridge | Dedicated fields | Settings / AI pipeline |
| Japanese Content | Story body | Sentence + ruby tokens | Reader/editor |

---

## 6. Data Model Guidance: Story, StorySentence, Vocabulary, Grammar, Quiz

**Principle:** Each pedagogical entity should support **at least**:

- **`sourceMeaning`** (or equivalent): human-authored meaning in **Learn / Source Language**.
- **`englishMeaning`** (or equivalent): canonical English for AI/backend use and optional UI when allowed.

**Suggested shapes (conceptual—not forcing immediate refactor):**

```text
StorySentence {
  japaneseText,
  furiganaTokens,
  sourceMeaning?,      // Learn language
  englishMeaning?,     // AI bridge / optional display
  ...
}

VocabularyItem {
  termJapanese,
  reading?,
  sourceMeaning?,
  englishMeaning?,
  ...
}

GrammarPattern {
  patternLabelJp?,
  sourceExplanation?,
  englishMeaning?,    // Or englishSummary for AI
  ...
}

QuizItem {
  promptJp?,
  sourceExplanation?,
  englishMeaning?,    // For generation / review
  ...
}
```

**Do not** collapse Source and English into one string without migration and UI rules.

---

## 7. UI Display Rules

1. **App chrome** uses **App System Language** only.
2. **Japanese sentence area** shows **Japanese Content Language** + furigana per reading prefs.
3. **Learner explanations** default to **Learn / Source Language** fields.
4. **English Meaning** appears only when:
   - settings allow “show English”, or
   - wireframe specifies bilingual display, or
   - editorial/review mode requires it.
5. **Validation messages** about forms use **App System Language**.

---

## 8. AI Generation Rules

1. **Inputs:** Prefer **Japanese Content** + **English Meaning** (when generating from structured data) + explicit Learn Language instruction.
2. **Outputs:** AI proposes **English Meaning** and/or draft **Source Meaning**—human confirmation before treating as canonical learner text where required.
3. **Never** silently replace **Source Meaning** with model output without user action.
4. **Routing:** AI calls go through **backend or repository abstraction**—see AI feature plan.

---

## 9. Fallback Rules

| Scenario | Fallback behavior |
|----------|-------------------|
| Source Meaning missing | Show placeholder in App System Language *about* missing content; optional English Meaning reveal if policy allows. |
| English Meaning missing | AI/backend may compute; if offline, skip or show “unavailable”. |
| App locale missing translation | Fallback English string key from ARB (project policy). |
| Learn Language unset | Use **Product Decisions** above: explicit choice preferred; temporary fallback to App System Language if skipped; do not permanently infer from device locale without confirmation. |

---

## 10. Cursor / Contributor Checklist

- [ ] New UI string → localization table, not inline literal (except debug-only).
- [ ] New learner field → decide **source vs english** columns explicitly.
- [ ] New AI output → separate **draft** from **published** content state.
