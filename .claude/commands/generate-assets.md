# Generate Assets — Phantom Crew AI Asset Pipeline

Generate original AI art assets for Phantom Crew using Stability AI, DALL-E 3, or Replicate.
All generated assets must be placed in the correct `assets/images/` subdirectory.

## Workflow

Make a todo list and work through each step.

### 1. Determine Which Assets to Generate

The user may specify a category (e.g. `characters`, `map`, `ui`, `tasks`, `cosmetics`, `all`).
If no argument is given, ask which category they want.

Available categories and their output directories:
- `characters` → `assets/images/characters/` and `assets/images/phantoms/`
- `map` → `assets/images/map/`
- `ui` → `assets/images/ui/`
- `tasks` → `assets/images/tasks/`
- `cosmetics` → `assets/images/cosmetics/`
- `fx` → `assets/images/fx/`
- `all` → all of the above

### 2. Check for API Keys

Read `.env` in the project root. Look for these keys:
- `STABILITY_API_KEY` → use Stability AI SDXL
- `OPENAI_API_KEY` → use DALL-E 3
- `REPLICATE_API_TOKEN` → use Replicate

If `.env` doesn't exist or keys are missing, tell the user which key(s) to add and halt.
If multiple keys are present, prefer in this order: Stability AI → DALL-E 3 → Replicate.

### 3. Read Asset Prompts

Load prompts from `scripts/asset_prompts.json`. If the file doesn't exist, create it using
the prompt templates in CLAUDE.md Section 11.

### 4. Create Output Directories

Ensure the target directories exist before writing files:
```bash
mkdir -p assets/images/characters assets/images/phantoms assets/images/map
mkdir -p assets/images/ui assets/images/tasks assets/images/cosmetics assets/images/fx
```

### 5. Generate Assets via API

For each asset in the requested category, call the appropriate API.

#### Stability AI (SDXL) — preferred for sprites and maps
```python
import requests, base64, json, os

headers = {
    "Authorization": f"Bearer {os.environ['STABILITY_API_KEY']}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

body = {
    "text_prompts": [{"text": PROMPT, "weight": 1}],
    "cfg_scale": 7,
    "height": 1024,
    "width": 1024,
    "samples": 1,
    "steps": 30,
}

response = requests.post(
    "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image",
    headers=headers,
    json=body
)
data = response.json()
image_b64 = data["artifacts"][0]["base64"]
with open(OUTPUT_PATH, "wb") as f:
    f.write(base64.b64decode(image_b64))
```

#### DALL-E 3 (OpenAI) — preferred for UI elements and concept art
```python
import openai, requests

client = openai.OpenAI()
response = client.images.generate(
    model="dall-e-3",
    prompt=PROMPT,
    size="1024x1024",
    quality="standard",
    n=1
)
image_url = response.data[0].url
img_data = requests.get(image_url).content
with open(OUTPUT_PATH, "wb") as f:
    f.write(img_data)
```

### 6. Validate Generated Images

After generation, verify:
- File exists and is non-empty
- File is a valid PNG (check magic bytes: `\x89PNG`)
- Log asset name and file size

### 7. Update Asset Manifest

Append generated assets to `assets/generated_manifest.json`:
```json
{
  "generated_at": "2026-04-06T00:00:00Z",
  "tool": "stability-ai|dall-e-3|replicate",
  "assets": [
    {"category": "characters", "file": "assets/images/characters/guardian_cyan_idle.png", "prompt_key": "guardian_idle_cyan"}
  ]
}
```

### 8. Report Results

List all successfully generated assets with file paths and sizes.
List any failures with error messages.
Remind user that generated assets should be reviewed before committing —
run `flutter pub get && flutter run` to see them in-game.

## Asset Prompt Reference

### Style Baseline (add to every prompt)
```
sci-fi mobile game 2D sprite art, clean flat vector style, dark space station atmosphere,
teal and dark blue palette with accent colours, high contrast, isolated on transparent background,
game-ready asset, no text, no watermarks
```

### Guardian Character
```
humanoid crew member in a sleek futuristic spacesuit, glowing visor helmet, 
bipedal silhouette, slim proportions, tool belt and equipment harness, 
[COLOUR] suit body colour, front-facing idle pose, full body visible,
2D game sprite, transparent background
```
Replace `[COLOUR]` with: cyan / red / orange / purple / green / pink / white / yellow

### Phantom Agent (same base, add):
```
same humanoid spacesuit design as guardian but with subtle dark aura, 
dark energy shimmer effect at edges, slightly menacing stance
```

### Map Tiles (128×128px)
```
top-down view space station floor tile, dark metal grating texture, 
teal ambient lighting, sci-fi aesthetic, seamless tileable, 
game asset, no characters, [ROOM_NAME] aesthetic
```

### UI Elements
```
sci-fi mobile game UI element, dark glass panel aesthetic, teal neon accents,
rounded corners, [ELEMENT_DESCRIPTION], clean and minimal, game HUD style
```

## Notes

- Generate one asset at a time; do not batch unless the API supports it.
- If an API call fails with a rate limit error, wait 5 seconds and retry once.
- Never overwrite an existing asset without user confirmation.
- Generated assets require manual review — AI output is not guaranteed to be game-ready.
