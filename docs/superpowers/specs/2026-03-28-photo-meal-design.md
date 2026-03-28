# Photo Meal Feature

## Problem

Users currently describe meals via text only. A photo of the meal would give the AI more information (portion size, visible ingredients) and be faster than typing a description. The user can optionally type alongside the photo for context (e.g., "I had a greek salad" + photo).

## Design

### iOS UI — Chat Input Bar

The input bar adds a camera button to the left of the text field:

```
[camera icon] [  What did you eat?  ] [send]
```

- Tapping the camera icon shows a confirmation dialog: "Take Photo" (camera) and "Choose from Library" (photo library)
- After selecting a photo, a small thumbnail preview (~60pt tall) appears above the input bar with an X button to remove it
- The user can optionally type text alongside the photo
- Send button sends both text (if any) and image
- If only a photo is attached with no text, the AI describes what it sees
- One photo per message (no multi-photo support)

### Image Processing (iOS)

Before sending, the selected image is processed:

- Resized so the longest side is at most 1024px (preserving aspect ratio)
- Compressed to JPEG at 0.5 quality (~200-300KB typical)
- Base64-encoded and included in the request body as a string

### Chat History Display

Since images are not stored, messages that had a photo show a "[Photo]" prefix in the chat bubble text. This prefix is added by the backend when storing the message.

### Backend API Changes

`POST /chat` request body:

```json
{
    "message": "I had a greek salad",
    "image": "<base64-encoded-jpeg or null>"
}
```

- `ChatRequest` model adds: `image: str | None = None`
- When `image` is present, the OpenAI message uses a content array:

```python
{"role": "user", "content": [
    {"type": "text", "text": "I had a greek salad"},
    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
]}
```

- When `image` is absent, the message stays a plain string (unchanged behavior)
- The image is **not stored** in the database. Only the text is stored in `chat_messages`, prefixed with `[Photo] ` when a photo was attached
- No changes to: system prompt, response parsing (`parse_llm_response`), SSE streaming, OpenAI model (`gpt-4o` already supports vision)

### Chat History Endpoint

`GET /chat/history` returns messages as-is. The `[Photo] ` prefix in the content string is the only trace of the image. The iOS app can detect this prefix to render the bubble differently if desired.

## Scope of Changes

### Backend

- `backend/app/routers/chat.py`: Add optional `image` field to `ChatRequest`. Build OpenAI content array when image is present. Prefix stored message with `[Photo] ` when image was attached.

### iOS — Models

- `ChatMessage.swift`: Add optional `image: String?` field to `ChatRequest`

### iOS — ViewModel

- `ChatViewModel`: Add `selectedImage: UIImage?` state. On send, compress/resize/base64-encode the image and include in request. Clear image after sending.

### iOS — Views

- `ChatView`: Add camera button to input bar. Show thumbnail preview above input when photo is selected.
- New `PhotoPickerButton` view: wraps system photo picker with camera/library options
- `ChatBubbleView`: Detect `[Photo]` prefix and render it distinctly (e.g., camera icon instead of raw text prefix)

### iOS — Services

- No changes to `SSEClient` — the image field is part of the JSON body which is already encoded and sent

### iOS — Configuration

- `Info.plist`: Add `NSCameraUsageDescription` ("Take a photo of your meal to estimate calories") for camera access permission

### iOS — Frameworks

- Import `PhotosUI` for `PhotosPicker` (already bundled with iOS, no external dependency)

### Not Changed

- System prompt, response parsing, SSE streaming
- Dashboard, stats bar, settings
- No new dependencies on backend (OpenAI SDK already supports vision)
- No file storage or new infrastructure
