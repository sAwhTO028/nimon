# M13F Backend Validation Response Audit

This document classifies how write and validation-sensitive paths respond when user input is invalid, and whether the response should be the standard `{ message: 'validation_failed', issues: ValidationIssue[] }` envelope (HTTP 400) versus other error types.

**Conventions**

- **validation_failed**: field- or rule-oriented user input that clients can map to inline errors or sheets.
- **Not** used for: authz, business state, not found, rate limits, server errors, or sensitive auth signals.

| Module | Endpoint / Service method | Mutation type | Current invalid-input behavior | Should become validation_failed? | Reason | Flutter mapping needed? | Status |
|--------|---------------------------|---------------|--------------------------------|----------------------------------|--------|-------------------------|--------|
| **common/validation** | N/A (helpers) | N/A | `assertNoBlockingValidationIssues` / `throwValidationFailed` | Yes (output shape) | Central `BadRequestException` constructor | N/A | **Done** — `validation-exception.ts` |
| **auth** | `POST /v1/auth/register` — `AuthService.register` | Create session | `validation_failed` for `validateRegisterPayload` | Yes (already) | Structural email/password rules | **M13E** — `HttpValidationFailedException` | **Verified** + helper refactored |
| **auth** | `POST /v1/auth/login` — `AuthService.login` | Create session | `validation_failed` for `validateLoginPayload`; `401` generic for bad credentials | Partial | Format errors: `validation_failed`. Wrong password: stay generic. | Register/login forms | **Unchanged** security |
| **auth** | `PATCH /v1/me/profile` — `AuthService.patchMeProfile` | Update profile | `validation_failed` for profile validators; `409` for handle unique | Yes (validation path) | Field-level profile rules; conflict stays `409` | **M13E** — rethrow `HttpValidationFailedException` in repo | **Done** + repo fix so VF not swallowed |
| **creator-collections** | `POST/PATCH` — `CreatorCollectionsService.create` / `updateMine` | Create / update | `validation_failed` for `validateCollectionName` | Yes | Name/title rules | `collection.title` (Flutter also aliases `collection.name`) | **Done** + helper |
| **story-drafts** | `POST` create — `StoryDraftsService.createDraft` | Create | **Now** `validation_failed` for dangerous title/description in draft | Yes (when provided) | Draft: unsafe markup / line breaks only (lenient) | `StoryDraftValidationFailedException` on 400 (PUT path) | **Done** |
| **story-drafts** | `PUT` — `StoryDraftsService.updateDraft` | Update | **Now** `validation_failed` for dangerous title/description | Yes | Same as create | Remote draft repo `_throwIfNotOk` | **Done** |
| **story-drafts** | `publishReadOnly` / `publishFullLearn` | Publish | `assertNoBlockingValidationIssues` (was inline `BadRequestException`) | Yes | M13B publish gate | M13B publish sheet | **Refactored** to helper (same shape) |
| **story-drafts** | `GET` list / `updatedAfter` query | Read | `apiError` 400 for bad ISO timestamp | **No** | Query contract, not form fields | N/A | **Intentionally not changed** |
| **published-monos** | (reviewed) | — | No ad-hoc string `BadRequestException` for form validation in scope | — | — | — | **N/A** |
| **mono-feed** | `GET` feed / filter / cursor | Read | `BadRequestException` string codes | **No** | Invalid cursors, filter combos, locale codes | N/A | **Documented** |
| **mono-social** | `GET` lists (reactions, etc.) | Read | `invalid_cursor` | **No** | Pagination | N/A | **Documented** |
| **user-follow** | `POST` follow | Action | `cannot_follow_self` 400 | **No** | Business rule | N/A | **Documented** |
| **media** | upload / storage | Write | *(Superseded by **M13G**)* — see `docs/M13G_MEDIA_UPLOAD_VALIDATION_AUDIT.md` | — | — | — | **See M13G** |
| **users / profile** | (no extra controllers beyond auth `me`) | — | — | — | — | — | **N/A** |

## Field ID alignment (summary)

- **Auth**: `email`, `password` — backend `auth-validation` / `RegisterDto` alignment unchanged.
- **Profile**: `displayName`, `handle`, `bio` — unchanged.
- **Collections**: backend issues use `collection.title`; Flutter forms map `collection.title` and `collection.name` to the same inline errors.
- **Story draft / publish**: `story.title`, `story.description` — unchanged.

## Media (audit only)

- `media.validation.ts` and storage classes use short string errors for missing multipart `file`, storage path, and extension rules. Converting to `validation_failed` was **out of scope** unless a dedicated upload field-error UX is added; keep **415** for unsupported media type if already relied on by clients.

## Mono social (document only)

- React / bookmark / follow failure modes remain **401 / 403 / 404** and business `BadRequestException` where they express state (e.g. cannot self-bookmark), not `validation_failed`.
