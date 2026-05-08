# M7e3d Public Profile Follow Smoke Result

**Date:** 2026-05-06  
**Scope:** Manual smoke only (no code changes)

## Checklist Source
- `docs/M7E3C_PUBLIC_PROFILE_FOLLOW_SMOKE_REPORT.md`

## Manual Smoke Results

1) **Public profile opens via userId**
- Result: **PASS**
- Notes: Public creator profile opened via `/profile/public?userId=<uuid>`.

2) **Follow works**
- Result: **PASS**
- Notes: Follow action succeeds.

3) **followersCount increments**
- Result: **PASS**
- Notes: Followers count increased immediately after follow.

4) **Following tab shows followed creator stories**
- Result: **PASS**
- Notes: Mono Following tab shows creator stories after refresh.

5) **/profile/following includes creator**
- Result: **PASS**
- Notes: Creator appears in the Following list.

6) **Unfollow works**
- Result: **PASS**
- Notes: Unfollow action succeeds.

7) **Following tab refreshes**
- Result: **PASS**
- Notes: After unfollow + refresh, creator stories no longer appear.

8) **Guest follow shows sign-in snackbar**
- Result: **PASS**
- Notes: Guest tapping Follow shows “Sign in to follow creators.”

9) **Self profile hides Follow button**
- Result: **PASS**
- Notes: Follow button hidden on self profile.

## Final Verdict
**PASS**

## Next Milestone Recommendation
- Proceed to **M7e4** (optional polish): remove remaining legacy handle-based routing where feasible, and optionally add deeper link canonicalization (always rewrite to userId route when handle route is used in mock/demo).

