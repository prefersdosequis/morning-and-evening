#!/usr/bin/env python3
"""
Generate devotion MP3s using ElevenLabs.

Key behavior for this project:
- Rewrites numbered Bible book names so TTS doesn't skip them.
  Example: "2 Corinthians 7:6" -> "Second Corinthians 7:6"
           "1 Peter 5:7" -> "First Peter 5:7"

This script intentionally does NOT commit audio; the repo ignores *.mp3.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


DEFAULT_VOICE_ID = os.environ.get("ELEVENLABS_VOICE_ID") or "onwK4e9ZLuTAKqWW03F9"
DEFAULT_MODEL_ID = os.environ.get("ELEVENLABS_MODEL_ID") or "eleven_multilingual_v2"
API_BASE = os.environ.get("ELEVENLABS_API_BASE") or "https://api.elevenlabs.io/v1"


NUMBERED_BOOKS = (
    "Corinthians",
    "Thessalonians",
    "Timothy",
    "Peter",
    "John",
    "Kings",
    "Chronicles",
    "Samuel",
)


def normalize_bible_references(text: str) -> str:
    """
    Convert only the numbered book name into a word ordinal.
    Leaves chapter:verse notation unchanged (e.g., "7:6" stays "7:6").
    """

    ordinals = {
        "1": "First",
        "1st": "First",
        "2": "Second",
        "2nd": "Second",
        "3": "Third",
        "3rd": "Third",
    }

    books = "|".join(map(re.escape, NUMBERED_BOOKS))
    nums = "|".join(map(re.escape, ordinals.keys()))

    # Match patterns like:
    # - "1 John"
    # - "2nd Corinthians"
    # - "-3 Peter" (preceded by punctuation)
    pattern = re.compile(rf"(?i)(?<!\w)({nums})\s+({books})\b")

    def repl(m: re.Match[str]) -> str:
        n = m.group(1).lower()
        book = m.group(2)
        return f"{ordinals[n]} {book}"

    return pattern.sub(repl, text)


def needs_normalization(text: str) -> bool:
    return text != normalize_bible_references(text)


def load_devotions(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def select_devotion(
    devotions: List[Dict[str, Any]],
    *,
    title: Optional[str],
    day: Optional[int],
    dev_type: Optional[str],
) -> List[Dict[str, Any]]:
    if title:
        selected = [d for d in devotions if d.get("title") == title]
        if not selected:
            raise SystemExit(f'No devotion found with title "{title}".')
        return selected

    if day is None and dev_type is None:
        return devotions

    selected = devotions
    if day is not None:
        selected = [d for d in selected if int(d.get("day", -1)) == int(day)]
    if dev_type is not None:
        selected = [d for d in selected if d.get("type") == dev_type]
    if not selected:
        raise SystemExit("No devotions matched the provided filters.")
    return selected


def devotion_output_path(base_dir: Path, devotion: Dict[str, Any]) -> Path:
    dev_type = devotion.get("type")
    day = int(devotion.get("day"))
    return base_dir / str(dev_type) / f"{day:03d}.mp3"


def build_tts_text(devotion: Dict[str, Any]) -> str:
    # Use the devotion content (scripture verse + reference + body).
    # Then rewrite numbered books so the spoken output includes First/Second/Third.
    content = str(devotion.get("content", "")).strip()
    return normalize_bible_references(content)


def elevenlabs_tts_mp3(text: str, *, api_key: str, voice_id: str, model_id: str) -> bytes:
    url = f"{API_BASE}/text-to-speech/{voice_id}"
    payload = json.dumps(
        {
            "text": text,
            "model_id": model_id,
            "voice_settings": {
                "stability": 0.5,
                "similarity_boost": 0.75,
            },
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "xi-api-key": api_key,
            "accept": "audio/mpeg",
            "content-type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.read()
    except Exception as e:
        raise RuntimeError(f"ElevenLabs TTS request failed: {e}") from e


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default=os.environ.get("ELEVENLABS_API_KEY"))
    p.add_argument("--voice-id", default=DEFAULT_VOICE_ID)
    p.add_argument("--model-id", default=DEFAULT_MODEL_ID)
    p.add_argument("--devotions", default="assets/devotions.json")
    p.add_argument("--out", default="assets/audio")

    group = p.add_mutually_exclusive_group()
    group.add_argument("--title", help='Exact title, e.g. "February 20 - Morning"')
    group.add_argument("--day", type=int, help="Day of year (1-366), e.g. 51 for Feb 20")
    p.add_argument("--type", choices=["morning", "evening"], dest="dev_type")

    p.add_argument("--force", action="store_true", help="Overwrite existing MP3(s)")
    p.add_argument("--print-text", action="store_true", help="Print rewritten text and exit (no API call)")
    p.add_argument(
        "--only-needing-normalization",
        action="store_true",
        help="Only select devotions whose text will change after normalization",
    )
    p.add_argument("--dry-run", action="store_true", help="Show what would be generated and exit")
    p.add_argument("--sleep", type=float, default=1.0, help="Seconds to sleep between API calls (default: 1.0)")

    args = p.parse_args()

    devotions_path = Path(args.devotions)
    out_dir = Path(args.out)

    devotions = load_devotions(devotions_path)
    selected = select_devotion(devotions, title=args.title, day=args.day, dev_type=args.dev_type)

    if args.only_needing_normalization:
        before = len(selected)
        selected = [d for d in selected if needs_normalization(str(d.get("content", "")))]
        if not selected:
            print(f"No devotions need normalization (filtered {before} -> 0).")
            return

    if args.dry_run:
        print(f"Selected devotions: {len(selected)}")
        print(f"Output base: {out_dir}")
        print(f"Overwrite existing: {args.force}")
        print("-" * 80)
        for d in selected[:50]:
            title = d.get("title", "")
            out_path = devotion_output_path(out_dir, d)
            action = "GENERATE" if (args.force or not out_path.exists()) else "SKIP (exists)"
            changed = "CHANGED" if needs_normalization(str(d.get("content", ""))) else "UNCHANGED"
            print(f"{action:13} {changed:9} {title} -> {out_path}")
        if len(selected) > 50:
            print(f"... and {len(selected) - 50} more")
        return

    if args.print_text:
        for d in selected:
            title = d.get("title", "")
            print("=" * 80)
            print(title)
            print("-" * 80)
            print(build_tts_text(d))
            print()
        return

    api_key = args.api_key
    if not api_key:
        raise SystemExit(
            "Missing ElevenLabs API key. Set ELEVENLABS_API_KEY or pass --api-key."
        )

    for idx, d in enumerate(selected, start=1):
        title = d.get("title", "")
        out_path = devotion_output_path(out_dir, d)
        out_path.parent.mkdir(parents=True, exist_ok=True)

        if out_path.exists() and not args.force:
            print(f"[{idx}/{len(selected)}] Skipping {title} (already exists): {out_path}")
            continue

        text = build_tts_text(d)
        print(f"[{idx}/{len(selected)}] Generating audio for {title}...")
        print(f"  Text length: {len(text)} characters")
        mp3 = elevenlabs_tts_mp3(text, api_key=api_key, voice_id=args.voice_id, model_id=args.model_id)
        out_path.write_bytes(mp3)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        print(f"  ✓ Saved: {out_path} ({size_mb:.2f} MB)")

        if args.sleep > 0 and idx < len(selected):
            time.sleep(args.sleep)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        raise SystemExit(130)

