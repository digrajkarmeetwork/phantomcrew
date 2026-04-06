#!/usr/bin/env python3
"""
Phantom Crew — AI Asset Generation Pipeline

Generates game assets using AI image generation APIs.
Reads prompts from asset_prompts.json, calls the configured API,
and saves outputs to the correct asset directories.

Usage:
    python generate_assets.py --category characters
    python generate_assets.py --category map
    python generate_assets.py --category ui
    python generate_assets.py --category tasks
    python generate_assets.py --category cosmetics
    python generate_assets.py --category fx
    python generate_assets.py --all
    python generate_assets.py --list  # List all assets and their status

Requires API keys in .env file:
    STABILITY_API_KEY=sk-...
    OPENAI_API_KEY=sk-...
    REPLICATE_API_TOKEN=r8_...

Set ASSET_API to choose the provider: stability, openai, or replicate (default: openai)
"""

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

# Try to load .env file
def load_env():
    env_path = Path(__file__).parent.parent / '.env'
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, val = line.split('=', 1)
                os.environ.setdefault(key.strip(), val.strip())

load_env()

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
PROMPTS_FILE = SCRIPT_DIR / 'asset_prompts.json'


def load_prompts():
    with open(PROMPTS_FILE) as f:
        return json.load(f)


def get_api():
    return os.environ.get('ASSET_API', 'openai').lower()


def generate_openai(prompt: str, size: str) -> bytes | None:
    """Generate an image using OpenAI DALL-E 3."""
    try:
        import requests
    except ImportError:
        print("  ERROR: 'requests' package required. Install with: pip install requests")
        return None

    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("  ERROR: OPENAI_API_KEY not set in .env")
        return None

    # DALL-E 3 only supports specific sizes
    w, h = size.split('x')
    w, h = int(w), int(h)
    if max(w, h) <= 256:
        dalle_size = '1024x1024'
    elif w > h:
        dalle_size = '1792x1024'
    elif h > w:
        dalle_size = '1024x1792'
    else:
        dalle_size = '1024x1024'

    resp = requests.post(
        'https://api.openai.com/v1/images/generations',
        headers={
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
        },
        json={
            'model': 'dall-e-3',
            'prompt': prompt,
            'n': 1,
            'size': dalle_size,
            'response_format': 'b64_json',
        },
        timeout=120,
    )

    if resp.status_code != 200:
        print(f"  ERROR: OpenAI API returned {resp.status_code}: {resp.text[:200]}")
        return None

    data = resp.json()
    b64 = data['data'][0]['b64_json']
    return base64.b64decode(b64)


def generate_stability(prompt: str, size: str) -> bytes | None:
    """Generate an image using Stability AI SDXL."""
    try:
        import requests
    except ImportError:
        print("  ERROR: 'requests' package required. Install with: pip install requests")
        return None

    api_key = os.environ.get('STABILITY_API_KEY')
    if not api_key:
        print("  ERROR: STABILITY_API_KEY not set in .env")
        return None

    w, h = size.split('x')
    # SDXL requires dimensions to be multiples of 64, min 512
    w = max(512, (int(w) // 64) * 64)
    h = max(512, (int(h) // 64) * 64)

    resp = requests.post(
        'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image',
        headers={
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        },
        json={
            'text_prompts': [{'text': prompt, 'weight': 1}],
            'cfg_scale': 7,
            'width': min(w, 1024),
            'height': min(h, 1024),
            'samples': 1,
            'steps': 30,
        },
        timeout=120,
    )

    if resp.status_code != 200:
        print(f"  ERROR: Stability API returned {resp.status_code}: {resp.text[:200]}")
        return None

    data = resp.json()
    b64 = data['artifacts'][0]['base64']
    return base64.b64decode(b64)


def generate_image(prompt: str, size: str) -> bytes | None:
    """Route to the configured API."""
    api = get_api()
    if api == 'openai':
        return generate_openai(prompt, size)
    elif api == 'stability':
        return generate_stability(prompt, size)
    else:
        print(f"  ERROR: Unknown API '{api}'. Set ASSET_API to 'openai' or 'stability'.")
        return None


def resize_image(data: bytes, target_size: str, output_path: Path) -> bool:
    """Resize to target dimensions if PIL is available, otherwise save as-is."""
    try:
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(data))
        w, h = target_size.split('x')
        img = img.resize((int(w), int(h)), Image.LANCZOS)
        img.save(output_path, 'PNG')
        return True
    except ImportError:
        # Save as-is without resizing
        output_path.write_bytes(data)
        return True


def process_asset(name: str, asset_def: dict, style_ref: str, dry_run: bool = False):
    """Generate one asset definition (may produce multiple variants)."""
    prompt_template = asset_def['prompt']
    variants = asset_def.get('variants', ['default'])
    output_dir = PROJECT_DIR / asset_def['output_dir']
    filename_pattern = asset_def['filename_pattern']
    size = asset_def.get('size', '512x512')

    output_dir.mkdir(parents=True, exist_ok=True)

    for variant in variants:
        filename = filename_pattern.replace('{variant}', variant)
        output_path = output_dir / filename

        # Check if real asset already exists (not a placeholder)
        if output_path.exists() and output_path.stat().st_size > 500:
            print(f"  SKIP {filename} (already exists, {output_path.stat().st_size} bytes)")
            continue

        # Build prompt
        prompt = prompt_template.replace('{color}', variant).replace('{style}', variant)
        prompt = f"{prompt}. Style: {style_ref}"

        if dry_run:
            print(f"  DRY RUN: Would generate {filename} ({size})")
            print(f"    Prompt: {prompt[:100]}...")
            continue

        print(f"  Generating {filename} ({size})...")
        image_data = generate_image(prompt, size)

        if image_data:
            resize_image(image_data, size, output_path)
            print(f"  SAVED {filename} ({output_path.stat().st_size} bytes)")
        else:
            print(f"  FAILED {filename}")

        # Rate limiting
        time.sleep(1)


def list_assets(prompts: dict):
    """List all assets and their status (placeholder vs real)."""
    style_ref = prompts['style_reference']
    categories = prompts['categories']

    total = 0
    placeholders = 0
    real = 0
    missing = 0

    for cat_name, cat_assets in categories.items():
        print(f"\n=== {cat_name.upper()} ===")
        for asset_name, asset_def in cat_assets.items():
            variants = asset_def.get('variants', ['default'])
            filename_pattern = asset_def['filename_pattern']
            output_dir = PROJECT_DIR / asset_def['output_dir']

            for variant in variants:
                total += 1
                filename = filename_pattern.replace('{variant}', variant)
                filepath = output_dir / filename

                if not filepath.exists():
                    status = 'MISSING'
                    missing += 1
                elif filepath.stat().st_size <= 500:
                    status = f'PLACEHOLDER ({filepath.stat().st_size}B)'
                    placeholders += 1
                else:
                    status = f'REAL ({filepath.stat().st_size:,}B)'
                    real += 1

                print(f"  {status:20s} {filename}")

    print(f"\n--- Summary ---")
    print(f"Total: {total} | Real: {real} | Placeholder: {placeholders} | Missing: {missing}")


def main():
    parser = argparse.ArgumentParser(description='Phantom Crew Asset Generation')
    parser.add_argument('--category', choices=['characters', 'map', 'ui', 'tasks', 'cosmetics', 'fx'],
                        help='Generate assets for a specific category')
    parser.add_argument('--all', action='store_true', help='Generate all assets')
    parser.add_argument('--list', action='store_true', help='List all assets and their status')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be generated without calling APIs')
    args = parser.parse_args()

    if not any([args.category, args.all, args.list]):
        parser.print_help()
        sys.exit(1)

    prompts = load_prompts()
    style_ref = prompts['style_reference']
    categories = prompts['categories']

    if args.list:
        list_assets(prompts)
        return

    if args.all:
        cats_to_process = list(categories.keys())
    else:
        cats_to_process = [args.category]

    for cat_name in cats_to_process:
        if cat_name not in categories:
            print(f"Unknown category: {cat_name}")
            continue

        print(f"\n{'='*60}")
        print(f"Category: {cat_name.upper()}")
        print(f"{'='*60}")

        for asset_name, asset_def in categories[cat_name].items():
            print(f"\n  [{asset_name}]")
            process_asset(asset_name, asset_def, style_ref, dry_run=args.dry_run)

    print("\nDone!")


if __name__ == '__main__':
    main()
