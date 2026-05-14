# M13H Validation Localization Audit

Mapping of validation-related UX to message sources before full AppLocalizations wiring.

| Area | Current message source | messageKey examples | Needs localization? | Notes |
|------|------------------------|---------------------|---------------------|-------|
| Auth register/login | English fallback map + field validators | `auth.email.required`, `auth.password.length`, `auth.login.failed` | Yes | Now resolved via `validationMessageKeyLocalized` / `validationIssueDisplayMessageLocalized` in login/register screens using `ValidationIssue` where applicable. |
| Edit profile | Fallback + `profile_validators` | `profile.displayName.*`, `profile.handle.*`, `profile.bio.*` | Yes | `EditProfileState.profileFieldErrors` now holds `ValidationIssue`; snackbars use localized resolver; upload errors use `mediaUploadUserMessageLocalized`. |
| Collections | Fallback + collection validators | `collection.title.*`, `collection.name.*` | Yes | Add/rename flows pass issues through localized resolver in sheet + profile screen rename. |
| Story basics | Fallback + story validators | `story.title.*`, `story.description.*` | Yes | `CreateStoryBasicsForm` displays localized messages from stored issues. |
| Publish validation sheet | Fallback + hardcoded section titles | `story.*`, `learn.*`, sheet titles | Yes | Sheet chrome uses ARB (`validationPublish*`); tiles use `validationFieldLabelLocalized` + issue resolver. |
| Protected action prompts | Fallback keys | `protected.*.login`, `protected.generic.*` | Yes | `showProtectedActionPrompt` uses resolver for body; CTAs from ARB (`validationCta*`); offline snack uses `network.offline`. |
| Offline/network copy | `network.offline` fallback | `network.offline` | Yes | Snackbar + media localized wrapper map offline recognition to same key. |
| Media upload errors | Fallback + mapper | `media.file.*`, `media.image.*`, `media.audio.*` | Yes | `mediaUploadUserMessageLocalized` for UI; `mediaUploadUserMessage` retained for non-UI/tests. |
| Generic validation fallback | `validation_fallback_messages.dart` | All keys in map | Safety net | English map preserved; unknown keys → `"Please check this field."` |
