# Nimon Add flow — UI-level manual verification (Remote + Strict)

Date: 2026-04-21

This document is **honest about what was actually verified**. I do not have interactive access to click through your running app UI, so I verified **launch + runtime readiness** and documented the exact manual steps you should run to complete the UI pass.

---

## A. Run configuration used

### Backend (local)

- Postgres/Redis:

```bash
cd nimon-backend
docker compose up -d
```

- API:

```bash
cd nimon-backend
pnpm run start
```

Expected API base URL: `http://localhost:3000`

### Flutter (remote + strict mode)

Windows desktop launch could **not** be executed on this machine due to missing Visual Studio toolchain (see §C).

Web launch (Chrome) was executed with:

```bash
flutter run -d chrome \
  --dart-define=NIMON_USE_REMOTE_DRAFTS=true \
  --dart-define=NIMON_STRICT_REMOTE_DRAFTS=true \
  --dart-define=NIMON_API_BASE_URL=http://localhost:3000
```

---

## B. What worked (from the actual runtime)

### 1) App launched in strict remote mode (web)

- `flutter run -d chrome` started successfully and the Dart VM service attached.
- This confirms the app can compile and launch with:
  - `NIMON_USE_REMOTE_DRAFTS=true`
  - `NIMON_STRICT_REMOTE_DRAFTS=true`
  - `NIMON_API_BASE_URL=...`

---

## C. What failed (from the actual runtime)

### 1) Windows desktop UI run could not be executed (toolchain)

Attempt:

```bash
flutter run -d windows ...
```

Result:
- `Error: Unable to find suitable Visual Studio toolchain.`
- `flutter doctor -v` reports **Visual Studio not installed** (Windows desktop builds require the "Desktop development with C++" workload).

This is **environment/toolchain**, not an app bug.

---

## D. Did strict mode expose failures honestly?

At the **repository level**, strict mode is implemented to throw on remote failures instead of silently returning local fallback “success”.

However, this UI-level pass did **not** execute in-app interactions (tapping Save/Publish) because interactive UI control isn’t available here.

Manual check to run on your side (required):
- Start app in strict mode.
- Break backend (stop API or set wrong `NIMON_API_BASE_URL`).
- Perform an action that triggers remote persistence (e.g. save basics or publish).
- Confirm the UI shows a failure (snackbar/error) and does **not** behave like it succeeded.

---

## E. Remaining UX / technical problems observed

- **Windows desktop toolchain missing** blocks running the app on the Windows device target in this environment.
- UI-level strict-mode error surfacing still needs a human click-through check to confirm the notifier/UI surfaces thrown exceptions clearly.

---

## F. Final verdict: Add flow UI usable in remote strict mode?

**INCONCLUSIVE** from this pass (no interactive UI verification performed here).

What is confirmed:
- app **builds/launches** in strict remote mode (web)
- repository-level strict behavior exists and is designed to fail loudly

What is not confirmed:
- the **actual Add flow UI** click-through (Basics → Storytelling → Modules → Processing → Publish → Resume)

---

## G. Recommended next engineering step

1) Fix local environment so UI runs on your target:
   - Install Visual Studio + C++ desktop workload (for Windows desktop), or use Android emulator/device.

2) Run the manual UI checklist below (copy/paste into your dev notes).

---

## Manual UI checklist (what you should verify)

Run app with:
- `NIMON_USE_REMOTE_DRAFTS=true`
- `NIMON_STRICT_REMOTE_DRAFTS=true`
- `NIMON_API_BASE_URL=...`

Then verify:
1. Add tab opens without crash
2. Create new story → Basics screen opens
3. Enter basics → save/continue works
4. Story sentences edit → autosave works
5. Learn modules edits → saves work
6. Processing list shows draft → Continue works
7. Read-only publish succeeds when ready
8. Full-learn publish succeeds when modules are completed
9. Stop backend / break URL → any save/publish fails clearly (no silent “success”)

