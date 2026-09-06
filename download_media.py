#!/usr/bin/env python3
"""
Download all exercise media (video + thumbnail) from the CSV,
save them into assets/media/exercises/ with index-based names,
and rewrite the CSV so the URL columns point at local asset paths.

Usage:
    python download_media.py
"""

import csv
import os
import sys
import urllib.request
import urllib.error
import ssl
import time

# ── paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(SCRIPT_DIR, "assets", "data", "exercises.csv")
OUT_DIR = os.path.join(SCRIPT_DIR, "assets", "media", "exercises")
ASSET_PREFIX = "assets/media/exercises"  # relative path stored in CSV

# ── helpers ──────────────────────────────────────────────────────────────────

def ext_from_url(url: str) -> str:
    """Extract the file extension from a URL (e.g. '.mp4', '.jpg')."""
    path