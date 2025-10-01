# Image Assets for Story Categories

This directory contains static images for episodes organized by story type categories.

## Story Type Categories

The app uses 10 story type categories:

1. **Love** - Romantic stories and relationships
2. **Comedy** - Humorous and lighthearted content
3. **Horror** - Scary and suspenseful stories
4. **Cultural** - Stories about culture and traditions
5. **Adventure** - Action-packed adventures
6. **Fantasy** - Magical and fantastical stories
7. **Drama** - Emotional and dramatic narratives
8. **Business** - Professional and learning-focused content
9. **Sci-Fi** - Science fiction and technology
10. **Mystery** - Detective and mystery stories

## Image Naming Convention

### Category Icons/Thumbnails
- Format: `{category}.png`
- Examples:
  - `love.png`
  - `comedy.png`
  - `horror.png`
  - `cultural.png`
  - `adventure.png`
  - `fantasy.png`
  - `drama.png`
  - `business.png`
  - `sci-fi.png`
  - `mystery.png`

### Episode Thumbnails
- Format: `{category}_{episode_number}.png`
- Examples:
  - `love_1.png` - Love category, Episode 1
  - `comedy_2.png` - Comedy category, Episode 2
  - `horror_3.png` - Horror category, Episode 3
  - `cultural_1.png` - Cultural category, Episode 1
  - `sci-fi_5.png` - Sci-Fi category, Episode 5

### Story Cover Images
- Format: Custom naming or stored as URLs in the database
- Can be referenced in the Story model's `coverUrl` field

## Notes

- All categories use lowercase with underscores replacing spaces/slashes
- Episode numbers start from 1
- Images should be in PNG format (though other formats like JPG/WebP can work)
- If an image doesn't exist, the app will fall back to placeholder URLs

## Current Assets

- `writer.png` - Used as fallback/placeholder


