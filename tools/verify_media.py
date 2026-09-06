#!/usr/bin/env python3
"""Check if all exercises with URLs in backup have corresponding files on disk."""
import csv
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_PATH = os.path.join(ROOT, "assets", "data", "exercises_backup.csv")
CSV_PATH = os.path.join(ROOT, "assets", "data", "exercises.csv")
MEDIA_DIR = os.path.join(ROOT, "assets", "media", "exercises")

existing = set(os.listdir(MEDIA_DIR))

# Read current CSV to get the expected local filenames
current_rows = []
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        current_rows.append(row)

# Check each row
really_missing = []
none_expected = []
for i, row in enumerate(current_rows, 1):
    vid = row.get("video", "").strip()
    thumb = row.get("thumbnail", "").strip()
    
    vid_file = os.path.basename(vid) if vid and vid != "None" else None
    thumb_file = os.path.basename(thumb) if thumb and thumb != "None" else None
    
    if vid_file and vid_file not in existing:
        really_missing.append("Row %d [%s]: VIDEO %s not on disk" % (i, row["name"], vid_file))
    if thumb_file and thumb_file not in existing:
        really_missing.append("Row %d [%s]: THUMB %s not on disk" % (i, row["name"], thumb_file))
    
    if (not vid_file) or (not thumb_file):
        missing_what = []
        if not vid_file:
            missing_what.append("video")
        if not thumb_file:
            missing_what.append("thumbnail")
        none_expected.append("Row %d [%s]: no %s" % (i, row["name"], "+".join(missing_what)))

print("=== FILES REFERENCED IN CSV BUT NOT ON DISK ===")
print("Count:", len(really_missing))
for m in really_missing:
    print("  " + m)

print()
print("=== EXERCISES WITH NO MEDIA (None/empty in CSV) ===")
print("Count:", len(none_expected))
for n in none_expected:
    print("  " + n)
