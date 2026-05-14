# M17F — Flutter free quota alerts (implementation report)

## Summary

Flutter now parses Nest **`quota_exceeded`** HTTP bodies (`code`, `key`, `limit`, `current`), maps them to typed **`AppQuotaExceededException`**, and shows a localized **`showQuotaExceededDialog`** for the five M17D/M17E keys. **`validation_failed`** handling is unchanged (parsed first in collection/draft error paths only where both could apply; story draft path checks quota before 400 validation).

## Parser and model

| Item | Location |
|------|----------|
| Exception type | `lib/core/validation/app_quota_exceeded_exception.dart` |
| JSON parsing | `lib/core/validation/quota_exceeded_from_json.dart` — `tryParseQuotaExceededFromHttpBody` |
| Barrel export | `lib/core/validation/validation.dart` exports `quota_exceeded_from_json.dart` and `app_quota_exceeded_exception.dart` |

Supported shapes:

- Root `{ "code": "quota_exceeded", "key", "limit", "current" }`
- Nested `{ "error": { ... } }`
- Defensive `{ "message": { ... } }`

## Localization

ARB keys added (English template + Japanese + Myanmar):

- `quotaDialogOk`, `quotaPremiumComingLaterCta`, `quotaUnknownLimitTitle`, `quotaUnknownLimitMessage`
- Per-key pairs: `publishedMonoLimitReachedTitle/Message`, `savedMonoLimitReachedTitle/Message`, `collectionLimitReachedTitle/Message`, `collectionItemLimitReachedTitle/Message`, `draftStoryLimitReachedTitle/Message`

Messages interpolate **`{limit}`** where product copy requires it.

Regenerated: `flutter gen-l10n`.

## UI helper

| Item | Location |
|------|----------|
| Copy resolution + dialog | `lib/ui/quota_exceeded_dialog.dart` — `resolveQuotaExceededStrings`, `showQuotaExceededDialog` |

- Primary: **OK** (`quotaDialogOk`).
- Optional secondary **Premium later** (`quotaPremiumComingLaterCta`) only for **`published_mono_limit_reached`** and **`collection_limit_reached`** (dismiss-only; no subscription navigation).
- Unknown `key`: generic fallback title/message.
- Uses **`context.mounted`** inside dialog entry where applicable; callers should guard async gaps.

## HTTP integration points

Quota is parsed **before** falling through to generic errors:

| Repository | Method |
|------------|--------|
| `RemoteStoryDraftRepository` | `_throwIfNotOk` — quota before 400 validation |
| `RemoteMonoSocialRepository` | `_throwIfNotOk` |
| `RemoteCreatorCollectionsRepository` | `_throwMapped` — quota before validation |

## Screen / action wiring

| Action | Behavior |
|--------|----------|
| **Publish Read Only / Full Learn** | `creator_drawer_publish.dart` catches `AppQuotaExceededException`, shows dialog; notifier rolls back publish state on quota (`story_creator_provider.dart`). |
| **Save / bookmark Mono** | `mono_screen.dart` `_toggleBookmark`: restores prior bookmark state, shows quota dialog. |
| **Create collection / bulk add** | `add_to_collection_sheet.dart`: quota dialog; sheet stays open (no success pop on quota). |
| **New draft from Create basics** | `create_screen.dart`: `applyBasicsAndWaitPersist` awaits persist; on quota shows dialog and **does not** navigate to sentences. |

New notifier API: **`applyBasicsAndWaitPersist`** (same fields as `applyBasics`, awaits `persistLocalNow`).

**`persistLocalNow`** rethrows **`AppQuotaExceededException`** after marking save failed (same pattern as validation).

## Tests added

| File | Coverage |
|------|----------|
| `test/core/validation/quota_exceeded_from_json_test.dart` | Root, nested `error`, nested `message`, validation_failed untouched, unknown key parses |
| `test/core/validation/quota_exceeded_copy_test.dart` | All five keys + fallback + premium-secondary flags |
| `test/features/create/story_creator_quota_publish_and_draft_test.dart` | Publish rollback on quota; draft quota from `applyBasicsAndWaitPersist` |
| `test/features/create/quota_exceeded_publish_dialog_test.dart` | Widget: published copy + Premium later |
| `test/features/create/quota_exceeded_draft_dialog_test.dart` | Widget: draft copy |
| `test/features/mono/quota_exceeded_saved_mono_dialog_test.dart` | Widget: saved copy |
| `test/features/profile/quota_exceeded_create_collection_dialog_test.dart` | Widget: collection limit |
| `test/features/collections/quota_exceeded_collection_dialog_test.dart` | Widget: collection item limit |

## Commands run (authoritative run log)

From repo root (`nimon/`):

```bash
dart format <touched Dart files>
flutter gen-l10n
flutter analyze lib/features/create/create_screen.dart lib/features/create/data/remote_story_draft_repository.dart
flutter test test/core/validation/quota_exceeded_from_json_test.dart test/core/validation/quota_exceeded_copy_test.dart test/features/create/story_creator_quota_publish_and_draft_test.dart test/features/collections/quota_exceeded_collection_dialog_test.dart
flutter test test/features/create/quota_exceeded_publish_dialog_test.dart test/features/create/quota_exceeded_draft_dialog_test.dart test/features/mono/quota_exceeded_saved_mono_dialog_test.dart test/features/profile/quota_exceeded_create_collection_dialog_test.dart
```

Also run (pre-merge full verification — **all passed** in the author environment):

```bash
flutter test test/core
flutter test test/features/create
flutter test test/features/profile
flutter test test/features/mono
flutter test test/features/collections
flutter test
```

## Remaining M17G smoke checklist (suggested)

1. Signed-in user at **published mono cap**: attempt **first publish** → expect **403** body `published_mono_limit_reached`, dialog shows **Free limit reached**, draft stays editable, no profile “published” success snack/route side effects from publish success path.
2. At **saved mono cap**: toggle **Save** on another user’s mono → dialog **Saved limit reached**, bookmark icon stays **unsaved**.
3. At **collection cap**: **Create new collection** from add-to-collection sheet → **Collection limit reached**, sheet remains usable.
4. At **collection item cap**: bulk add or single add → **Collection is full**, no “Added” success path.
5. At **draft cap**: complete Story basics on **Add** → **Draft limit reached**, **no** navigation to sentences route.

## Constraints

- **Backend**: not modified.
- **Media upload / auth session / public profile layout / owner published pagination**: not touched as part of this change set.
