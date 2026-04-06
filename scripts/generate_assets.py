#!/usr/bin/env python3
"""
Phantom Crew — AI Asset Generation Script

Generates all game art assets using Stability AI, DALL-E 3, or Replicate.
Run with: python3 scripts/generate_assets.py --category <category>

Categories: characters, map, ui, tasks, cosmetics, role_reveal, end_screens, all

Requires one of these in .env (project root):
  STABILITY_API_KEY=sk-...
  OPENAI_API_KEY=sk-...
  REPLICATE_API_TOKEN=r8_...
"""
import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

# ── Dependency check ──────────────────────────────────────────────────────────
def _check_deps():
    missing = []
    for pkg in ['requests', 'PIL', 'dotenv']:
        try:
            __import__(pkg if pkg != 'PIL' else 'PIL.Image')
        except ImportError:
            missing.append({'PIL': 'Pillow', 'dotenv': 'python-dotenv'}.get(pkg, pkg))
    if missing:
        print(f"Missing packages: {', '.join(missing)}")
        print(f"Run: pip3 install {' '.join(missing)}")
        sys.exit(1)

_check_deps()

import requests
from PIL import Image
from io import BytesIO
from dotenv import load_dotenv

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
ASSETS_DIR = PROJECT_DIR / 'phantom-crew' / 'assets' / 'images'
PROMPTS_FILE = SCRIPT_DIR / 'asset_prompts.json'

load_dotenv(PROJECT_DIR / '.env')

STABILITY_KEY = os.getenv('STABILITY_API_KEY', '')
OPENAI_KEY    = os.getenv('OPENAI_API_KEY', '')
REPLICATE_KEY = os.getenv('REPLICATE_API_TOKEN', '')

STYLE_BASELINE = (
    "sci-fi mobile game 2D sprite art, clean flat vector style, dark space station atmosphere, "
    "teal and dark blue palette with accent colours, high contrast, isolated on transparent background, "
    "game-ready asset, no text, no watermarks"
)

MANIFEST_FILE = ASSETS_DIR.parent / 'generated_manifest.json'

# ── Category → output directory mapping ──────────────────────────────────────
CATEGORY_DIRS = {
    'characters':   ASSETS_DIR / 'characters',
    'phantoms':     ASSETS_DIR / 'phantoms',
    'map':          ASSETS_DIR / 'map',
    'ui':           ASSETS_DIR / 'ui',
    'tasks':        ASSETS_DIR / 'tasks',
    'cosmetics':    ASSETS_DIR / 'cosmetics',
    'fx':           ASSETS_DIR / 'fx',
    'role_reveal':  ASSETS_DIR / 'ui',
    'end_screens':  ASSETS_DIR / 'ui',
}

# ── API providers ─────────────────────────────────────────────────────────────
def generate_stability(prompt: str, width: int = 1024, height: int = 1024) -> bytes:
    """Call Stability AI SDXL and return PNG bytes."""
    url = 'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image'
    resp = requests.post(
        url,
        headers={'Authorization': f'Bearer {STABILITY_KEY}', 'Accept': 'application/json'},
        json={
            'text_prompts': [{'text': f"{prompt}, {STYLE_BASELINE}", 'weight': 1}],
            'cfg_scale': 7,
            'height': min(height, 1024),
            'width': min(width, 1024),
            'samples': 1,
            'steps': 30,
        },
        timeout=60,
    )
    resp.raise_for_status()
    data = resp.json()
    return base64.b64decode(data['artifacts'][0]['base64'])


def generate_dalle(prompt: str, size: str = '1024x1024') -> bytes:
    """Call DALL-E 3 and return PNG bytes."""
    import openai
    client = openai.OpenAI(api_key=OPENAI_KEY)
    response = client.images.generate(
        model='dall-e-3',
        prompt=f"{prompt}. Style: {STYLE_BASELINE}",
        size=size,
        quality='standard',
        n=1,
    )
    url = response.data[0].url
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    return r.content


def generate_replicate(prompt: str) -> bytes:
    """Call Replicate (SDXL) and return PNG bytes."""
    resp = requests.post(
        'https://api.replicate.com/v1/predictions',
        headers={
            'Authorization': f'Token {REPLICATE_KEY}',
            'Content-Type': 'application/json',
        },
        json={
            'version': '7762fd07cf82c948538e41f63f77d685e02b063e37e496e96eefd46c929f9bdc',
            'input': {'prompt': f"{prompt}. {STYLE_BASELINE}"},
        },
        timeout=30,
    )
    resp.raise_for_status()
    prediction = resp.json()
    pred_id = prediction['id']

    # Poll for result
    for _ in range(60):
        time.sleep(2)
        poll = requests.get(
            f'https://api.replicate.com/v1/predictions/{pred_id}',
            headers={'Authorization': f'Token {REPLICATE_KEY}'},
            timeout=10,
        )
        result = poll.json()
        if result['status'] == 'succeeded':
            img_url = result['output'][0]
            r = requests.get(img_url, timeout=30)
            return r.content
        if result['status'] == 'failed':
            raise RuntimeError(f"Replicate prediction failed: {result.get('error')}")
    raise TimeoutError("Replicate timed out")


def pick_generator():
    """Return (name, generate_fn) for the best available provider."""
    if STABILITY_KEY:
        return 'stability-ai', generate_stability
    if OPENAI_KEY:
        return 'dall-e-3', generate_dalle
    if REPLICATE_KEY:
        return 'replicate', generate_replicate
    print("ERROR: No API key found. Add STABILITY_API_KEY, OPENAI_API_KEY, or REPLICATE_API_TOKEN to .env")
    sys.exit(1)


# ── Asset generation ──────────────────────────────────────────────────────────
def load_prompts() -> dict:
    with open(PROMPTS_FILE) as f:
        return json.load(f)


def generate_asset(key: str, prompt: str, out_path: Path, generator_name: str, generate_fn) -> bool:
    if out_path.exists():
        print(f"  SKIP  {out_path.name} (already exists)")
        return True
    print(f"  GEN   {out_path.name} ({generator_name})...")
    try:
        png_bytes = generate_fn(prompt)
        # Validate PNG
        img = Image.open(BytesIO(png_bytes))
        img.verify()
        out_path.write_bytes(png_bytes)
        size_kb = len(png_bytes) // 1024
        print(f"  OK    {out_path.name} — {size_kb} KB")
        return True
    except Exception as e:
        print(f"  FAIL  {out_path.name}: {e}")
        # Write placeholder on failure
        _write_placeholder(out_path)
        return False


def _write_placeholder(path: Path):
    """Write a 64x64 coloured placeholder PNG so Flutter doesn't crash."""
    img = Image.new('RGBA', (64, 64), (0, 229, 204, 128))  # teal
    img.save(path, 'PNG')


def run_category(category: str, prompts: dict, generator_name: str, generate_fn):
    cat_prompts = prompts.get(category, {})
    if not cat_prompts:
        print(f"No prompts defined for category: {category}")
        return

    out_dir = CATEGORY_DIRS.get(category, ASSETS_DIR / category)
    out_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for key, prompt in cat_prompts.items():
        if key.startswith('_'):
            continue
        out_path = out_dir / f"{key}.png"
        ok = generate_asset(key, prompt, out_path, generator_name, generate_fn)
        results.append({
            'category': category,
            'file': str(out_path.relative_to(PROJECT_DIR / 'phantom-crew')),
            'prompt_key': key,
            'ok': ok,
        })
        time.sleep(0.5)  # Rate-limit courtesy

    _update_manifest(results, generator_name)
    ok_count = sum(1 for r in results if r['ok'])
    print(f"\n  Category '{category}': {ok_count}/{len(results)} generated successfully")
    return results


def _update_manifest(new_entries: list, tool: str):
    manifest = {'generated_at': '', 'tool': tool, 'assets': []}
    if MANIFEST_FILE.exists():
        manifest = json.loads(MANIFEST_FILE.read_text())
    from datetime import datetime, timezone
    manifest['generated_at'] = datetime.now(timezone.utc).isoformat()
    manifest['tool'] = tool
    existing_files = {a['file'] for a in manifest.get('assets', [])}
    for entry in new_entries:
        if entry['file'] not in existing_files:
            manifest['assets'].append(entry)
    MANIFEST_FILE.write_text(json.dumps(manifest, indent=2))


def ensure_placeholder_png():
    """Create a placeholder.png so Flutter asset declaration doesn't fail."""
    ph = ASSETS_DIR.parent / 'placeholder.png'
    if not ph.exists():
        _write_placeholder(ph)
        print(f"Created placeholder.png")


def ensure_all_placeholders(prompts: dict):
    """Pre-create placeholders for all declared assets so Flutter builds don't fail."""
    for category, cat_prompts in prompts.items():
        if category.startswith('_'):
            continue
        out_dir = CATEGORY_DIRS.get(category, ASSETS_DIR / category)
        out_dir.mkdir(parents=True, exist_ok=True)
        for key in cat_prompts:
            if key.startswith('_'):
                continue
            path = out_dir / f"{key}.png"
            if not path.exists():
                _write_placeholder(path)


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description='Generate Phantom Crew AI assets')
    parser.add_argument('--category', default='all',
        help='Category to generate: characters|map|ui|tasks|cosmetics|role_reveal|end_screens|all')
    parser.add_argument('--placeholders-only', action='store_true',
        help='Only write placeholder PNGs (no API calls)')
    args = parser.parse_args()

    prompts = load_prompts()
    ensure_placeholder_png()

    if args.placeholders_only:
        ensure_all_placeholders(prompts)
        print("All placeholder assets written.")
        return

    generator_name, generate_fn = pick_generator()
    print(f"Using generator: {generator_name}")

    categories = list(CATEGORY_DIRS.keys()) if args.category == 'all' else [args.category]
    for cat in categories:
        print(f"\n[{cat.upper()}]")
        run_category(cat, prompts, generator_name, generate_fn)

    print("\nDone. Run 'flutter pub get && flutter run' to see assets in-game.")


if __name__ == '__main__':
    main()
