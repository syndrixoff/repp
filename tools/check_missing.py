#!/usr/bin/env python3
"""Check which exercise media files are missing from disk."""
import csv
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
CSV_PATH = os.path.join(ROOT, "assets", "data", "exercises.csv")
BACKUP_PATH = os.path.join(ROOT, "assets", "data", "exercises_backup.csv")
MEDIA_DIR = os.path.join(ROOT, "assets", "media", "exercises")

existing = set(os.listdir(MEDIA_DIR))

# Read backup to get original URLs
backup_rows = {}
with open(BACKUP_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    backup_fields = reader.fieldnames
    for i, row in enumerate(reader, 1):
        backup_rows[i] = row

# Read current CSV
missing = []
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    fields = reader.fieldnames
    for i, row in enumerate(reader, 1):
        vid = row.get("video", "").strip()
        thumb = row.get("thumbnail", "").strip()
        vid_missing = False
        thumb_missing = False
        
        if vid:
            fname = os.path.basename(vid)
            if fname and fname not in existing:
                vid_missing = True
        else:
            vid_missing = True
            
        if thumb:
            fname = os.path.basename(thumb)
            if fname and fname not in existing:
                thumb_missing = True
        else:
            thumb_missing = True
            
        if vid_missing or thumb_missing:
            brow = backup_rows.get(i, {})
            missing.append({
                "row": i,
                "name": row["name"],
                "csv_video": vid,
                "csv_thumb": thumb,
                "backup_video": brow.get("video", ""),
                "backup_thumb": brow.get("thumbnail", ""),
                "vid_missing": vid_missing,
                "thumb_missing": thumb_missing,
            })

# Write report
report_path = os.path.join(ROOT, "missing_report.txt")
with open(report_path, "w", encoding="utf-8") as f:
    f.write("Fields: " + str(fields) + "\n")
    f.write("Backup fields: " + str(backup_fields) + "\n")
    f.write("Total exercises: " + str(i) + "\n")
    f.write("Total missing entries: " + str(len(missing)) + "\n\n")
    for m in missing:
        f.write("Row " + str(m["row"]) + ": " + m["name"] + "\n")
        if m["vid_missing"]:
            f.write("  VIDEO MISSING - csv: [" + m["csv_video"] + "] backup: [" + m["backup_video"] + "]\n")
        if m["thumb_missing"]:
            f.write("  THUMB MISSING - csv: [" + m["csv_thumb"] + "] backup: [" + m["backup_thumb"] + "]\n")
        f.write("\n")

print("Done - see " + report_path)
print("Total missing entries: " + str(len(missing)))
