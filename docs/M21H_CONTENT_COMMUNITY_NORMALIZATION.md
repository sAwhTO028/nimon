# M21H — Content Community normalization (Compatibility)

## Goal

Fix **Content Community naming/normalization mismatch** between:
- Nimon app Settings (user preference `contentLocale`)
- Import JSON `nimonImportMeta.contentCommunity`
- External HTML generator output

This is **compatibility only**:
- No numeric HTML rule changes
- No import count validation changes
- No readiness/publish numeric rule changes
- No feed filtering changes in this phase

## Current canonical values

### App Settings (stored wire codes)

Nimon Settings stores Content Community as `UserPreferences.contentLocale`:
- `my` → **Myanmar**
- `en` → **International / English**
- `ja` → **Japanese**

### Import JSON (human labels)

Import JSON uses `nimonImportMeta.contentCommunity` as a human label.

**Canonical output going forward**
- **Myanmar** (not Burmese)
- English / International values remain aliases for `en`
- Japanese remains Japanese / `ja`

## Accepted aliases (import)

When validating import JSON against app setting:

### Myanmar community (`contentLocale == "my"`)
- Accept: `Myanmar` (canonical)
- Accept legacy: `Burmese`
- Accept code-style: `my`

### International / English community (`contentLocale == "en"`)
- Accept: `International / English`
- Accept: `International English`
- Accept: `International`
- Accept: `English`
- Accept code-style: `en`

### Japanese community (`contentLocale == "ja"`)
- Accept: `Japanese`
- Accept code-style: `ja`

## HTML generator requirements

The generator must:
- **Output `Myanmar`** in `nimonImportMeta.contentCommunity` when Myanmar is selected.
- Never output `Burmese` for newly generated JSON.

The generator may still:
- Accept older AI JSON that contains `Burmese` (converter-side normalization is optional),
  but the final import JSON output should be canonical.

## Future plan (not implemented here)

Later, we can formalize Content Community as codes:
- `my` = Myanmar
- `en` = International / English
- `ja` = Japanese
- `id` = Indonesian
- `vi` = Vietnamese

And implement feed filtering and/or content routing by selected community **in a later phase**.

