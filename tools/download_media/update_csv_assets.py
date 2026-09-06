#!/usr/bin/env python3
"""
update_csv_assets.py

Update CSV rows to point to local downloaded asset filenames.

This script:
- Reads the CSV at assets/data/exercises.csv (or a provided path)
- Looks for columns that look like video/thumbnail columns
- For each row (indexed 1..N) it looks for downloaded files in
  assets/media/exercises/ with index-based names like:
    ex_0001_video.mp4
    ex_0001_thumbnail.jpg
  If such a file exists it will replace the CSV cell value with the
  relative asset path (e.g. assets/media/exercises/ex_0001_video.mp4).
- Makes a timestamped backup before writing (when --apply).
- Prints a summary and lists any rows where assets were not found.

Usage:
    python update_csv_assets.py [--apply] [--csv PATH] [--media DIR] [--prefix RELPATH]

Options:
    --apply         Write changes back to the CSV (otherwise runs a dry-run).
    --csv PATH      Path to the CSV file (default: assets/data/exercises.csv).
    --media DIR     Directory containing downloaded media files
                    (default: assets/media/exercises).
    --prefix STR    The asset path prefix to write into the CSV (default: assets/media/exercises/).
    -h, --help      Show help.
"""

from __future__ import annotations

import argparse
import csv
import shutil
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional


def find_column(fieldnames: List[str], candidates: List[str]) -> Optional[str]:
    """Return the first matching column name from fieldnames for the candidates list."""
    lower_map = {fn.lower(): fn for fn in fieldnames}
    for c in candidates:
        key = c.lower()
        if key in lower_map:
            return lower_map[key]
    return None


def find_asset_file_for_index(
    media_dir: Path, idx_str: str, kind: str
) -> Optional[Path]:
    """
    Look for a file in media_dir matching ex_{idx_str}_{kind}.* and return first match.
    kind should be 'video' or 'thumbnail' (or another suffix used by the download step).
    """
    pattern = f"ex_{idx_str}_{kind}.*"
    matches = list(media_dir.glob(pattern))
    if not matches:
        return None
    # If there are multiple matches, prefer common extensions in order
    ext_priority = [".mp4", ".mov", ".webm", ".jpg", ".jpeg", ".png", ".gif", ".webp"]
    matches_sorted = sorted(
        matches,
        key=lambda p: (
            ext_priority.index(p.suffix.lower())
            if p.suffix.lower() in ext_priority
            else len(ext_priority)
        ),
    )
    return matches_sorted[0]


def read_csv(csv_path: Path) -> List[Dict[str, str]]:
    with csv_path.open("r", newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)
        return rows, reader.fieldnames or []


def write_csv(
    csv_path: Path, fieldnames: List[str], rows: List[Dict[str, str]]
) -> None:
    # Write using same fieldnames order
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def make_backup(csv_path: Path) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    bak = csv_path.with_suffix(csv_path.suffix + f".bak.{stamp}")
    shutil.copy2(str(csv_path), str(bak))
    return bak


def process_csv(
    csv_path: Path,
    media_dir: Path,
    asset_prefix: str,
    apply: bool = False,
) -> None:
    if not csv_path.exists():
        print(f"CSV file not found: {csv_path}", file=sys.stderr)
        sys.exit(1)
    if not media_dir.exists():
        print(f"Media directory not found: {media_dir}", file=sys.stderr)
        sys.exit(1)

    rows, fieldnames = read_csv(csv_path)
    if not fieldnames:
        print("CSV has no header / fieldnames. Aborting.", file=sys.stderr)
        sys.exit(1)

    # Detect likely columns
    video_candidates = ["video", "video_url", "videoUrl", "videourl"]
    thumb_candidates = [
        "thumbnail",
        "thumbnail_url",
        "thumbnailUrl",
        "thumb",
        "thumbnailurl",
    ]

    video_col = find_column(fieldnames, video_candidates)
    thumb_col = find_column(fieldnames, thumb_candidates)

    print("Detected columns:")
    print("  video column    ->", video_col)
    print("  thumbnail column->", thumb_col)
    print()

    if video_col is None and thumb_col is None:
        print("No video or thumbnail columns detected. Nothing to do.", file=sys.stderr)
        sys.exit(0)

    missing_assets: List[str] = []
    replaced_count = 0
    rows_modified = 0

    for i, row in enumerate(rows, start=1):
        idx_str = f"{i:04d}"
        row_changed = False

        # Video
        if video_col:
            cur = (row.get(video_col) or "").strip()
            # Only attempt replacement if the cell looks like a remote URL or not yet local
            # We'll replace if a local file exists with the expected index-based name.
            asset_file = find_asset_file_for_index(media_dir, idx_str, "video")
            if asset_file:
                local_path = f"{asset_prefix.rstrip('/')}/{asset_file.name}"
                if cur != local_path:
                    row[video_col] = local_path
                    row_changed = True
                    replaced_count += 1
            else:
                if cur and cur.startswith(("http://", "https://")):
                    missing_assets.append(f"row {i} video: {cur}")

        # Thumbnail
        if thumb_col:
            cur = (row.get(thumb_col) or "").strip()
            asset_file = find_asset_file_for_index(media_dir, idx_str, "thumbnail")
            if asset_file:
                local_path = f"{asset_prefix.rstrip('/')}/{asset_file.name}"
                if cur != local_path:
                    row[thumb_col] = local_path
                    row_changed = True
                    replaced_count += 1
            else:
                if cur and cur.startswith(("http://", "https://")):
                    missing_assets.append(f"row {i} thumbnail: {cur}")

        if row_changed:
            rows_modified += 1

    print("Processing complete.")
    print(f"Rows processed: {len(rows)}")
    print(f"Rows modified:  {rows_modified}")
    print(f"Cells replaced: {replaced_count}")
    print(f"Missing assets entries: {len(missing_assets)}")
    if missing_assets:
        # Show up to first 50 missing entries
        print("\nMissing assets (first 50):")
        for m in missing_assets[:50]:
            print(" -", m)
        if len(missing_assets) > 50:
            print("  ... and", len(missing_assets) - 50, "more")

    if apply:
        bak = make_backup(csv_path)
        write_csv(csv_path, fieldnames, rows)
        print(f"\nWrote updated CSV to {csv_path}")
        print(f"Backup saved as {bak}")
    else:
        print("\nDry-run complete. No files were changed.")
        print("To apply changes, re-run with --apply")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Update CSV rows to point at local assets.")
    p.add_argument(
        "--apply", action="store_true", help="Write changes to CSV (default: dry-run)."
    )
    p.add_argument(
        "--csv",
        type=str,
        default=None,
        help="Path to CSV file (default: assets/data/exercises.csv)",
    )
    p.add_argument(
        "--media",
        type=str,
        default=None,
        help="Directory containing media files (default: assets/media/exercises)",
    )
    p.add_argument(
        "--prefix",
        type=str,
        default=None,
        help="Asset path prefix to write to CSV (default: assets/media/exercises/)",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()

    script_path = Path(__file__).resolve()
    repo_root = script_path.parents[
        2
    ]  # assume tools/download_media/<file> -> repo root
    csv_path = (
        Path(args.csv) if args.csv else repo_root / "assets" / "data" / "exercises.csv"
    )
    media_dir = (
        Path(args.media) if args.media else repo_root / "assets" / "media" / "exercises"
    )
    prefix = args.prefix if args.prefix is not None else "assets/media/exercises/"

    print("CSV path: ", csv_path)
    print("Media dir:", media_dir)
    print("Asset prefix:", prefix)
    print("Apply changes:", args.apply)
    print()

    process_csv(
        csv_path=csv_path, media_dir=media_dir, asset_prefix=prefix, apply=args.apply
    )


if __name__ == "__main__":
    main()
