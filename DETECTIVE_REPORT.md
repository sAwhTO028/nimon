# Detective Report: "Select Prompt" Widget Investigation

## 1. All "Select Prompt" Occurrences Found

### Found 4 occurrences:

1. **`lib/ui/bottom_sheets/add_mono_bottom_sheet.dart`** (line 686)
   - Class: `_AddMonoSheetState`
   - Method: `_buildPromptSelector()`
   - Status: ⚠️ **DEAD CODE - NOT USED**

2. **`lib/features/create/create_screen.dart`** (line 789)
   - Class: `_CreateScreenState`
   - Method: `_buildPromptSelector()`
   - Status: ✅ **ACTIVELY USED**

3. **`lib/ui/create/widgets/build_prompt_section.dart`** (line 135)
   - Class: `BuildPromptSection`
   - Status: ❓ **NEEDS VERIFICATION**

4. **`lib/create_mono/one_short_tab.dart`** (line 231)
   - Status: ❓ **NEEDS VERIFICATION**

---

## 2. Navigation Trace

### Route Chain:
1. User navigates to `/create` route (from Mono screen or home)
2. Route handler: `GoRoute(path: '/create', builder: (_, state) => CreateScreen(...))`
3. `CreateScreen` is a full-screen widget (NOT a bottom sheet)
4. Inside `CreateScreen`, there's a tab system with `CreateTab.oneShort`
5. When One-Short tab is selected, `_buildOneShortContent()` is called
6. `_buildOneShortContent()` calls `_buildPromptSelector()` at line 760
7. This method renders the "Select Prompt" section at line 789

### Key Finding:
- **`showAddMonoSheet()` function is NEVER called anywhere in the codebase**
- The `_AddMonoSheet` widget in `add_mono_bottom_sheet.dart` is **DEAD CODE**
- The actual screen is `CreateScreen`, which is a full-screen page, NOT a bottom sheet

---

## 3. Duplicate/Dead Code Analysis

### ✅ SAFE TO DELETE (Dead Code):
- **`lib/ui/bottom_sheets/add_mono_bottom_sheet.dart`**
  - The entire file appears to be unused
  - `showAddMonoSheet()` function is never called
  - `_AddMonoSheet` widget is never instantiated
  - Comment in code says: "TODO: check usage before removing - Entry point function. Currently not called anywhere"

### ❓ NEEDS VERIFICATION:
- **`lib/ui/create/widgets/build_prompt_section.dart`**
  - Has `BuildPromptSection` widget with "Select Prompt" text
  - Need to check if this is used anywhere

- **`lib/create_mono/one_short_tab.dart`**
  - Has "Select Prompt" text at line 231
  - Need to check if this is used

---

## 4. Exact File to Edit

### ✅ CORRECT FILE:
**`lib/features/create/create_screen.dart`**

### Correct Method:
**`_buildPromptSelector()`** (starts at line 760)

### Correct Class:
**`_CreateScreenState`**

### The "Select Prompt" text is at:
**Line 789** in `create_screen.dart`

---

## 5. Debug Change Applied

I will now add a visible debug change to prove this is the correct widget.

