# Nimon Validation and Limitation Standard

## Goals

- **Single source of truth** for rule definitions (central modules + shared codes/message keys).
- **Reusable validation** — pure functions on backend and mirrored helpers on Flutter for UX.
- **Clear user-facing messages** — stable `messageKey` strings mapped to copy (EN first; l10n later).
- **Backend safety** — authoritative checks on mutations; DB constraints unchanged.
- **Flutter UX consistency** — field-level errors, predictable prompts for guests/offline.
- **Draft vs publish strictness** — lenient drafts; strict publish gates.

## Validation Modes

| Mode | Purpose |
|------|---------|
| **Draft** | Lenient: allow incomplete core fields; warn where helpful; block only dangerous input (HTML/script, obvious abuse). |
| **ReadOnlyPublish** | Story content required for publish; Learn modules optional. |
| **FullLearnPublish** | Story + vocab + grammar + quiz requirements enforced per level/duration bands. |
| **ProfileUpdate** | Display name, handle, bio, URLs — blocking per rules below. |
| **Auth** | Register/login structural validation; generic messages for auth failures. |
| **ProtectedAction** | Guest vs authenticated vs network — UX routing, not field validation. |

## Severity Levels

| Severity | Meaning |
|----------|---------|
| **info** | FYI; does not block save. |
| **warning** | Recommended fix; draft may proceed; publish may still block depending on mode. |
| **blocking** | Cannot proceed with current operation. |

**Rules**

- **Draft** should mostly emit **warnings** (except dangerous input → **blocking**).
- **Publish** modes may emit **blocking** errors.
- **Dangerous input** (HTML/script injection patterns) → **blocking** in every mode.

## Error Result Shape

```text
ValidationIssue {
  code: string;           // stable machine code, e.g. profile.handle.reserved
  field: string;          // logical field path, e.g. handle, story.title
  messageKey: string;     // key for localization / fallback map
  severity: ValidationSeverity;
  params?: Record<string, unknown>; // interpolation (max, min, etc.)
  source?: string;       // optional: validator id
}

ValidationResult {
  ok: boolean;            // true iff no blocking issues (warnings allowed)
  issues: ValidationIssue[];
}
```

### Example codes

- `profile.handle.tooShort`
- `profile.handle.reserved`
- `story.title.required`
- `story.sentences.tooFew`
- `learn.vocab.meaning.required`
- `auth.login.invalidCredentials` (generic client message only)
- `action.loginRequired`
- `network.offline`

## UX Policy

| Situation | UX |
|-----------|-----|
| Invalid field on form | Inline field error from `ValidationIssue` / `messageKey`. |
| Offline / no network | Top snackbar or banner: stable offline copy (no raw Dio/socket text). |
| Guest tries protected action | Bottom sheet or dialog: Sign in / Not now. |
| Publish blocked | Publish checklist or modal listing **blocking** issues; optional **warning** list for polish items. |
| Auth failure | Single generic login message (no email enumeration). |

## Network Limitation Policy

When offline:

- Allow **local reading** when content is cached.
- **Block** remote mutations (follow, react, save, publish, upload).
- Show: **"No internet connection. Please check your network and try again."**
- Never surface raw HTTP/Dio/socket errors to end users.

## Guest Limitation Policy

**Guest may:** browse public Mono feed, read public content, preview app.

**Guest may not:** follow, react/like, save/bookmark, create durable collections, publish, upload media, or create permanent story content without signing in.

**Protected actions** (React, Follow, Save, Create, Publish, …): show **login-required** prompt.

Example messages:

- "Sign in to react to stories."
- "Sign in to follow creators."
- "Sign in to create and publish stories."

CTAs: **Sign in** | **Not now**

## Auth Failure Policy

**Login:** generic only — **"Email or password is incorrect."** Do not reveal whether an email exists.

**Register:** field-level validation on client + server; backend enforces uniqueness and security.

**Rate limiting:** backend responsibility; document if not yet implemented.

## Implementation Notes

- Backend modules live under `src/common/validation/` (pure functions + shared constants).
- Flutter mirrors under `lib/core/validation/` for UX-only checks; **server remains authoritative**.
- Message keys map through a single fallback map until full l10n wiring.
