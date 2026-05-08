# M4b3d Listening Hydration Report

**Report date:** 2026-05-03  
**Scope:** Hydrate **`ListeningPronunciationScreen`** from **`LearnPublishedSnapshot.storyAudio`** with catalog **`publishKind`** gating. Vocab, Grammar, and Quiz unchanged.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/learn/listening_pronunciation_screen.dart` | **`ListeningPronunciationScreen`** is now a **`ConsumerWidget`**; watches **`catalogPublishedMonoDetailProvider`** + **`learnPublishedSnapshotProvider`**; added **`publishedStoryAudioHttpUrl`**; **`_ListeningPlaybackView`** (Stateful) holds **`AudioPlayer`** and transcript UI; loading/error/retry/locked/unavailable bodies; demo path via **`learnDemoMocksAllowed`**. |
| `test/features/learn/listening_hydration_widget_test.dart` | **New.** Read-only, HTTPS catalog audio, local-only audio, demo **`mono`** transcript. |
| `test/features/learn/listening_story_audio_url_test.dart` | **New.** Unit tests for **`publishedStoryAudioHttpUrl`**. |

---

## Listening Screen Behavior

- **Route params:** Same as before: **`contentId`**, optional **`storyTitle`**, **`audioUrl`**, **`lines`**, **`explanationLanguageOverride`** from **`main.dart`** / **`extra`**.
- **Demo (`learnDemoMocksAllowed`):** Uses **`ListeningSampleData.defaultAudioUrl`** when **`audioUrl`** is empty; **`ListeningSampleData.mockLines`** when **`lines`** is null — **debug-only** non-UUID ids (see gate).
- **Catalog UUID:** Watches providers; **`shouldUsePublishedLearnSnapshot(detail.publishKind, snap)`** gates learn.
  - **Loading / error:** Spinner or **`_ListeningErrorBody`** + **Retry** (invalidates **`catalogPublishedMonoDetailProvider`**).
  - **Read-only / unusable snapshot:** Locked copy (read-only vs full learn), **no** sample audio or transcript.
  - **Full learn but no HTTP(S) `sourceUrl`:** Full-screen **`_ListeningAudioUnavailableBody`** (“Audio is not available for this story yet.” + short policy note).
  - **Full learn + valid HTTP(S) URL:** **`_ListeningPlaybackView`** loads that URL via **`just_audio`**; app bar subtitle prefers route **`storyTitle`**, then **`StoryAudioDto.displayName`**, optional **`durationSeconds`** suffix (`m:ss`).
  - **Transcript:** **`lines ?? []`** — no published transcript model in **`StoryAudioDto`**; empty list shows **“No transcript is published for this story yet.”** above the player (audio-only layout).

---

## Audio URL Policy

- **`publishedStoryAudioHttpUrl(StoryAudioDto?)`** returns **`sourceUrl`** trimmed only when it starts with **`http://`** or **`https://`** (case-insensitive).
- **`file://`**, **`ftp://`**, empty, or missing **`sourceUrl`** → **null** (no player load). **`localPath`** / **`localFileName`** alone do **not** enable playback on catalog builds.

---

## Transcript Policy

- Published snapshot has **no** transcript lines in V1 **`StoryAudioDto`**.
- Catalog UUID: **never** inject **`ListeningSampleData.mockLines`**; only explicit **`lines`** from route **`extra`** (if ever passed) or empty + honest message.
- Broader timed transcript / alignment remains **deferred**.

---

## Mock Fallback Policy

| Condition | Audio | Transcript |
|-----------|-------|--------------|
| **`learnDemoMocksAllowed(contentId)`** (debug + non-UUID / `mono` / empty) | Sample default URL unless **`audioUrl`** set | **`mockLines`** unless **`lines`** set |
| Catalog UUID + full learn + valid HTTP(S) **`sourceUrl`** | Published URL | Route **`lines`** or empty + message |
| Catalog UUID otherwise | No sample URL | No mock lines |

Release builds never use sample data for UUID-shaped mono ids.

---

## Tests Added

| File | Notes |
|------|--------|
| `test/features/learn/listening_story_audio_url_test.dart` | **`publishedStoryAudioHttpUrl`** accepts http/https, rejects file/ftp/empty, ignores local-only. |
| `test/features/learn/listening_hydration_widget_test.dart` | Widget tests avoid **`pumpAndSettle`** where **`just_audio`** would hang; use **`pump`** + short duration for HTTPS / demo cases. |

---

## Flutter Analyze Result

```bash
flutter analyze lib/features/learn/listening_pronunciation_screen.dart test/features/learn/listening_hydration_widget_test.dart test/features/learn/listening_story_audio_url_test.dart
```

**Result:** No issues found.

---

## Flutter Test Result

```bash
flutter test test/features/learn
flutter test
```

**Results (2026-05-03 run):** `test/features/learn` — **29** passed; full `flutter test` — **185** passed.

---

## Remaining Risks

- **Route `extra.audioUrl` for catalog UUID** is not merged when published **`sourceUrl`** is missing; **`LearnHubScreen`** currently passes title + language only — low risk until previews pass URLs.
- **Playback failures** (403, TLS, bad file) still surface as the generic card error string after load attempt.
- **Widget tests** intentionally avoid full **`pumpAndSettle`** on screens that start network audio.

---

## Recommended Next Step

**M4b3e (optional):** Learn hub / mono entry polish — surface “no audio yet” on the tile when snapshot has no HTTP(S) audio, coordinated **pull-to-refresh** invalidation of **`catalogPublishedMonoDetailProvider`**, or a thin **integration / golden** pass for Learn routes after M4b3a–d.
