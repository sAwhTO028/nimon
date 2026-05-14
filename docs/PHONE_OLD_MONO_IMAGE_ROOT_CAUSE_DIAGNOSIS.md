# Phone Old Mono Image Root Cause Diagnosis

## Summary

Old published monos fail to show covers on a **physical phone** because the backend returns **`http://localhost:3000/uploads/...`** for those rows’ stored cover URLs in `published_monos.content.core.coverImageUrl`. On a phone, **`localhost` is the handset**, not the development PC, so Flutter’s `NetworkImage` cannot load the image.

Newly created content from the phone works because uploads were stamped with **`http://192.168.11.5:3000/uploads/...`** (matching `MEDIA_PUBLIC_BASE_URL` at upload time), which **is reachable** from the phone on the LAN.

The runtime log mentioning **`assets/images/one_short/history.png`** is **not** because the API stores Flutter asset paths. It matches the **client-side bundled fallback** used when the Mono reader treats catalog rows as `MonoContentType.article`, whose default cover category maps to **`MonoCoverCategory.culture`**, which resolves to **`history.png`**. That path appears during precache and/or `NetworkImage` error fallback—not as a database value.

---

## Reproduction

1. Run the Nest backend with `MEDIA_PUBLIC_BASE_URL=http://192.168.11.5:3000/uploads` (current `.env` intent).
2. Run the Flutter app on a **physical phone** pointed at `http://192.168.11.5:3000`.
3. Open Mono Home / reader for monos created earlier while **`MEDIA_PUBLIC_BASE_URL` was `http://localhost:3000/uploads`** (or default localhost).
4. Observe missing covers; logs may include fallback asset loading for `history.png`.

---

## Old Failing Mono Evidence

Live **`GET http://127.0.0.1:3000/v1/mono/feed?limit=5`** (same JSON shape the phone receives from `192.168.11.5`) showed multiple rows with **`coverUrl`** beginning with **`http://localhost:3000/uploads/`**.

Example older row (abbreviated):

| Field | Value |
|--------|--------|
| `monoId` | `f22f6a27-210b-4c63-a3ed-4de9f75cfa19` |
| `title` | `Full Learn Story Title ????` |
| `coverUrl` | `http://localhost:3000/uploads/1cf3efd7-804d-4802-87bd-deb1e4ed665a/cover/1778293363643-333f4d6a-070c-4f57-b954-5d75c9db727d.webp` |

Detail endpoint for the same mono confirms the same string under **`coverImageUrl`** and nested **`content.core.coverImageUrl`**:

- **`GET /v1/mono/f22f6a27-210b-4c63-a3ed-4de9f75cfa19`** → `coverImageUrl`: `http://localhost:3000/uploads/...` (matches feed).

Other “old” feed items in the same response similarly used **`http://localhost:3000/uploads/...`** for `coverUrl`.

---

## New Working Mono Evidence

From the same feed response, the newest item **`Holiday`** (`monoId` `0ada75e6-2754-4e64-b7f7-72f09b9fcb52`) had:

| Field | Value |
|--------|--------|
| `coverUrl` | `http://192.168.11.5:3000/uploads/1cf3efd7-804d-4802-87bd-deb1e4ed665a/cover/1778304382002-e1edeb6c-ca8c-447a-af3a-80bbb523ddac.jpg` |

**`GET /v1/mono/0ada75e6-2754-4e64-b7f7-72f09b9fcb52`** returned the same **`coverImageUrl`** host (`192.168.11.5`), i.e. reachable from the phone.

Note: that row still had **`writerAvatarUrl`** and **`shareUrl`** using **`http://localhost:3000`** — only the **cover** reflects the newer LAN base URL, consistent with **cover URL being rewritten at upload/publish time** while profile/share URLs come from other code paths.

---

## Backend Raw DB Values

No direct SQL was run in this environment (Prisma Client v7 here expects adapter configuration when invoked ad hoc). Semantics are defined in code:

- Published mono JSON stores cover under **`content.core.coverImageUrl`** (see extraction below).
- Whatever string was saved at publish time is returned unchanged to clients.

---

## Backend API Response Values

### Feed list (`MonoFeedSummaryItemDto`)

- **`coverUrl`**: derived only from **`content.core.coverImageUrl`** via `extractContentMeta` in `mono-feed.service.ts` (not transformed to the phone’s LAN host).

### Detail (`PublishedMonoDetailDto`)

- **`coverImageUrl`**: from **`publishedMonoListItemFromRow`** → same **`core.coverImageUrl`** passthrough.

Reference — extraction from stored JSON (trimmed string only; **no host rewriting**):

```139:146:nimon-backend/src/modules/mono-feed/mono-feed.service.ts
    const coverUrl =
      typeof core.coverImageUrl === 'string' && core.coverImageUrl.trim() !== ''
        ? core.coverImageUrl.trim()
        : null;
```

```79:83:nimon-backend/src/modules/published-monos/published-mono-common.ts
  const coverImageUrl =
    typeof core?.coverImageUrl === 'string' && core.coverImageUrl.trim() !== ''
      ? core.coverImageUrl.trim()
      : null;
```

Upload URLs are built using **`MEDIA_PUBLIC_BASE_URL`** at save time:

```78:96:nimon-backend/src/modules/media/disk-media.storage.ts
  private publicBaseUrl(): string {
    const raw =
      this.config.get<string>('MEDIA_PUBLIC_BASE_URL') ??
      process.env.MEDIA_PUBLIC_BASE_URL ??
      DEFAULT_PUBLIC_BASE;
    const t = raw.trim().replace(/\/+$/, '');
    return t.length > 0 ? t : DEFAULT_PUBLIC_BASE;
  }
  private buildPublicUrl(
    userId: string,
    kind: 'cover' | 'audio',
    storedFileName: string,
  ): string {
    const base = this.publicBaseUrl();
    const segments = [userId, kind, storedFileName].map((s) =>
      encodeURIComponent(s),
    );
    return `${base}/${segments.join('/')}`;
  }
```

So **historical rows retain whatever host was configured when the cover was uploaded** (e.g. `localhost`); **new phone uploads** retain the **current** LAN base (`192.168.11.5`).

---

## Flutter Image Source Selection

Remote Mono Home maps feed summaries to **`MonoFeedItem.coverImageUrl`** from **`dto.coverUrl`** (`mono_feed_item_mapper.dart`).

Cover UI (`_MonoCoverPage`): if **`coverImageUrl`** is non-empty → **`NetworkImage(url)`**; else **`AssetImage(fallback)`**.

```3703:3711:lib/features/mono/mono_screen.dart
    final fallback = _monoCoverFallbackAsset(_monoEffectiveCoverCategory(item));
    final url = item.coverImageUrl?.trim();

    final ImageProvider<Object> coverProvider;
    if (url != null && url.isNotEmpty) {
      coverProvider = NetworkImage(url);
    } else {
      coverProvider = AssetImage(fallback);
    }
```

Fallback asset for **`MonoCoverCategory.culture`** is **`history.png`**:

```45:59:lib/features/mono/mono_screen.dart
String _monoCoverFallbackAsset(MonoCoverCategory c) {
  switch (c) {
    case MonoCoverCategory.love:
      return 'assets/images/one_short/love.png';
    case MonoCoverCategory.horror:
      return 'assets/images/one_short/horror.png';
    case MonoCoverCategory.culture:
      return 'assets/images/one_short/history.png';
    ...
    case MonoCoverCategory.history:
      return 'assets/images/one_short/history.png';
  }
}
```

Catalog summaries use **`MonoContentType.article`**, whose default category is **`culture`** → **`history.png`**:

```62:77:lib/features/mono/mono_screen.dart
MonoCoverCategory _monoDefaultCoverCategory(MonoContentType t) {
  switch (t) {
    ...
    case MonoContentType.article:
      return MonoCoverCategory.culture;
  }
}
```

Precache **always** loads the fallback asset for adjacent cards (even when a network URL exists):

```2295:2301:lib/features/mono/mono_screen.dart
      final url = it.coverImageUrl?.trim();
      if (url != null && url.isNotEmpty) {
        precacheImage(NetworkImage(url), context);
      }
      final asset = _monoCoverFallbackAsset(_monoEffectiveCoverCategory(it));
      precacheImage(AssetImage(asset), context);
```

So the observed **`history.png`** string in logs aligns with **client fallback naming**, not API-stored asset paths.

---

## Asset / URL Existence Check

| Check | Result |
|--------|--------|
| **`assets/images/one_short/history.png` in repo** | Present (alongside `love.png`, `horror.png`, `comedy.png`, `art.png`). |
| **`pubspec.yaml` assets** | Declares **`assets/images/`**, which includes files under subdirectories for Flutter asset bundling. |
| **Old mono cover URL on phone** | **`http://localhost:3000/...`** targets the **phone**, not the PC → image bytes are not fetched from the dev server. |
| **New mono cover URL on phone** | **`http://192.168.11.5:3000/...`** targets the **LAN host** running Nest → same upload files are reachable. |

---

## Root Cause

**Confirmed:** Old laptop/Chrome-era published monos store **`content.core.coverImageUrl` values with host `localhost`**, produced when **`MEDIA_PUBLIC_BASE_URL` (or effective upload base)** was **`http://localhost:3000/uploads`**. The API returns those strings verbatim. On a **physical phone**, **`NetworkImage('http://localhost:3000/...')` cannot load the dev machine’s files**, so covers appear broken.

**Confirmed:** New phone uploads embed **`http://192.168.11.5:3000/uploads/...`**, which **does resolve** on the LAN phone → covers work.

The **`history.png`** log line is **consistent with Flutter’s bundled fallback** for **`MonoContentType.article` → culture → `history.png`**, invoked during precache and/or after failed network decode—not evidence that the backend stored `assets/images/...` in the database.

---

## Non-Causes Ruled Out

| Hypothesis | Verdict |
|-------------|---------|
| **A. DB stores Flutter `assets/images/...` paths for covers** | **Ruled out** for failing old rows inspected: API returned **`http://localhost:...`** URLs, not asset paths. |
| **C. Backend incorrectly transforms uploaded URLs on read** | **Ruled out** for cover fields: backend **passes through** `core.coverImageUrl` (see citations above). |
| **D. Flutter maps empty cover to legacy asset only (no bad URL)** | **Insufficient alone**: empty cover would show fallback assets; here URLs are **non-empty localhost**, so **`NetworkImage`** is selected first. |
| **E. `history.png` missing from repo / undeclared** | **Ruled out** in workspace: file exists and **`assets/images/`** is declared. If a device still threw “Unable to load asset”, treat as **secondary** (build/bundle or precache path), not the primary reason localhost URLs fail. |

---

## Recommended Fix Options

1. **Data repair**: Migrate existing `published_monos.content.core.coverImageUrl` (and any other stored media URLs) from `http://localhost:3000` / `http://127.0.0.1:3000` to the canonical LAN/public base used by devices.
2. **API response rewriting**: When emitting DTOs, rewrite known dev hosts to `MEDIA_PUBLIC_BASE_URL` or request-derived base (policy decision required).
3. **Client-side rewrite**: Map `localhost`/`127.0.0.1` media hosts to `NIMON_API_BASE_URL`’s host for `NetworkImage` only (tight scope; must avoid breaking intentional remote URLs).

---

## Safest Fix Recommendation

Prefer **server-side canonicalization or one-time migration** so **all clients** (Flutter, future web, tests) see consistent, reachable URLs without duplicating policy in the app. Pair with **stable `MEDIA_PUBLIC_BASE_URL`** for each deployment environment.

---

## Risks

- Blind rewriting can break environments where `localhost` URLs were intentional (rare for mobile QA).
- Mixed LAN IPs (Wi‑Fi changes) require either dynamic discovery or DNS/stable hostname for uploads.
- Avatar and `shareUrl` still showed `localhost` on newest mono in samples — **related class of bugs** for profile/share surfaces if tested on device.

---

## Commands / Queries Used

PowerShell (read-only HTTP against the running local backend):

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/v1/mono/feed?limit=5" -Headers @{ Accept = 'application/json' }
Invoke-RestMethod -Uri "http://127.0.0.1:3000/v1/mono/f22f6a27-210b-4c63-a3ed-4de9f75cfa19" -Headers @{ Accept = 'application/json' }
Invoke-RestMethod -Uri "http://127.0.0.1:3000/v1/mono/0ada75e6-2754-4e64-b7f7-72f09b9fcb52" -Headers @{ Accept = 'application/json' }
```

Workspace inspection:

- Ripgrep for `one_short`, `history.png`, `coverImageUrl`, `coverUrl`
- Listed `assets/images/one_short/` and read `pubspec.yaml`
- Read `mono_screen.dart`, `mono-feed.service.ts`, `published-mono-common.ts`, `disk-media.storage.ts`

**No application source files were modified for this diagnosis.**
