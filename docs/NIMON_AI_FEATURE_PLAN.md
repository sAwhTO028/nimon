# Nimon AI Feature Plan

**Status:** Forward-looking architecture—**no requirement** to implement until backend and product sign-off.  
**Hard rule:** Flutter UI **must not** invoke OpenAI or other AI HTTP APIs directly.

---

## 1. Future AI Feature Roadmap

| Capability | Description | Target phase |
|------------|-------------|----------------|
| AI story generation | Outline/scenes from prompts | **V2+** |
| AI furigana generation | Ruby suggestions from kanji readings | **V2+** |
| AI source meaning generation | Draft learner explanations in Learn Language | **V2+** |
| AI English meaning generation | Canonical bridge text + validation | **V2+** |
| AI vocabulary extraction | Candidate terms from sentences | **V2+** |
| AI grammar extraction | Patterns + examples | **V2+** |
| AI quiz generation | MCQ/cloze from story | **V2+** |
| AI listening / script assistance | Transcript alignment, TTS hints | **V3** (heavier media) |

**V1:** Focus on **wireframe flows**, manual authoring, existing Learn routes, and **abstractions** only where needed—no mandatory AI shipping.

---

## 2. AI Field Policy

- AI may generate draft **English Meaning**.
- AI may generate draft **Source Meaning** only when **Learn / Source Language** is explicitly provided (or explicitly supplied for that generation request).
- AI output must be marked as **draft** until the user **accepts** it (UX/state—do not treat raw model output as canonical learner text).
- **Publishing** should use **accepted** content only, not raw AI draft content.

---

## 3. AI Provider Abstraction

**Layers:**

1. **Flutter:** `AiGenerationRepository` / `AiAssistService` interface (Dart)—methods like `suggestFurigana`, `draftSourceMeaning`, etc.
2. **Transport:** HTTP to **`nimon-backend`** (or future worker)—**only** the backend holds provider keys.
3. **Backend:** Provider adapter (OpenAI, Anthropic, etc.) behind a single internal module; swap providers without Flutter changes.

**Forbidden:** `package:http` calls from widgets to `api.openai.com`.

---

## 4. AI Request / Response Shape (Conceptual)

**Request (JSON):**

```json
{
  "feature": "furigana_suggest",
  "draftId": "uuid",
  "sentenceId": "uuid",
  "japaneseText": "...",
  "learnLanguage": "my",
  "englishMeaningHint": "...",
  "clientLocale": "ja"
}
```

**Response:**

```json
{
  "jobId": "uuid",
  "status": "completed",
  "outputs": {
    "furiganaTokens": [...],
    "englishMeaningDraft": "...",
    "sourceMeaningDraft": "...",
    "confidence": 0.0
  },
  "audit": {
    "model": "gpt-4.x",
    "promptVersion": "2026-05-01"
  }
}
```

Use **async jobs** for long tasks; poll or WebSocket as backend matures.

---

## 5. Backend-First AI Integration Rule

1. Flutter calls **your API** only.
2. Backend validates auth, quotas, content policy.
3. Backend calls AI provider.
4. Backend stores **audit metadata** and returns safe subsets to client.

---

## 6. Prompt Template Storage Plan

| Approach | Pros | Cons |
|---------|------|------|
| **Versioned YAML/JSON in backend repo** | Git review, deploy with API | Requires redeploy for copy tweaks |
| **DB table `prompt_templates`** | Runtime edits | Needs admin UI |
| **Hybrid** | Stable system prompts in repo; few hotfixes in DB | Slightly more ops |

**Recommendation:** Start with **backend repo files** (`nimon-backend/prompts/*.yaml`) + version string in responses.

---

## 7. Safety Checks

- **PII:** Strip account identifiers from prompts where unnecessary.
- **Content policy:** Reject prompts/responses violating policy (backend middleware).
- **Injection:** Treat user story text as **data**, not system instructions—use structured messages / JSON mode.
- **Japanese minors / educational:** Follow product moderation rules.

---

## 8. Cost Control

- **Per-user quotas** (daily tokens) enforced **server-side**.
- **Batch size limits** on sentences processed per request.
- **Caching:** Hash input text → reuse identical AI outputs where safe.

---

## 9. Rate Limit Strategy

- **Global:** Token bucket per API key (backend).
- **Per user:** Stricter limits for free tier.
- **Per feature:** Furigana cheaper than full story gen—different quotas.

---

## 10. Logging Strategy

- Log **request id**, **feature**, **latency**, **token usage**, **outcome** (success/fail)—**no** raw user story text in logs unless encrypted/compliance-approved.
- Flutter: log only correlation IDs returned from backend.

---

## 11. Manual Review Before Publish

**Rule:** AI-generated **Source Meaning**, **quiz**, or **published story text** must pass **human confirmation** or **explicit “accept AI draft”** UX before hitting **Publish**—wireframe must gate this.

---

## 12. V2 vs V3 Placement

| Tier | Features |
|------|----------|
| **V2** | Furigana suggest, vocabulary extract, English/source drafts, quiz draft—all behind backend + review UI. |
| **V3** | Heavy listening alignment, long-form story generation pipelines, multi-modal. |

---

## Related Documents

- `docs/NIMON_LANGUAGE_SYSTEM.md` — field separation.
- `docs/NIMON_ARCHITECTURE_CONSTITUTION.md` — repository rules.
- `ai_prompts/ADD_AI_FEATURE_PROMPT.md` — Cursor checklist.
