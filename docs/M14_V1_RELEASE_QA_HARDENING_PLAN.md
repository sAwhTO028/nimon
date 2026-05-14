# M14 V1 Release QA Hardening Plan

## Goals

- Lock a **repeatable V1 release regression** path for Nimon before external QA or store submission.
- Confirm **backend** and **Flutter** automated gates still pass after M13A–M13I validation, connectivity, and localization work.
- Provide **operator checklists** (phone smoke, auth/guest, creator, reader, social, media, validation, offline) so nothing critical is missed on a real device and LAN backend.
- Define **release blocker criteria** and **known risk areas** so the team can sign off with clear go/no-go rules.

## Scope

- **Documentation:** Final regression checklist, smoke matrix, and sign-off checklist (this plan + M14 report).
- **Automated verification:** `nimon-backend` Jest + Nest build; Flutter `gen-l10n`, `dart format`, `analyze`, `test`.
- **Manual / device verification:** Smoke on physical phone against backend on LAN (`192.168.11.5:3000`) with remote drafts, remote mono feed, and public web base URL aligned to the same host (see Test Environments).
- **Fixes:** Only **small, release-blocking** issues discovered during the above; each fix paired with a focused test when practical.

## Out of Scope

- New product features, UX redesigns, or broad refactors.
- Rewriting validation architecture or changing validation rules unless a **release-blocking** bug is proven.
- Changing localization **keys** unless broken (copy tweaks only when required for correctness).
- Backend schema or contract changes unless **absolutely required** for a blocker.
- Downgrading dependencies for convenience (prefer toolchain alignment, already addressed for Android where applicable).

## Test Environments

| Layer | Configuration |
|--------|----------------|
| **Flutter app** | Debug or profile build on **physical Android** (recommended primary for V1 smoke). |
| **API** | Backend listens **`0.0.0.0:3000`**; app uses `--dart-define=NIMON_API_BASE_URL=http://192.168.11.5:3000`. |
| **Public web / share** | `--dart-define=NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000` so share links are not `localhost`. |
| **Mono feed** | `--dart-define=NIMON_USE_REMOTE_MONO_FEED=true`. |
| **Drafts** | `--dart-define=NIMON_USE_REMOTE_DRAFTS=true`. |
| **Media** | `MEDIA_PUBLIC_BASE_URL=http://192.168.11.5:3000/uploads`; verify cover/avatar/audio URLs load on phone. |

**Example device run (PowerShell):**

```powershell
flutter run `
  --dart-define=NIMON_API_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_PUBLIC_WEB_BASE_URL=http://192.168.11.5:3000 `
  --dart-define=NIMON_USE_REMOTE_MONO_FEED=true `
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true
```

## Backend Verification

**Commands (from repo root):**

```bash
cd nimon-backend
pnpm jest --runInBand
pnpm nest build
```

**Fallback if `pnpm` unavailable:**

```bash
cd nimon-backend
node ./node_modules/jest/bin/jest.js --runInBand
node ./node_modules/@nestjs/cli/bin/nest.js build
```

**Manual / API smoke (against running server):**

- Auth: register, login, token refresh behavior as exercised by tests or Postman.
- **Profile PATCH:** validation errors and `validation_failed` envelope consistency.
- **Collections:** create/update validation, ownership errors.
- **Story draft:** create, update, versioning if applicable.
- **Publish:** read-only publish path; full learn publish path.
- **Media upload:** size/type validation and error messages.
- **`validation_failed` response shape:** stable `statusCode`, `message` / `issues[]` contract as documented in M13 specs.

Do not edit backend unless automated tests fail or smoke reveals a **release blocker**.

## Flutter Verification

**Commands (from Flutter project root):**

```bash
flutter gen-l10n
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

**Checks:**

- Generated ARB-derived files are current and imports resolve.
- `dart format` exits 0 (no unformatted Dart).
- `flutter analyze`: no **new** errors; existing info-level warnings may be documented in the M14 report (do not add blanket ignores).
- All tests pass.

## Phone Smoke Matrix

| # | Area | Action | Pass criteria |
|---|------|--------|----------------|
| P1 | Launch | Cold start | App opens, no crash |
| P2 | Feed | Open Mono tab | Remote items load |
| P3 | Reader | Open item | Content, meta, back |
| P4 | Network | Airplane toggle | Snackbars, recovery |
| P5 | Media | Cover / audio | Loads from LAN base URL |
| P6 | Share | Share sheet / copy | URL uses public LAN base, not localhost |

## Auth / Guest Matrix

Execute **Part E** checklist (guest browse, protected actions prompt, register/login/logout). Record pass/fail and build in report.

## Creator Flow Matrix

Execute **Part F** checklist (draft lifecycle, read-only publish, profile visibility, edit/republish/trash). Record pass/fail.

## Reader Flow Matrix

Execute **Part G** (full learn creation smoke) and **Part H** (feed + reader + social affordances). Record pass/fail.

## Social/Profile Matrix

Execute **Part I** checklist (own profile, edit, public profile, follow lists, saved, collections).

## Media Upload Matrix

Valid image/audio uploads succeed; invalid MIME/size yields **friendly, localized** errors; offline shows snackbar, not raw stack traces.

## Validation/Localization Matrix

Languages: **English**, **Myanmar**, **Japanese**.

Per language, run **Part J** cases (invalid email, wrong password, handle, collection name, publish title, learn field, guest prompts, offline, bad media).

**Quality bar:**

- No English mirror for high-priority user-facing strings in my/ja where product spec requires translated copy.
- No severe overflow on small phone.
- No raw `messageKey` or raw JSON `validation_failed` blob shown to users.
- Unknown l10n key fallback must not crash.

## Offline/Connectivity Matrix

Execute **Part K**: authenticated happy path online; then airplane mode for React/Follow/Save/Publish/Upload; restore network; actions work without restart.

## Known Risk Areas

- **LAN-only URLs:** Wrong `NIMON_PUBLIC_WEB_BASE_URL` → share links unusable off-LAN.
- **Disk / Gradle:** Android native builds need sufficient free space.
- **Guest vs auth:** Any path that mutates server state without sign-in is a **severity 1** defect.
- **validation_failed parsing:** Client must map issues to fields; raw Dio errors must not leak to UI.
- **Myanmar / Japanese:** Long strings and mixed scripts on narrow layouts.

## Release Blocker Criteria

Treat as **blocker** if any of the following is true:

- App cannot launch on target device.
- Backend cannot build or Jest suite fails.
- Flutter tests fail or `dart format --set-exit-if-changed` fails.
- Publish flow broken (cannot publish read-only or full learn when valid).
- Auth broken (cannot register/login/logout).
- Profile or mono reader crashes in common paths.
- Phone cannot load media from configured public base URL.
- `validation_failed` shown as raw JSON to the user.
- User sees raw Dio/socket/backend stack string in normal UI.
- Guest protected action **mutates** remote data.
- Localization / delegate error causes runtime crash.
- Share URL points to phone **localhost** instead of configured public base.

## Final Sign-off Checklist

- [ ] Backend: `jest --runInBand` green; `nest build` green.
- [ ] Flutter: `gen-l10n`, format, `analyze` (per team policy), `test` green.
- [ ] Phone smoke matrix complete (P1–P6).
- [ ] Auth/guest matrix (Part E) complete.
- [ ] Creator matrix (Part F) complete.
- [ ] Full learn matrix (Part G) complete.
- [ ] Reader matrix (Part H) complete.
- [ ] Profile/social matrix (Part I) complete.
- [ ] Validation/l10n matrix (Part J) for en / my / ja complete.
- [ ] Offline matrix (Part K) complete.
- [ ] No open release blockers; remaining risks documented.
- [ ] **Sign-off:** Name, date, build / commit SHA.

---

## Part E — Auth / guest smoke

1. Guest can open app and browse Mono feed.
2. Guest can read public content.
3. Guest React → sign-in prompt.
4. Guest Follow → sign-in prompt.
5. Guest Save → sign-in prompt.
6. Guest Create Story → sign-in prompt.
7. Guest Publish → sign-in prompt before validation.
8. Register valid account.
9. Register invalid email → localized field error.
10. Login wrong password → generic localized error only.
11. Logout / login again.

## Part F — Creator smoke

1. Create new story.
2. Fill story basics.
3. Upload valid cover.
4. Try invalid cover type → friendly localized error.
5. Add sentences.
6. Save draft.
7. Reopen draft.
8. Publish Read-only.
9. Confirm appears in profile published tab.
10. Open from Mono feed / profile.
11. Edit published mono.
12. Update title/description/sentences.
13. Re-publish/update.
14. Trash published mono.
15. Restore if supported.
16. Permanent delete if supported.

## Part G — Full Learn smoke

1. Create story with Full Learn.
2. Add vocabulary.
3. Add furigana / reading.
4. Add grammar.
5. Add quiz.
6. Add audio.
7. Upload valid audio.
8. Try invalid audio type → friendly localized error.
9. Publish Full Learn.
10. Open reader.
11. Open Learn path from More sheet or CTA if present.
12. Verify vocab/grammar/quiz/listening render from snapshot.

## Part H — Reader smoke

1. Mono feed loads remote content.
2. Reader opens from feed.
3. Sentence order correct.
4. Translation/furigana visible.
5. Footer meta balanced.
6. Follow button works and Following color matches status chip.
7. React works.
8. More sheet opens.
9. Save/Unsave works.
10. Share uses LAN public base URL, not localhost.
11. Cover image loads on phone.
12. Audio, if present, loads on phone.
13. Back/close behavior works.

## Part I — Profile/social smoke

1. Own profile loads.
2. Edit profile display name/handle/bio.
3. Invalid handle → localized field error.
4. Upload avatar.
5. Upload cover.
6. Public profile opens.
7. Follow/unfollow from public profile.
8. Followers/following list opens.
9. Saved list works.
10. Collections create/rename/delete.
11. Add mono to collection.
12. Collection public/private behavior if applicable.

## Part J — Validation/localization smoke

**Languages:** English, Myanmar, Japanese.

For each:

1. Invalid register email.
2. Wrong login password.
3. Invalid profile handle.
4. Invalid collection name.
5. Empty publish title.
6. Full learn missing vocab meaning.
7. Guest react prompt.
8. Offline snackbar.
9. Invalid media upload.

**Verify:**

- No English mirror in Myanmar/Japanese for high-priority strings (per product bar).
- No overflow on small phone.
- No raw `messageKey` shown.
- Unknown key fallback never crashes.

## Part K — Offline/connectivity smoke

1. Authenticated online actions work.
2. Turn airplane mode on.
3. React → offline snackbar only.
4. Follow → offline snackbar only.
5. Save → offline snackbar only.
6. Publish → offline snackbar before validation/network.
7. Upload → offline snackbar.
8. Turn network back on.
9. Actions recover without app restart.

## Part L — Release blocker criteria (summary)

Block **release** if: cannot launch; backend cannot build; Flutter tests fail; publish/auth broken; profile/reader crash; media cannot load on phone; raw `validation_failed` JSON; raw stack strings to user; guest mutates protected data; l10n runtime crash; share URL is localhost on device.

## Part M — Fix small blockers only

If issues are found during M14:

- Small focused patches only.
- Add or extend tests per fix.
- Document each fix in `docs/M14_V1_RELEASE_QA_HARDENING_REPORT.md` under **Fixes Applied**.

## Part N — Final report

See `docs/M14_V1_RELEASE_QA_HARDENING_REPORT.md` after running commands and (where possible) device smoke.

## Part O — Output summary

The M14 report concludes with yes/no (or **N/A – operator**) for: plan created; backend tests/build; Flutter gen-l10n/format/analyze/test; phone smoke; auth/guest; creator read-only; full learn; reader/social; media; validation/l10n; offline; blockers fixed; release readiness.
