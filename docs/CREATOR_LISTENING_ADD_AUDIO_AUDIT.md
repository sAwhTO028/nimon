# Creator Listening Add Audio Audit

**Report date:** 2026-05-03  
**Type:** Debug / audit only — **no** code, migration, test, or refactor changes in this task.

**Context:** Reader **M4b3d** can play **`storyAudio.sourceUrl`** when it is **http/https**. Creator “Listening / Audio” is a separate surface; this audit traces whether **add → persist → remote → publish** preserves usable audio.

**References:** [M4_FULL_LEARN_CLOSEOUT_REPORT.md](M4_FULL_LEARN_CLOSEOUT_REPORT.md), [M4B3D_LISTENING_HYDRATION_REPORT.md](M4B3D_LISTENING_HYDRATION_REPORT.md), [M4A_LEARN_LAYER_WIRE_FIX_REPORT.md](M4A_LEARN_LAYER_WIRE_FIX_REPORT.md).

---

## 1. Issue Summary

Reported: **in creator listening, user cannot add audio** (or addition does not “stick” / full learn still has no playable reader audio).

Findings:

- **Add Audio UI is implemented** (file picker + bottom sheet + notifier methods).
- **Local-first attach** writes a **`StoryAudioAsset`** with **local file metadata** and a **non-HTTP `sourceUrl`** placeholder (`local://…` or device path) via **`setStoryAudioFromPickedFile`**.
- **Remote save** intentionally sends **`StoryDraftMapper.fromDomainRemoteSafe`**, which **strips local-only audio fields** and **clears non-http(s) `sourceUrl`**.
- After **`PUT /v1/story-drafts/:id`**, **`RemoteStoryDraftRepository.saveDraft`** replaces the in-memory + on-disk draft with **`StoryDraftMapper.toDomain(putDto)`** (server echo). That round-trip typically yields **`storyAudio` that fails `isValidV1`**, so the UI returns to **“no audio attached”** even though the user just picked a file.
- **Backend** can still create a **`draft_audio`** row with **stub JSON** (e.g. id + display metadata) **without** an **https** URL, so **publishFullLearn** can copy a **non-playable** `storyAudio` into **`content.learn`** — aligning with reader “honest unavailable” unless a real URL exists.

So the failure is **not** “no UI”; it is primarily **remote-safe serialization + post-PUT domain replace** without an **upload → https URL** step.

---

## 2. Current UI Entry Point

| Question | Answer |
|----------|--------|
| **Where is “Add Audio”?** | **`StoryCreatorListeningModuleBody`** in **`lib/features/create/story_creator_audio_editor_screen.dart`**. When there is no valid audio, it shows **`FilledButton.icon` — label `Upload audio`**, which calls **`StoryCreatorAudioEditorScreen._showUpsertSheet`**. |
| **Dedicated route screen** | **`StoryCreatorAudioEditorScreen`** — same **`StoryCreatorListeningModuleBody`** with app bar title **“Listening / Audio”** (used when navigating the learn/audio route). |
| **Embedded workspace** | **`CreatorWorkspaceModulePlaceholder`** routes **`CreatorWorkspaceStep.listeningPronunciation`** to **`StoryCreatorListeningModuleBody`** (**`lib/features/create/creator_workspace_module_placeholder.dart`**). Host: **`StoryCreatorSentencesScreen`** with **`?panel=listening`**. |
| **Disabled / hidden / no-op?** | **Not disabled by default.** The primary CTA is **`Upload audio`**. **Learn mode** must allow the user to stay on the listening panel; turning **Learn mode off** while on a learn panel triggers navigation back to storytelling (**`creator_learn_mode_sync.dart`**) — can feel like “listening disappeared” but is separate from the save bug. |

---

## 3. Current Audio Data Model

| Question | Answer |
|----------|--------|
| **Domain** | **`StoryAudioAsset`** in **`lib/features/create/story_v1_model.dart`**: `id`, `sourceUrl`, `localFileName`, `localPath`, `localSizeBytes`, `localExtension`, `displayName`, `durationSeconds`, `provenance`. |
| **`isValidV1`** | True if **any** of: non-empty **`sourceUrl`**, non-empty **`localFileName`**, non-empty **`localPath`**. |
| **`hasUploadedSourceUrl`** | True only if **`sourceUrl`** starts with **`http://`** or **`https://`**. |
| **Wire DTO** | **`StoryAudioDto`** in **`lib/features/create/data/dto/story_draft_dto.dart`**; JSON via **`storyAudioDtoToWireJson` / `storyAudioDtoFromWireJson`** (**`remote_story_draft_learn_layers_wire.dart`** — M4a). |

**Picker flow:** **`setStoryAudioFromPickedFile`** (**`story_creator_provider.dart`**) sets **`sourceUrl`** to **`local://<file>`** or the **trimmed `pickedPath`**, plus extension gate **`mp3|m4a|wav`**.

**URL flow:** **`setStoryAudio`** (same notifier) sets **`sourceUrl`** to a trimmed URL (intended for real **http(s)** later).

---

## 4. Local Save Flow

| Question | Answer |
|----------|--------|
| **Notifier methods** | **`setStoryAudioFromPickedFile`**, **`setStoryAudio`**, **`clearStoryAudio`** on **`StoryCreatorDraftNotifier`** (**`story_creator_provider.dart`**). Each updates **`state.draft.copyWith(audio: …)`**, **`syncModuleWorkflowWithContent`**, **`_setDraft`**, then **`unawaited(persistLocalNow(…))`**. |
| **Local storage** | **`StoryCreatorDraftStorage`** serializes **`audio.storyAudio`** under the learn/audio JSON shape (**`story_creator_draft_storage.dart`** — fields include **`sourceUrl`**, **`localFileName`**, **`localPath`**, etc.). **Yes**, local serialize includes audio. |
| **Wire (local file path)** | **`StoryDraftMapper.fromDomain`** with **`stripLocalAudioFields: false`** would include local fields; **remote path uses `fromDomainRemoteSafe`** (see §5). |

---

## 5. Remote Save Flow

| Question | Answer |
|----------|--------|
| **Does PUT include `audio`?** | **Yes.** **`RemoteStoryDraftRepository.saveDraft`** builds **`StoryDraftMapper.fromDomainRemoteSafe(persisted)`**, then **`_dtoToJsonMap(dto)`** which sets **`audio.storyAudio`** from **`storyAudioDtoToWireJson`** when non-null (**`remote_story_draft_repository.dart`**). |
| **`fromDomainRemoteSafe`** | **`StoryDraftMapper.fromDomain(..., stripLocalAudioFields: true)`** (**`story_draft_mapper.dart`**). **`_audioToDto(..., stripLocal: true)`** sets **`localFileName` / `localPath` / …` to `null`** and **`sourceUrl`** to **`_remoteSourceUrl(sourceUrl)`** — **only http(s)** preserved; **`local://…` and file paths become `null`**. |
| **After PUT** | On success (non-publish path), **`final domain = StoryDraftMapper.toDomain(putDto); return await _local.saveDraft(domain);`** — **local draft is overwritten by server response**, not merged with the pre-PUT rich local audio. |

**Conclusion:** Remote save **is wired**, but it **strips** the data the creator UI relies on for “attached file” state, then **rehydrates** from the server payload that **no longer satisfies `isValidV1`** in typical local-pick scenarios.

---

## 6. Backend Storage Flow

| Question | Answer |
|----------|--------|
| **`updateDraft`** | **`nimon-backend/src/modules/story-drafts/story-drafts.service.ts`**: reads **`body.audio?.storyAudio`**. Inside a transaction: **`draftAudio.deleteMany`**, then **`if (storyAudio) { draftAudio.create({ kind: 'storyAudio', content: storyAudio }) }`**. |
| **`kind === 'storyAudio'`** | **Yes** — Prisma model **`draft_audio`** defaults **`kind`** to **`storyAudio`** (**`nimon-backend/prisma/schema.prisma`**). |
| **What gets stored** | Whatever JSON the client sends after **remote-safe** mapping — often **id + display fields** without **https `sourceUrl`** and **without** local path (because stripped client-side before PUT). |

---

## 7. Publish Full Learn Flow

| Question | Answer |
|----------|--------|
| **Does `publishFullLearn` copy audio?** | **Yes.** **`buildLearnSnapshotFromDraft`** selects **`draft.audios.find(kind === 'storyAudio')`** and shallow-copies **`content` into `learn.audio.storyAudio`** (or **`null`** if no row) — **`story-drafts.service.ts`** (see M4b1 report / service tests with **`sourceUrl: 'https://cdn/x.mp3'`**). |
| **`content.learn.audio.storyAudio` after publish** | **Present** if a **`draft_audio`** row existed at publish time; **playable in reader** only if **`sourceUrl`** is **http(s)** per **M4b3d** policy. |

---

## 8. Root Cause

**Primary (most likely user-visible “add audio doesn’t work”):**

- **Classification:** **`save method` / wire policy interaction** — not missing UI.
- **Mechanism:** **`fromDomainRemoteSafe`** + **`_remoteSourceUrl`** drops **local-only** audio identity from the PUT body; **`saveDraft`** then **`toDomain(putDto)`** **overwrites** local state with that **stripped** payload → **`storyAudio?.isValidV1 != true`** → UI shows **no audio** again.

**Secondary factors (environment-specific):**

- **File picker:** **`file_picker`** + **`FileType.custom`**; **`withData: kIsWeb`** on web — failures here would block picking (classify **file picker / platform**).
- **Reader vs creator:** **M4b3d** blocks **non-http(s)** URLs — even if local state survived, **published** listening would still show **unavailable** until a **real https** URL exists (classify **local path blocked** for *reader*, **upload pipeline missing** for *system*).

**Not the main issue:** “UI not implemented” — **false**; “Backend mapping missing” for **`draft_audio`** — **false** for PUT; **validation** blocking attach — **unlikely** for a successful pick (extension gate is narrow but explicit).

---

## 9. Recommended V1 Fix

**Pick minimal V1: (A) URL-only audio input first**, aligned with reader hydration.

| Option | Pros | Cons |
|--------|------|------|
| **A) URL-only first** | Matches **M4b3d**; small UI add (field + `setStoryAudio`); remote-safe payload keeps **`https` `sourceUrl`**; survives **`toDomain(putDto)`**. | Creators must host audio elsewhere until upload exists. |
| **B) Local picker + later upload** | Best UX long-term. | Requires **upload API**, blob store, then patch **`sourceUrl`** — larger scope. |
| **C) Disable with copy** | Honest until B exists. | Blocks creator value. |

**Additional fix (small, high leverage):** After PUT, **merge** server **`storyAudio`** with **local `StoryAudioAsset`** when server lacks **http(s)** but local still has **picker metadata** — *or* stop replacing domain from **`putDto`** for audio-only downgrades (careful with conflict rules). Either is a **product decision** vs strict server-authoritative sync.

---

## 10. Tests Needed

- **Unit:** `StoryDraftMapper.fromDomainRemoteSafe` + **`toDomain`** round-trip for **picked file** asset → expect **loss** today (documents bug); after fix, expect **preservation or URL**.
- **Integration / fake HTTP:** `RemoteStoryDraftRepository.saveDraft` with mock client — assert PUT JSON **`audio.storyAudio`** for **https** vs **local pick**.
- **Widget (optional):** Tap **Upload audio** → pick (mock **`FilePicker`**) → assert **`hasAudio`**; then simulate **post-PUT domain replace** and assert regression if unfixed.

---

## 11. Exact Cursor Prompt For Fix

Use this as a single task prompt for a follow-up coding session:

> **Fix creator story audio disappearing after remote save.**  
> Today: `setStoryAudioFromPickedFile` stores `StoryAudioAsset` with local metadata + non-http `sourceUrl` (`local://` or path). `RemoteStoryDraftRepository.saveDraft` uses `StoryDraftMapper.fromDomainRemoteSafe`, strips local fields and non-http URLs, PUTs `/v1/story-drafts/:id`, then replaces local state via `StoryDraftMapper.toDomain(putDto)`, so `storyAudio?.isValidV1` becomes false and the Listening UI shows empty.  
> **Implement minimal V1 (choose one path, prefer A):**  
> (A) Add **https/http URL** field to `StoryCreatorListeningModuleBody` / upsert sheet, call existing `setStoryAudio`, validate URL, keep file picker optional or secondary; ensure remote-safe DTO still has http(s) `sourceUrl` after PUT.  
> **OR** (B small) After successful PUT, **merge** server `storyAudio` with prior local asset when server lacks http(s) URL but local has `localFileName` / picker path (document conflict policy).  
> Add tests from `CREATOR_LISTENING_ADD_AUDIO_AUDIT.md` §10. Do not change M4b3d reader policy. No migrations.

---

## Output Summary

| Question | Answer |
|----------|--------|
| **Add audio UI exists?** | **Yes** — `Upload audio` / sheet in **`story_creator_audio_editor_screen.dart`** (+ embedded **`CreatorWorkspaceModulePlaceholder`**). |
| **Expected audio input type?** | **V1:** **`file_picker`** for **mp3/m4a/wav**; optional duration + display name. **`setStoryAudio`** exists for **URL** but is **not** the primary sheet flow today. |
| **Local save wired?** | **Yes** — notifier + **`StoryCreatorDraftStorage`** JSON. |
| **Remote save wired?** | **Yes** — PUT includes **`audio.storyAudio`** using **remote-safe** mapper. |
| **Backend stores `draft_audio`?** | **Yes** when **`storyAudio`** JSON is truthy — **`kind: 'storyAudio'`**. |
| **Publish copies `storyAudio`?** | **Yes** when row exists — shallow copy into **`content.learn.audio.storyAudio`**. |
| **Most likely root cause** | **Remote strip + post-PUT `toDomain(putDto)` overwrite** removes picker-only audio from the draft the UI reads. |
| **Recommended fix** | **(A) URL-only (https) input first**, optionally later **(B) upload**; or explicit **merge** policy if product wants local metadata to survive until upload. |
