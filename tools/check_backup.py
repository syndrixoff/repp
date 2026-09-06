#!/usr/bin/env python3
"""Check backup CSV for remaining URLs and compare with current CSV."""
import csv
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP_PATH = os.path.join(ROOT, "assets", "data", "exercises_backup.csv")
CSV_PATH = os.path.join(ROOT, "assets", "data", "exercises.csv")
MEDIA_DIR = os.path.join(ROOT, "assets", "media", "exercises")

existing_files = set(os.listdir(MEDIA_DIR))

# Check backup CSV
print("=== BACKUP CSV ANALYSIS ===")
with open(BACKUP_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    http_rows = []
    local_rows = []
    none_rows = []
    total = 0
    for i, row in enumerate(reader, 1):
        total = i
        vid = row.get("video", "").strip()
        thumb = row.get("thumbnail", "").strip()
        if vid.startswith("http") or thumb.startswith("http"):
            http_rows.append((i, row["name"], vid, thumb))
        elif vid == "None" or not vid:
            none_rows.append((i, row["name"]))
        else:
            local_rows.append(i)  
    
    print("Total rows:", total)
    print("Rows with HTTP URLs:", len(http_rows))
    print("Rows with local paths:", len(local_rows))
    print("Rows with None/empty:", len(none_rows))
    
    if http_rows:
        print("\nHTTP URL rows:")
        for r in http_rows:
            print("  Row %d: %s" % (r[0], r[1]))
            print("    video: %s" % r[2])
            print("    thumb: %s" % r[3])

# Check current CSV for any remaining issues
print("\n=== CURRENT CSV ANALYSIS ===")
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    http_count = 0
    local_count = 0 
    none_count = 0
    total = 0
    for i, row in enumerate(reader, 1):
        total = i
        vid = row.get("video", "").strip()
        thumb = row.get("thumbnail", "").strip()
        if vid.startswith("http") or thumb.startswith("http"):
            http_count += 1
        elif vid == "None" or not vid:
            none_count += 1
        else:
            local_count += 1
    
    print("Total rows:", total)
    print("HTTP URLs:", http_count)
    print("Local paths:", local_count)
    print("None/empty:", none_count)

print("\n=== FILES ON DISK ===")
print("Total files:", len(existing_files))
videos = [f for f in existing_files if f.endswith(".mp4")]
thumbnails = [f for f in existing_files if f.endswith(".jpg") or f.endswith(".png")]
print("Videos (.mp4):", len(videos))
print("Thumbnails (.jpg/.png):", len(thumbnails))
