# M13C — Protected action & connectivity audit

Short map of each user-facing protected action, current behavior, target behavior, and wiring plan (M13C implementation).

| # | Action | Location(s) | Guest today | Offline today | Desired / M13C | Safe wiring |
|---|--------|-------------|-------------|---------------|----------------|-------------|
| 1 | **React** | `lib/features/mono/mono_screen.dart` — `_toggleReact` | `checkProtectedActionFromRef` + `showProtectedActionPrompt` (M13A) | Not checked (network default online) | Same flow via `ensureProtectedActionAllowed`; offline → central `network.offline` snack | Replace inline check with `ensureProtectedActionAllowed` |
| 2 | **Follow** | `mono_screen.dart` — `_FooterFollowButton._toggleFollow`; `public_profile_screen.dart` — `_toggleFollow` | Snack + `NimonAppStrings.signInToFollowCreators` | Generic error on failure | Login → `showProtectedActionPrompt` with `protected.follow.login`; offline → network snack; catch → `offlineUserMessageIfRecognized` | Call guard at start; map network errors in `catch` |
| 3 | **Save / bookmark** | `mono_screen.dart` — `_toggleBookmark` | Snack + `SavedLibraryCopy` (→ sign-in to save) | Raw / repository error | `ensureProtectedActionAllowed` + `save` + catch mapping | Guard before mutation |
| 4 | **Create story** | `story_creator_add_tab_screen.dart` — `_createNewStory`; `create_screen.dart` — `_handleCreate` | Local draft / guest path varies | N/A for pre-open | Guest → `protected.createStory.login` before new story or first create submit | `ensureProtectedActionAllowed` at `_createNewStory` and `_handleCreate` |
| 5 | **Publish story** | `creator_drawer_publish.dart` — `performCreatorDrawerPublish` | Would fail at API | Fails at save | **Order:** protect → M13B preflight → remote | `ensureProtectedActionAllowed(publishStory)` before `_preflightCreatorPublish` |
| 6 | **Create collection** | `add_to_collection_sheet.dart` — `showAddToCollectionSheet` (callers: `profile_screen.dart`) | Create path hits API | Error text | Guard at sheet open: `createCollection` | Await `ensureProtectedActionAllowed` before `showModalBottomSheet` |
| 7 | **Upload media** | `create_screen.dart` — cover; `story_creator_audio_editor_screen.dart` — `_showUpsertSheet`; `edit_profile_screen.dart` — `changeAvatar` / `changeCover` | Token / inline snack | `MediaUploadException` / generic | `uploadMedia` **before** picker or sheet; profile uploads also use `uploadMedia` | Guard at start of each entry point |
| 8 | **Edit profile** | `lib/features/profile/edit_profile_screen.dart` | Route reachable | Load errors as strings | If guest opens `/profile/edit`, pop after `ensureProtectedActionAllowed(editProfile)` | `addPostFrameCallback` before `load()` |

**Exceptions (documented):** continuing a **local** draft from the Add tab without signing in remains allowed (no new “permanent” create). Collection **add to existing** (not create) still requires auth for API; opening the sheet is gated for any flow that can create a collection.

**Connectivity:** `connectivity_plus` is **not** in `pubspec.yaml`. M13C uses `nimonNetworkOnlinePod` (StateProvider, default `true`) + API-layer offline recognition via `lib/core/networking/network_error_mapping.dart` (no new dependency).
