# Nimon Cache & Refresh Policy

**Purpose:** Consistent **memory**, **disk**, and **invalidation** strategy for Mono, Profile, Create, Learn, and Settings—aligned with wireframe flows and future backend AI jobs.  
**Constraint:** This doc plans behavior; **StoryRepo** and mocks remain until migrated (`docs/CLEANUP_WAVE_2_PLAN.md` aware).

---

## 1. Memory Cache Policy

| Data class | Policy |
|------------|--------|
| **Paged list summaries** | Hold **current page window** in notifier; **cap** retained items (e.g. max `N` rows or soft trim on tab switch) to avoid unbounded growth. |
| **Detail payloads** | Single-entry or **LRU map** keyed by `monoId` / `draftId` with **small max** (e.g. 3–5) for reader stack. |
| **Images** | Use Flutter image cache; prefer **thumbnail URLs** in lists; full-res on reader. |
| **Learn module detail** | Cache **after first open** for session; evict on language setting change (see §6). |

**Rule:** Memory cache is **not** source of truth—server / local draft storage wins on conflict after successful sync.

---

## 2. Local Persistence Policy

| Domain | Persistence |
|--------|-------------|
| **Auth tokens / prefs** | Secure storage or `shared_preferences` per existing patterns—**not** this doc’s scope to change code. |
| **Draft index / etag hints** | Already in creator repo patterns—keep **authoritative** copy server-side when online. |
| **Saved / bookmarked mono ids** | Cache id list + summary snapshot for offline read where product allows (**offline-friendly**, §5). |
| **Settings / app language / learn language** | Durable local + sync to profile when backend supports. |

---

## 3. TTL Examples (Guideline)

| Resource | TTL / consistency |
|-----------|-------------------|
| **Mono feed** | Short (**30–120 s**) or **pull-only** freshness; trending may be **15–45 s**. |
| **Profile published** | Medium (**2–10 min**) with **SWR** (§4). |
| **Saved tab** | Medium; optimistic bookmark updates (§7). |
| **Workspace drafts** | **Strong consistency after mutations**—re-fetch list on successful save/processing update. |
| **Settings / languages** | **Persistent** locally; invalidated only on explicit user change **or** successful profile sync conflict resolution. |
| **Learn detail** | Long-lived in-session after open; invalidated if **Learn language** toggles explanations (product rules—`docs/NIMON_LANGUAGE_SYSTEM.md`). |

---

## 4. Pull-to-Refresh

- **Bypass TTL** immediately for touched list.
- **Keep** stale items visible while refresh in flight (**SWR**) unless integrity error—then optionally clear list with error banner.

---

## 5. Stale-While-Revalidate (SWR)

1. Present cached summaries immediately (`isRefreshing` optional indicator).
2. Fetch fresh page in background; merge by **stable id**.
3. If fetch fails and cache exists → **silent degrade** except first load.

---

## 6. Offline-Friendly (Saved / Bookmarked)

Product-dependent (wireframe)—engineering stance:

- **Cache last known summary + minimal reader snapshot** where legal/DRM allows.
- **Queue mutations** (bookmark/react) — replay when online (**idempotent** server endpoints required).

---

## 7. Optimistic Updates — React / Bookmark

| Action | Client behavior |
|--------|----------------|
| React / like | Bump counter locally; rollback on HTTP failure |
| Bookmark | Toggle icon + PATCH; rollback on conflict |
| Unbookmark | Inverse |

Avoid **invalidate entire feed notifier** (`docs/NIMON_PERFORMANCE_BUDGETS.md`).

---

## 8. Cache Invalidation Matrix

After each event:

| Event | Invalidate / refresh targets |
|-------|-------------------------------|
| **Publish story** | Workspace list; published tab; optionally Mono feed (**first page** only, not entire cache tree). |
| **Edit story** | That **draft/detail** cache entry; workspace row; optionally **associated published** mono if edited post-publish. |
| **Delete story** | Remove ids from workspace/published caches; pruning feed rows if visible. |
| **Save draft** | Workspace summaries + creator session state—not global Mono feed unless draft becomes visible elsewhere. |
| **Bookmark / unbookmark** | Saved tab summaries; optionally adjust feed row bookmark flag only—not full refetch. |
| **Update profile** | Profile header caches; follower counts if surfaced. |
| **Change language settings** | Settings cache; **reload** learner-facing summaries if server localizes summaries (else no-op unless client-side localization only). |

**AI drafts accepted** invalidate only the **scoped entity** draft buffers—not catalog lists except when publish occurs.

---

## Related

- `docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md`
- `docs/NIMON_QUERY_PERFORMANCE_GUIDE.md`
- `docs/NIMON_LANGUAGE_SYSTEM.md`
