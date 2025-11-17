# AI Category Classification Prompt Template

This document describes the backend LLM prompt template for automatically classifying YouTube videos into story categories.

## Prompt Template

```
You are a classification assistant for a Japanese learning storytelling app.

The user provides a short Japanese YouTube video. You receive the video title, description, and transcript. Your task is to classify the video into exactly ONE story category.

Available categories (MUST choose exactly one, output only its ID):
- love
- comedy
- horror
- cultural
- adventure
- fantasy
- drama
- business
- sci_fi
- mystery

Rules:
- Output only the category ID in lowercase snake_case (no explanation, no extra text).
- If multiple categories seem possible, choose the single best match.
- If nothing fits perfectly, choose the closest category instead of inventing a new one.

Video Information:
Title: {video_title}
Description: {video_description}
Transcript: {video_transcript}

Category:
```

## Backend Implementation Guidelines

### 1. Prompt Construction

```python
def build_category_classification_prompt(video_title: str, video_description: str, video_transcript: str) -> str:
    prompt = f"""You are a classification assistant for a Japanese learning storytelling app.

The user provides a short Japanese YouTube video. You receive the video title, description, and transcript. Your task is to classify the video into exactly ONE story category.

Available categories (MUST choose exactly one, output only its ID):
- love
- comedy
- horror
- cultural
- adventure
- fantasy
- drama
- business
- sci_fi
- mystery

Rules:
- Output only the category ID in lowercase snake_case (no explanation, no extra text).
- If multiple categories seem possible, choose the single best match.
- If nothing fits perfectly, choose the closest category instead of inventing a new one.

Video Information:
Title: {video_title}
Description: {video_description}
Transcript: {video_transcript}

Category:"""
    return prompt
```

### 2. LLM Call and Validation

```python
ALLOWED_CATEGORIES = {
    'love', 'comedy', 'horror', 'cultural', 'adventure',
    'fantasy', 'drama', 'business', 'sci_fi', 'mystery'
}
DEFAULT_CATEGORY = 'cultural'  # Safe fallback

def classify_video_category(video_title: str, video_description: str, video_transcript: str) -> str:
    # Build prompt
    prompt = build_category_classification_prompt(video_title, video_description, video_transcript)
    
    # Call LLM (example with OpenAI)
    response = openai_client.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,  # Lower temperature for more consistent classification
        max_tokens=10,    # Category ID should be short
    )
    
    # Extract category from response
    category_id = response.choices[0].message.content.strip().lower()
    
    # Validate and return
    if category_id in ALLOWED_CATEGORIES:
        return category_id
    else:
        # Log warning and return default
        logger.warning(f"Invalid category '{category_id}' returned by LLM, using default '{DEFAULT_CATEGORY}'")
        return DEFAULT_CATEGORY
```

### 3. API Response Format

The backend should include the detected category in the AI-Stories generation response:

```json
{
  "storyId": "ai_story_123",
  "title": "Generated Story Title",
  "description": "Story description...",
  "category": "comedy",  // Auto-detected category (snake_case)
  "jlptLevel": "N4",
  "episodes": [...],
  "coverUrl": "...",
  "videoThumbnailUrl": "..."
}
```

### 4. Error Handling

- If LLM fails: Return `DEFAULT_CATEGORY` ('cultural')
- If LLM returns invalid category: Validate against `ALLOWED_CATEGORIES` and use default if invalid
- Log all classification results for monitoring and improvement

### 5. Category Mapping

The backend should map category IDs to match the Flutter enum:

| Backend ID (snake_case) | Flutter Enum |
|------------------------|--------------|
| `love` | `StoryCategory.love` |
| `comedy` | `StoryCategory.comedy` |
| `horror` | `StoryCategory.horror` |
| `cultural` | `StoryCategory.cultural` |
| `adventure` | `StoryCategory.adventure` |
| `fantasy` | `StoryCategory.fantasy` |
| `drama` | `StoryCategory.drama` |
| `business` | `StoryCategory.business` |
| `sci_fi` | `StoryCategory.sciFi` |
| `mystery` | `StoryCategory.mystery` |

