# M13I Validation Translation Audit

## Pre–M13I state (M13H)

All keys under `validation*` in `app_ja.arb` and `app_my.arb` that were added from the English template via `tool/mirror_arb_locales.dart` **matched English verbatim** (mirrored). Settings keys that pre-existed in ja/my were already properly translated and were **not** considered mirrored.

## Post–M13I state

| Priority bucket | Keys (ARB names) | `app_ja.arb` | `app_my.arb` |
|-----------------|------------------|--------------|--------------|
| 1 Protected + network + CTAs | `validationProtected*`, `validationNetworkOffline`, `validationCta*` | Translated | Translated |
| 2 Auth | `validationAuth*` | Translated | Translated |
| 3 Profile | `validationProfile*` | Translated | Translated |
| 4 Collections | `validationCollectionTitle*`, `validationCollectionName*` | Translated | Translated |
| 5 Story basics | `validationStoryTitle*`, `validationStoryDescription*` | Translated | Translated |
| 6 Publish sheet + field labels | `validationPublish*`, `validationField*`, `validationLearnModule*` | Translated | Translated |
| 7 Media | `validationMedia*`, `validationMediaUploadGeneric*` | Translated | Translated |
| 8 Learn / publish limits | `validationLearn*`, `validationStorySentences*`, `validationStoryBodyTooLong`, `validationStoryLimits*` | Translated | Translated |

**Translation status:** High-traffic validation UX strings are **no longer English mirrors** in ja/my for the full validation block present in `app_en.arb`.

## Mirrored keys remaining

None intentionally left as English for the validation subset shipped in this pass; spot-check: grep English phrases such as `"Before publishing"` under `lib/l10n/app_ja.arb` / `app_my.arb` returns no hits.

## Style guide (short)

### Myanmar

- Concise, natural UI Burmese; avoid stiff legal tone.
- Prefer short directives (“ထည့်ပါ”, “မဖြစ်ရပါ”) over blaming the user.
- **Sign in (validation CTA):** ဝင်မည် (compact; settings may still use ဝင်ရောက်မည်).
- **Not now:** နောက်မှ.
- **Publish:** ထုတ်ဝေ — combined with clarifiers where needed (e.g. publish-anyway button).
- **Story:** စတိုရီ where clarity helps; JLPT/technical labels may stay recognizable.

### Japanese

- Polite, compact product Japanese (です／ます調).
- **ログイン**, **今はしない**, **公開**, **入力内容を確認してください** — align prompts with common app patterns.
- Field errors: short and specific; avoid stacking multiple clauses where one sentence suffices.
