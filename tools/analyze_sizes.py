#!/usr/bin/env python3
"""Analyze media file sizes to plan compression strategy."""
import os

MEDIA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "media", "exercises")

videos = []
thumbnails = []

for f in os.listdir(MEDIA_DIR):
    path = os.path.join(MEDIA_DIR, f)
    size = os.path.getsize(path)
    if f.endswith(".mp4"):
        videos.append((f, size))
    elif f.endswith(".jpg") or f.endswith(".png"):
        thumbnails.append((f, size))

videos.sort(key=lambda x: x[1], reverse=True)
thumbnails.sort(key=lambda x: x[1], reverse=True)

total_vid = sum(s for _, s in videos)
total_thumb = sum(s for _, s in thumbnails)
total = total_vid + total_thumb

print("=== MEDIA SIZE ANALYSIS ===")
print("Total size: %.1f MB" % (total / 1024 / 1024))
print()
print("Videos: %d files, %.1f MB" % (len(videos), total_vid / 1024 / 1024))
print("  Average: %.0f KB" % (total_vid / len(videos) / 1024) if videos else "  None")
print("  Largest: %s (%.0f KB)" % (videos[0][0], videos[0][1] / 1024) if videos else "  None")
print("  Smallest: %s (%.0f KB)" % (videos[-1][0], videos[-1][1] / 1024) if videos else "  None")
print("  Median: %s (%.0f KB)" % (videos[len(videos)//2][0], videos[len(videos)//2][1] / 1024) if videos else "  None")
print()
print("Thumbnails: %d files, %.1f MB" % (len(thumbnails), total_thumb / 1024 / 1024))
print("  Average: %.0f KB" % (total_thumb / len(thumbnails) / 1024) if thumbnails else "  None")
print("  Largest: %s (%.0f KB)" % (thumbnails[0][0], thumbnails[0][1] / 1024) if thumbnails else "  None")
print("  Smallest: %s (%.0f KB)" % (thumbnails[-1][0], thumbnails[-1][1] / 1024) if thumbnails else "  None")
print()

# Size distribution for videos
print("=== VIDEO SIZE DISTRIBUTION ===")
buckets = [0, 100, 200, 300, 400, 500, 750, 1000, 1500, 2000]
for i in range(len(buckets)):
    lo = buckets[i] * 1024
    hi = buckets[i + 1] * 1024 if i + 1 < len(buckets) else float("inf")
    label_hi = "%dKB" % buckets[i + 1] if i + 1 < len(buckets) else "+"
    count = sum(1 for _, s in videos if lo <= s < hi)
    total_in_bucket = sum(s for _, s in videos if lo <= s < hi) / 1024 / 1024
    if count > 0:
        print("  %dKB-%s: %d files (%.1f MB)" % (buckets[i], label_hi, count, total_in_bucket))

print()
print("=== TOP 10 LARGEST FILES ===")
all_files = videos + thumbnails
all_files.sort(key=lambda x: x[1], reverse=True)
for f, s in all_files[:10]:
    print("  %s: %.0f KB" % (f, s / 1024))
