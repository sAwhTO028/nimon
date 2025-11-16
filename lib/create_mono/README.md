# Create Mono Screen

A polished Flutter screen that matches the provided mockups for creating different types of content (One-Short, Story-Series, Prompt-Episode).

## Features

- **Modal-like sheet** with dynamic titles based on selected tab
- **Clean, scrollable layout** with no overflow on small phones
- **Segmented bottom tabs** to switch between 3 creation modes
- **Preview card carousel** with dot indicators
- **JLPT level dropdown** (N1-N5)
- **Category chips** with multi-select functionality
- **Horizontal prompt cards** for One-Short and Prompt-Episode
- **Type-specific input fields** for each creation mode
- **CREATE button** with validation logic

## File Structure

```
lib/create_mono/
├── create_mono_screen.dart      # Main screen with segmented tabs
├── widgets/
│   ├── header_sheet.dart        # Top pill handle + title + CREATE button
│   ├── preview_carousel.dart    # PageView + dot indicator
│   ├── level_dropdown.dart      # JLPT dropdown
│   ├── category_chips.dart      # Wrap of FilterChips
│   ├── prompt_card.dart         # Small card used in horizontal list
│   └── input_fields.dart        # Reusable labeled text fields
└── README.md                    # This file
```

## State Management

Uses `flutter_riverpod` with `StateNotifier` for state management:

- `CreateMonoState` - Contains all form data and UI state
- `CreateMonoNotifier` - Handles state updates and validation
- `createMonoProvider` - Riverpod provider for state access

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'create_mono/create_mono_screen.dart';

// Wrap your app with ProviderScope
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        home: CreateMonoScreen(),
      ),
    );
  }
}
```

## Validation Logic

The CREATE button is enabled when:

- **One-Short**: `oneShortTitle.isNotEmpty`
- **Story-Series**: `seriesTitle.isNotEmpty && episodeTitleSeries.isNotEmpty`
- **Prompt-Episode**: `episodeTitlePrompt.isNotEmpty`

## Design System

- **Cards**: 16dp border radius, subtle shadows, 0xFFE6E6E6 borders
- **Typography**: H1 (22sp, w700), Section (18sp, w600), Field (14sp, w600)
- **Spacing**: 12-16dp between sections, 12dp inside cards
- **Colors**: Material 3 with blue accent color
- **Responsive**: Supports screens as small as 360dp width

## Mock Data

Includes exactly the specified prompt data:
- "Theme – RAINY DAY PROMISE" (4-6 minutes, Love)
- "Theme – FIRST SNOW, LAST TRAIN" (6-8 minutes, Love)

## Technical Notes

- Uses `SingleChildScrollView` with `BouncingScrollPhysics`
- All scrollables have `shrinkWrap: true` when nested
- `Wrap` for chips prevents right-overflow
- `SizedBox(height: 140)` for horizontal lists to avoid unbounded height
- No `Expanded`/`Flexible` inside unbounded `SingleChildScrollView` columns




