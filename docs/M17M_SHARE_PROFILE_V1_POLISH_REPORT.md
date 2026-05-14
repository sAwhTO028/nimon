# M17M — Share Profile V1 polish

**M17M status:** **Passed** (V1 complete). **Phone verification:** **Passed** — on-device check and **screenshots** looked good; no further product action required for V1.

## Summary

Replaced the **poster-style** share screen (large elevated card, fake QR, Share-before-copy, download placeholder) with a **utility-first** layout: compact identity block, **Copy link** as the primary action, **Share profile** (system sheet) as secondary, **real QR** encoding the public URL, and a short **privacy hint**. **Download card** was removed for V1.

## V1 final layout (documented)

- **Identity card:** avatar (or default icon), display name, `@handle`, **short URL** label (`host` + path, e.g. `nimon.app/u/handle`).
- **Primary:** **Copy link** (`FilledButton`).
- **Secondary:** **Share profile** (`OutlinedButton` → native share sheet, same URL as copy).
- **QR section:** real QR in a rounded container; caption **Scan to open profile** (localized).
- **Footer:** public profile visibility hint (localized).
- **Download card:** **removed** for V1 (no placeholder).

**V1 closeout:** No further engineering or design action required for Share Profile in V1 unless product reopens scope (e.g. downloadable share card in a later milestone).

## Old vs new layout

| Before | After |
|--------|--------|
| Large `surfaceContainerHighest` hero card filling space | Compact `surfaceContainer` identity card (avatar, name, @handle, short link text) |
| Decorative fake QR (`CustomPaint`) | `qr_flutter` **QrImageView** with real URL payload (black on white tile for scan contrast) |
| **Share** filled + **Copy** outlined; Share called copy + “coming soon” | **Copy link** `FilledButton` (primary) + **Share profile** `OutlinedButton` → `Share.share(url)` |
| **Download card** `TextButton` | **Removed** |
| Raw full URL only at bottom | Short label (`host` + `path`, e.g. `nimon.app/u/alice`) under identity; copy/share/QR use **full HTTPS URL** |
| Hard-coded English strings | **AppLocalizations** (`shareProfile*` keys in `app_en.arb`, `app_ja.arb`, `app_my.arb`) |

## Actions kept

- **Copy profile link** (clipboard + **“Link copied”** snack; snack shown immediately, then clipboard write completes).
- **Native share** via **`share_plus`** (`Share.share` with the same URL).
- **QR** for the same URL.
- **Close** (toolbar leading).
- **Public identity**: display name, `@handle`, avatar when `avatarUrl` is passed.

## Actions removed / de-emphasized

- **Download card** — removed (no placeholder).

## URL source

- **`resolvePublicProfileShareUrl`** (`lib/features/profile/share_public_profile_url.dart`): same policy family as mono shares — **explicit URL** (optional future API) → `{NIMON_PUBLIC_WEB_BASE_URL}/u/{slug}` with slug from **handle** (strip `@`) or **userId** if no handle → non-loopback **`NIMON_API_BASE_URL`** `/u/{slug}`; **empty** if only loopback API (no unsafe localhost links).
- **Profile → Share** passes **`ShareProfileScreenArgs`** from `profile_screen.dart` (`displayName`, `handleLine`, `avatarUrl`, `userId`). Router in `main.dart` resolves the final URL and builds **`ShareProfileScreen`**.
- **Deep link** `/profile/share` without `extra` keeps a small **demo** profile using an explicit `https://nimon.app/u/just4withyou` resolver input (unchanged marketing sample).

## QR source

- **`QrImageView.data`** = resolved **full public profile URL** (same string as copy/share).

## Dependencies

- **`share_plus`** — system share sheet.
- **`qr_flutter`** (+ `qr`) — QR rendering.

## Tests

| File | Coverage |
|------|----------|
| `test/features/profile/share_public_profile_url_test.dart` | Resolver: explicit URL, public web + handle, userId slug, LAN API fallback, loopback empty; short label |
| `test/features/profile/share_profile_screen_test.dart` | UI: name / handle / short URL; copy → snack; share channel `text`; QR `ValueKey`; no Download; dark theme name color `onSurface` |

**Note:** Snackbar is shown **before** `await Clipboard.setData` so widget tests are not blocked by clipboard platform channel timing; copy still runs immediately after.

## Commands run

```text
dart format <touched Dart files>
flutter test test/features/profile   # 261 passed, ~3 skipped (one run)
flutter test                         # 741 passed, ~3 skipped (one run)
```

## Phone acceptance

**Result:** **Passed** (manual phone + screenshots). Layout, contrast, copy/share/QR behavior, and absence of Download card matched the V1 spec.

1. Open **Share Profile** from owner profile — see title **Share Profile**, identity, short link, QR, hint.
2. **Copy link** — snack **Link copied**; pasted URL opens public profile in browser (same host as configured `NIMON_PUBLIC_WEB_BASE_URL` / production).
3. **Share profile** — OS share sheet opens with the same URL.
4. QR scans to the same URL.
5. No **Download card** row.
6. **Dark mode** — scaffold background, surfaces, `onSurface` / `onSurfaceVariant` readable.
