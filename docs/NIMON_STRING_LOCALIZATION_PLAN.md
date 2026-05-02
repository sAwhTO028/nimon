# Nimon String Localization Plan

**Goal:** Centralize **App System Language** strings so the solo developer (and Cursor) can translate UI reliably without touching pedagogy fields (`docs/NIMON_LANGUAGE_SYSTEM.md`).

---

## Current Migration Decision

- **Do not** enable full **flutter gen-l10n** yet unless the **product owner** approves (requires `pubspec.yaml` / codegen changes).
- **V1 cleanup** may use an **interim centralized string file** (e.g. `lib/l10n/app_strings.dart`) if needed to reduce scatter.
- **Long-term target** remains **ARB + `flutter gen-l10n`** per section 2 below.
- **New hardcoded user-facing strings** should be **avoided**; route copy through the interim file or existing conventions until ARB lands.

---

## 1. Centralized String Strategy

| Concern | Where it lives | Examples |
|---------|----------------|----------|
| **UI chrome** | Flutter localization (recommended: ARB + gen-l10n) | Save, Cancel, Settings |
| **Domain/learn content** | Entity fields (`sourceMeaning`, Japanese text)—**not** ARB | Lesson explanations |
| **English AI bridge** | `englishMeaning` fields + backend | Model drafts |

**Golden rule:** ARB / app strings = **chrome only**. Story/learn copy stays in **models/API**.

---

## 2. Recommended Flutter Localization Approach

1. Enable **`flutter gen-l10n`** in `pubspec.yaml` (`generate: true`, `arb-dir`, `template-arb-file`)—**when product approves** pubspec change (not done in this doc-only task).
2. Use **`AppLocalizations.of(context)!`** for widgets.
3. Keep **`intl`** / `flutter_localizations` aligned with Flutter SDK constraints.

Until gen-l10n is enabled, **interim:** a single `lib/l10n/app_strings.dart` (or similar) with **const keys** can reduce scatter—migrate to ARB later.

---

## 3. Do Not Hardcode UI Text in Screens

**Avoid:**

```dart
Text('Save draft')
```

**Prefer:**

```dart
Text(context.l10n.saveDraft) // after gen-l10n
// or AppStrings.saveDraft (interim)
```

**Exceptions (acceptable short-term):**
- Debug-only `debugPrint` labels.
- Developer-only tools under `tool/`.

---

## 4. App String Key Naming Convention

**Pattern:** `semantic.section.action` or `feature.screen.element`

Examples:

- `mono.feed.emptyState`
- `create.story.validation.titleRequired`
- `settings.language.title`
- `errors.network.generic`

Use **lowerCamelCase** keys in Dart accessors; ARB keys often use **snake_case** (`save_draft`)—pick one convention per ARB policy and stick to it.

---

## 5. Validation Message Strategy

- **Form validation** messages live in **App System Language**—same ARB namespace as settings (`validation.*` or `create.validation.*`).
- **Business rule failures** from backend should map to **localized** client messages via **error codes** (`STORY_TITLE_EMPTY` → mapped string)—avoid showing raw server English unless fallback.

---

## 6. Settings Language Switch Behavior

1. User selects **App System Language** in Settings.
2. Persist preference (`shared_preferences` / existing providers).
3. **`MaterialApp`** `locale` updates (already patterned with `appLocaleSettingProvider`).
4. **Restart not required** if providers + `locale` update propagate (test on Android/iOS/Web).

**Learn / Source Language** is **independent**—changing app locale must **not** rewrite story fields.

---

## 7. Migration Plan From Hardcoded Strings

| Phase | Action |
|-------|--------|
| **A** | Inventory top screens (Mono, Create shell, Profile tabs, Settings)—grep `'...'` in `lib/features/`. |
| **B** | Add ARB files `app_en.arb`, `app_ja.arb` (+ future locales). |
| **C** | Replace literals screen-by-screen; run `flutter gen-l10n`. |
| **D** | Lint: custom rule or manual review—no new raw UI strings in PRs. |

**Order:** Settings → shared dialogs → Mono → Create → Profile (wireframe priority).

---

## 8. Example Key Structure (ARB Fragment)

```json
{
  "@@locale": "en",
  "appTitle": "Nimon",
  "monoFeedTitle": "Mono",
  "actionSave": "Save",
  "actionCancel": "Cancel",
  "createStoryBasicsTitle": "Story basics",
  "validationTitleRequired": "Please enter a title."
}
```

---

## 9. How Cursor Should Update Strings Safely

1. **Search** existing keys before adding duplicates.
2. **Add** keys to **all** shipped locale ARBs in the same PR (at least `en` + `ja`).
3. **Do not** change unrelated screens’ strings.
4. **Run** `flutter gen-l10n` after ARB edits (when enabled).
5. **Run** `flutter analyze`.

---

## 10. Relationship to `NIMON_LANGUAGE_SYSTEM.md`

| Document | Focus |
|----------|--------|
| This file | **App UI** translation |
| Language system doc | **Content** languages (Source vs English vs Japanese) |

Never put **Source Meaning** text into ARB files.
