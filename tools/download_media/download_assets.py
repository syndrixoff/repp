#!/usr/bin/env python3
"""
download_assets.py

Tool to:
- Create a virtual environment under tools/download_media/venv (if needed)
- Install `requests` inside that venv (and re-run the script under the venv Python)
- Parse assets/data/exercises.csv
- Download each remote `video` and `thumbnail` URL into assets/media/exercises/
  using index-based names (ex_0001_video.mp4 / ex_0001_thumbnail.jpg)
- Replace the CSV cells with the local asset relative path (assets/media/exercises/...)
- Create a timestamped backup of the original CSV before overwriting
- Report any download failures

Usage:
    python download_assets.py

Note:
- The script will automatically relaunch itself inside the created venv if `requests`
  is not importable in the current Python environment.
- Downloads are skipped if the target file already exists.
"""

from __future__ import annotations

import csv
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import urlparse

# -------------------------------------------------------------------------
# Paths (relative to repository root)
# The script assumes it lives in Repp/tools/download_media/download_assets.py
# So repo_root is two levels up from this file's directory.
# -------------------------------------------------------------------------
SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[2]  # Repp/
CSV_PATH = REPO_ROOT / "assets" / "data" / "exercises.csv"
MEDIA_DIR = REPO_ROOT / "assets" / "media" / "exercises"
VENV_DIR = SCRIPT_PATH.parent / "venv"

# -------------------------------------------------------------------------
# Config
# -------------------------------------------------------------------------
CSV_BACKUP_SUFFIX = time.strftime("%Y%m%d-%H%M%S")
DOWNLOAD_CHUNK_SIZE = 8192
ASSET_RELATIVE_PREFIX = "assets/media/exercises/"  # written into CSV cells


# -------------------------------------------------------------------------
# Helper dataclasses
# -------------------------------------------------------------------------
@dataclass
class DownloadResult:
    url: str
    dest: Path
    success: bool
    error: Optional[str] = None


# -------------------------------------------------------------------------
# Virtualenv & pip helper
# -------------------------------------------------------------------------
def is_windows() -> bool:
    return sys.platform.startswith("win")


def venv_python_path(venv_dir: Path) -> Path:
    if is_windows():
        return venv_dir / "Scripts" / "python.exe"
    else:
        return venv_dir / "bin" / "python"


def venv_pip_path(venv_dir: Path) -> Path:
    if is_windows():
        return venv_dir / "Scripts" / "pip.exe"
    else:
        return venv_dir / "bin" / "pip"


def create_venv(venv_dir: Path) -> None:
    if venv_dir.exists():
        print(f"Virtualenv already exists at {venv_dir}")
        return
    print(f"Creating virtualenv at {venv_dir} ...")
    subprocess.check_call([sys.executable, "-m", "venv", str(venv_dir)])
    print("Virtualenv created.")


def pip_install_in_venv(venv_dir: Path, packages: List[str]) -> None:
    pip = venv_pip_path(venv_dir)
    if not pip.exists():
        raise FileNotFoundError(f"pip not found in venv at {pip}")
    cmd = [str(pip), "install", "--upgrade"] + packages
    print("Installing packages in venv:", " ".join(packages))
    subprocess.check_call(cmd)
    print("Packages installed.")


def ensure_requests_module() -> None:
    """
    Ensure requests is available. If not, create venv, install it, and re-run this script
    under the venv Python interpreter.
    """
    try:
        import requests  # noqa: F401

        return
    except Exception:
        # Not available in current environment -> create venv and install
        print("`requests` package is not available in the current environment.")
        print("Creating virtualenv and installing `requests`...")

        create_venv(VENV_DIR)
        pip_install_in_venv(VENV_DIR, ["requests"])

        # Relaunch script under venv python
        venv_py = venv_python_path(VENV_DIR)
        if not venv_py.exists():
            raise FileNotFoundError(f"venv python not found at {venv_py}")

        env = os.environ.copy()
        # Mark that we're launching within the venv to avoid loops
        env["REPP_DOWNLOAD_IN_VENV"] = "1"
        print("Relaunching script under venv python:", venv_py)
        subprocess.check_call([str(venv_py), str(__file__)] + sys.argv[1:], env=env)
        sys.exit(0)


# -------------------------------------------------------------------------
# Download helpers (use requests; ensure ensure_requests_module() is called first)
# -------------------------------------------------------------------------
def guess_extension_from_url(url: str) -> str:
    parsed = urlparse(url)
    path = parsed.path
    ext = Path(path).suffix
    if ext:
        return ext
    # fallback
    return ""


def download_stream(url: str, dest: Path) -> DownloadResult:
    import requests

    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        # Stream download
        with requests.get(url, stream=True, timeout=30) as r:
            r.raise_for_status()
            total = r.headers.get("Content-Length")
            total = int(total) if total and total.isdigit() else None

            tmp_path = dest.with_suffix(dest.suffix + ".part")
            with open(tmp_path, "wb") as fh:
                downloaded = 0
                for chunk in r.iter_content(chunk_size=DOWNLOAD_CHUNK_SIZE):
                    if not chunk:
                        continue
                    fh.write(chunk)
                    downloaded += len(chunk)
                fh.flush()
            # Replace tmp to final
            tmp_path.replace(dest)
        return DownloadResult(url=url, dest=dest, success=True)
    except Exception as e:
        return DownloadResult(url=url, dest=dest, success=False, error=str(e))


# -------------------------------------------------------------------------
# CSV processing
# -------------------------------------------------------------------------
def read_csv(path: Path) -> List[Dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)
        return rows


def write_csv(path: Path, fieldnames: List[str], rows: List[Dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def make_backup(path: Path) -> Path:
    bak = path.with_suffix(path.suffix + f".bak.{CSV_BACKUP_SUFFIX}")
    shutil.copy2(str(path), str(bak))
    return bak


# -------------------------------------------------------------------------
# Main flow
# -------------------------------------------------------------------------
def main() -> None:
    # Ensure CSV exists
    if not CSV_PATH.exists():
        print("CSV file not found at:", CSV_PATH)
        sys.exit(1)

    # Ensure media directory exists
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)

    # Ensure requests is available (and possibly relaunch under venv)
    if os.environ.get("REPP_DOWNLOAD_IN_VENV") != "1":
        # Only attempt to create venv & relaunch if not already inside the venv run
        ensure_requests_module()

    # At this point, import requests for downloads
    import requests  # noqa: E402

    print("Reading CSV:", CSV_PATH)
    rows = read_csv(CSV_PATH)
    if not rows:
        print("No rows found in the CSV.")
        return

    fieldnames = list(rows[0].keys())

    # Make a backup
    bak = make_backup(CSV_PATH)
    print(f"Backup created at {bak}")

    failures: List[DownloadResult] = []
    success_count = 0

    # Columns to process (common names)
    video_col_candidates = ["video", "video_url", "videoUrl", "videoUrl"]
    thumb_col_candidates = [
        "thumbnail",
        "thumbnail_url",
        "thumbnailUrl",
        "thumbnailUrl",
    ]

    # Normalize: detect actual column names in CSV
    lower_to_col = {col.lower(): col for col in fieldnames}

    def find_col(candidates):
        for c in candidates:
            key = c.lower()
            if key in lower_to_col:
                return lower_to_col[key]
        return None

    video_col = find_col(video_col_candidates)
    thumb_col = find_col(thumb_col_candidates)

    print("Detected columns:")
    print(" - video column:", video_col)
    print(" - thumbnail column:", thumb_col)

    # Iterate and download
    for idx, row in enumerate(rows, start=1):
        # Build index-based base name
        idx_str = f"{idx:04d}"

        # Process video
        if video_col:
            val = (row.get(video_col) or "").strip()
            if val and val.lower().startswith(("http://", "https://")):
                # Determine extension
                ext = guess_extension_from_url(val) or ""
                if not ext:
                    # try to get content-type via HEAD request
                    try:
                        r = requests.head(val, allow_redirects=True, timeout=10)
                        ctype = r.headers.get("content-type", "")
                        if "mp4" in ctype:
                            ext = ".mp4"
                        elif "mpeg" in ctype:
                            ext = ".mp4"
                        elif "quicktime" in ctype or "mov" in ctype:
                            ext = ".mov"
                        elif "webm" in ctype:
                            ext = ".webm"
                        elif "ogg" in ctype:
                            ext = ".ogv"
                        else:
                            # fallback
                            ext = ".mp4"
                    except Exception:
                        ext = ".mp4"
                dest_name = f"ex_{idx_str}_video{ext}"
                dest_path = MEDIA_DIR / dest_name
                if dest_path.exists():
                    print(f"[{idx_str}] Video already exists, skipping: {dest_name}")
                    row[video_col] = ASSET_RELATIVE_PREFIX + dest_name
                    success_count += 1
                else:
                    print(f"[{idx_str}] Downloading video -> {dest_name}")
                    result = download_stream(val, dest_path)
                    if result.success:
                        print(f"[{idx_str}] Downloaded video: {dest_name}")
                        row[video_col] = ASSET_RELATIVE_PREFIX + dest_name
                        success_count += 1
                    else:
                        print(
                            f"[{idx_str}] Failed to download video: {val} -- {result.error}"
                        )
                        failures.append(result)

        # Process thumbnail
        if thumb_col:
            val = (row.get(thumb_col) or "").strip()
            if val and val.lower().startswith(("http://", "https://")):
                ext = guess_extension_from_url(val) or ""
                if not ext:
                    # try to infer from content-type
                    try:
                        r = requests.head(val, allow_redirects=True, timeout=10)
                        ctype = r.headers.get("content-type", "")
                        if "jpeg" in ctype or "jpg" in ctype:
                            ext = ".jpg"
                        elif "png" in ctype:
                            ext = ".png"
                        elif "webp" in ctype:
                            ext = ".webp"
                        elif "gif" in ctype:
                            ext = ".gif"
                        else:
                            ext = ".jpg"
                    except Exception:
                        ext = ".jpg"

                dest_name = f"ex_{idx_str}_thumbnail{ext}"
                dest_path = MEDIA_DIR / dest_name
                if dest_path.exists():
                    print(
                        f"[{idx_str}] Thumbnail already exists, skipping: {dest_name}"
                    )
                    row[thumb_col] = ASSET_RELATIVE_PREFIX + dest_name
                    success_count += 1
                else:
                    print(f"[{idx_str}] Downloading thumbnail -> {dest_name}")
                    result = download_stream(val, dest_path)
                    if result.success:
                        print(f"[{idx_str}] Downloaded thumbnail: {dest_name}")
                        row[thumb_col] = ASSET_RELATIVE_PREFIX + dest_name
                        success_count += 1
                    else:
                        print(
                            f"[{idx_str}] Failed to download thumbnail: {val} -- {result.error}"
                        )
                        failures.append(result)

    # Write updated CSV back (overwriting original)
    print("Writing updated CSV to:", CSV_PATH)
    write_csv(CSV_PATH, fieldnames, rows)

    # Summary
    print("\n=== Summary ===")
    print(f"Total successful downloads (counted per-file): {success_count}")
    if failures:
        print(f"Failures: {len(failures)}")
        for f in failures:
            print(f"- URL: {f.url} -> Error: {f.error}")
    else:
        print("All downloads succeeded (or already existed).")

    print(f"Original CSV backed up at: {bak}")
    print("Done.")


# -------------------------------------------------------------------------
# Entrypoint
# -------------------------------------------------------------------------
if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCanceled by user.")
        sys.exit(2)
    except subprocess.CalledProcessError as e:
        print("\nA subprocess error occurred:", e)
        sys.exit(3)
    except Exception as e:
        print("\nUnexpected error:", e)
        sys.exit(4)
