# 🔍 One-Short Create Screen - Audit & Fix Results

## 🎯 ROOT CAUSE FOUND

**Problem**: New UI was implemented in `add_mono_bottom_sheet.dart` but the **ACTIVE** screen (`create_screen.dart`) was still using old code.

**Solution**: Updated the active screen to use the new widgets.

---

## ✅ FIXES APPLIED

### 1. **`lib/features/create/create_screen.dart`** (ACTIVE SCREEN - UPDATED)

**Changes:**
- ✅ Added `OneShortState` class and `OneShortStateSteps` extension
- ✅ Imported `PromptCarousel` and `CustomPromptSheet`
- ✅ Removed all `currentStep` mutations from setters (`_setLevel`, `_setCategory`, `_setPrompt`, `_setTitle`)
- ✅ Updated `_buildStepIndicator()` to:
  - Use `stepsCompleted` extension (pure calculation)
  - Hide when `stepsCompleted == 0`
  - Show dots based on count, not sequential steps
- ✅ Replaced vertical prompt list with `PromptCarousel` in `_buildPromptContent()`
- ✅ Wired custom prompt bottom sheet via `onTapCustom`
- ✅ Added `_visibleLimit` state for pagination (starts at 5, increases to 10, then 15)
- ✅ Updated preview card to use actual state values (removed demo fallbacks)
- ✅ Updated `_setPrompt()` to accept `Prompt` object instead of string ID
- ✅ Updated `_refreshPrompts()` to use `_visibleLimit`

**Result**: Active screen now uses the new UI!

---

## 📁 FILE STATUS

### ✅ ACTIVE & USED
| File | Status | Usage |
|------|--------|-------|
| `lib/features/create/create_screen.dart` | ✅ ACTIVE | Main create screen (via `/create` route) |
| `lib/ui/create/widgets/one_short_paper_card.dart` | ✅ USED | Preview card widget |
| `lib/ui/create/widgets/prompt_carousel.dart` | ✅ USED | Horizontal prompt picker |
| `lib/ui/create/widgets/custom_prompt_sheet.dart` | ✅ USED | Custom prompt bottom sheet |
| `lib/data/prompt_repository.dart` | ✅ USED | Prompt data source |
| `lib/ui/widgets/one_short_prompt_card.dart` | ✅ USED | Individual prompt card |

### ❌ UNUSED/DUPLICATE (Safe to Delete)
| File | Issue | Recommendation |
|------|-------|----------------|
| `lib/ui/widgets/one_short_paper_card.dart` | Old duplicate (uses CompactStoryCard) | **DELETE** - not imported |
| `lib/ui/create/one_short_paper_view.dart` | Not imported anywhere | **DELETE** - dead code |

### ⚠️ HAS CODE BUT UNUSED ENTRY POINT
| File | Status |
|------|--------|
| `lib/ui/bottom_sheets/add_mono_bottom_sheet.dart` | Has `showAddMonoSheet()` but never called. Keep for reference or future use. |

---

## 📊 DEPENDENCY MAP (Final State)

```
main.dart
  └─> GoRouter('/create')
       └─> CreateScreen ✅ ACTIVE (NOW FIXED)
            ├─> OneShortState (local)
            ├─> OneShortStateSteps extension ✅
            ├─> OneShortPaperCard ✅
            ├─> PromptCarousel ✅ NOW USED
            │   ├─> Custom card at index 0 ✅
            │   └─> OneShortPromptCard ✅
            ├─> CustomPromptSheet ✅ NOW USED
            └─> PromptRepository ✅
```

---

## 🧹 CLEANUP RECOMMENDATIONS

### Safe to Delete (Not Referenced):
1. `lib/ui/widgets/one_short_paper_card.dart` - Old duplicate
2. `lib/ui/create/one_short_paper_view.dart` - Not imported

### Optional Cleanup (Unused Helpers):
In `create_screen.dart`, these methods are now simple wrappers:
- `_getPromptTitle()` → just `_selectedPrompt?.title ?? ''`
- `_getContextText()` → just `_selectedPrompt?.context ?? ''`
- `_getDuration()` → just `_selectedPrompt?.duration ?? ''`
- `_getCategoryIcon()` - not used
- `_getAssetPathForCategory()` - not used

**Recommendation**: Remove or simplify these helpers.

---

## ✅ VERIFICATION COMPLETE

**Step Indicator:**
- ✅ Uses pure calculation (`stepsCompleted` extension)
- ✅ Hides when 0 selections
- ✅ Title-first = step 1 (not step 4)

**Prompt Picker:**
- ✅ PromptCarousel with custom card at index 0
- ✅ Pagination 5→10→15 working
- ✅ Dots indicator excludes custom card

**State Management:**
- ✅ No `currentStep` mutations
- ✅ All state changes trigger rebuilds
- ✅ Step indicator purely derived

**All files compile without errors!**

