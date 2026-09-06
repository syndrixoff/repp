if (window.__hevyScraperLoaded) {
  console.log("Hevy Scraper: Already loaded, reloading...");
  window.__hevyScraperLoaded = false;
}

window.__hevyScraperLoaded = true;

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "start_scraping") {
    console.log("Hevy Scraper: Received start signal");
    updateStatus("Initializing...");
    startScraping();
  }
});

var statusOverlay = null;

function updateStatus(msg) {
  if (!statusOverlay) {
    statusOverlay = document.createElement("div");
    statusOverlay.style.cssText =
      "position:fixed;top:10px;right:10px;z-index:999999;background:#1a1a1a;color:white;padding:12px 20px;border-radius:8px;font-family:sans-serif;box-shadow:0 4px 12px rgba(0,0,0,0.5);border:1px solid #333;font-size:14px;max-width:400px;";
    document.body.appendChild(statusOverlay);
  }
  statusOverlay.textContent = "Hevy Scraper: " + msg;
  console.log("Hevy Scraper:", msg);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Find the right-side scrollable panel containing exercise list
function findExerciseListPanel() {
  const allDivs = document.querySelectorAll("div");

  for (const div of allDivs) {
    const style = window.getComputedStyle(div);
    const rect = div.getBoundingClientRect();

    if (
      (style.overflowY === "auto" || style.overflowY === "scroll") &&
      rect.height > 400 &&
      rect.width > 200 &&
      rect.width < 500 &&
      rect.right > window.innerWidth * 0.5
    ) {
      const hasExerciseImages = div.querySelector('img[src*="cloudfront"]');
      if (hasExerciseImages) {
        console.log("Hevy Scraper: Found exercise list panel", rect);
        return div;
      }
    }
  }

  for (const div of allDivs) {
    const style = window.getComputedStyle(div);
    if (style.overflowY === "auto" || style.overflowY === "scroll") {
      const hasExerciseImages = div.querySelector('img[src*="cloudfront"]');
      if (hasExerciseImages) {
        return div;
      }
    }
  }

  return null;
}

// Find clickable exercise items in the list (only from "All Exercises" section)
function findExerciseItems(onlyAfterAllExercises = false) {
  const exercises = [];
  const seenNames = new Set();

  // Find "All Exercises" header position to filter out "Popular Exercises"
  let allExercisesY = 0;
  if (onlyAfterAllExercises) {
    const headers = document.querySelectorAll("p, h2, h3, span, div");
    for (const header of headers) {
      if (header.textContent.trim() === "All Exercises") {
        const rect = header.getBoundingClientRect();
        allExercisesY = rect.top;
        break;
      }
    }
  }

  const images = document.querySelectorAll('img[src*="cloudfront"]');

  for (const img of images) {
    const src = img.src || "";

    if (!src.includes("exercise-assets") && !src.includes("cloudfront"))
      continue;

    let clickable = img;
    for (let i = 0; i < 6; i++) {
      if (!clickable.parentElement) break;
      clickable = clickable.parentElement;

      const style = window.getComputedStyle(clickable);
      if (
        style.cursor === "pointer" ||
        clickable.onclick ||
        clickable.getAttribute("role") === "button"
      ) {
        break;
      }
    }

    let container = img.parentElement;
    let exerciseName = "";
    let muscleGroup = "";

    for (let i = 0; i < 5 && container; i++) {
      const textNodes = container.querySelectorAll("p, span, div");
      for (const node of textNodes) {
        const text = node.textContent.trim();
        if (!text || text.length < 2) continue;

        if (
          [
            "Popular Exercises",
            "All Exercises",
            "Library",
            "Routines",
            "Feedback",
          ].includes(text)
        )
          continue;

        const nodeStyle = window.getComputedStyle(node);
        const fontSize = parseFloat(nodeStyle.fontSize);

        if (node.getAttribute("type") === "secondary" || fontSize < 14) {
          if (!muscleGroup && text.length > 2 && text.length < 50) {
            muscleGroup = text;
          }
        } else if (!exerciseName && text.length > 2 && text.length < 100) {
          exerciseName = text;
        }
      }

      if (exerciseName && muscleGroup) break;
      container = container.parentElement;
    }

    if (!exerciseName || exerciseName.length < 3) continue;
    if (seenNames.has(exerciseName)) continue;

    // Skip items above "All Exercises" header (they are from "Popular Exercises")
    if (onlyAfterAllExercises && allExercisesY > 0) {
      const rect = clickable.getBoundingClientRect();
      if (rect.top < allExercisesY) continue;
    }

    seenNames.add(exerciseName);

    exercises.push({
      name: exerciseName,
      muscleGroup: muscleGroup || "Unknown",
      el: clickable,
      thumbnailUrl: src,
    });
  }

  console.log("Hevy Scraper: Found", exercises.length, "exercises");
  return exercises;
}

// Extract data from the detail panel (left side) after clicking an exercise
function extractExerciseDetails(fallbackThumbnail, listName) {
  const data = {
    name: "",
    equipment: "None",
    primary_muscle: "None",
    secondary_muscle: "None",
    video: "None",
    thumbnail: fallbackThumbnail || "None",
    howTo: "",
  };

  // Find exercise name from h2 element (Hevy uses h2 for exercise title)
  const h2s = document.querySelectorAll("h2");
  for (const h2 of h2s) {
    const text = h2.textContent.trim();
    if (text && text.length > 2 && text.length < 100) {
      // Skip generic labels
      const lower = text.toLowerCase();
      if (
        lower !== "exercise" &&
        lower !== "exercises" &&
        !lower.includes("popular") &&
        !lower.includes("all exercises")
      ) {
        data.name = text;
        break;
      }
    }
  }

  // Fallback to h1 if no h2 found
  if (!data.name) {
    const h1s = document.querySelectorAll("h1");
    for (const h1 of h1s) {
      const text = h1.textContent.trim();
      if (text && text.length > 2 && text.length < 100) {
        const lower = text.toLowerCase();
        if (lower !== "exercise" && lower !== "exercises") {
          data.name = text;
          break;
        }
      }
    }
  }

  // Use list name as final fallback
  if (!data.name && listName) {
    data.name = listName;
  }

  // Find video
  const video = document.querySelector("video");
  if (video) {
    const source = video.querySelector("source");
    data.video = source?.src || video.src || "None";
  }

  // Extract Equipment and Muscles using Hevy's exact DOM structure
  // Structure: div.sc-839c587-2 contains two <p> elements - label and value
  // First <p> has gray color (label like "Equipment: ")
  // Second <p> has the value (like "Resistance Band")

  const allParagraphs = document.querySelectorAll("p");

  for (const p of allParagraphs) {
    const text = p.textContent.trim().toLowerCase();

    // Check if this is a label paragraph
    if (text.startsWith("equipment:") || text === "equipment:") {
      // Get next sibling p element for value
      const nextP = p.nextElementSibling;
      if (nextP && nextP.tagName === "P") {
        const value = nextP.textContent.trim();
        if (value && value.length > 0) {
          data.equipment = value;
        }
      }
    }

    if (
      text.startsWith("primary muscle") ||
      text.includes("primary muscle group:")
    ) {
      const nextP = p.nextElementSibling;
      if (nextP && nextP.tagName === "P") {
        const value = nextP.textContent.trim();
        if (value && value.length > 0) {
          data.primary_muscle = value;
        }
      }
    }

    if (
      text.startsWith("secondary muscle") ||
      text.includes("secondary muscle group:")
    ) {
      const nextP = p.nextElementSibling;
      if (nextP && nextP.tagName === "P") {
        const value = nextP.textContent.trim();
        if (value && value.length > 0) {
          data.secondary_muscle = value;
        }
      }
    }
  }

  // Alternative: Find divs with class containing "sc-839c587" (the label-value container)
  if (
    data.equipment === "None" ||
    data.primary_muscle === "None" ||
    data.secondary_muscle === "None"
  ) {
    const containers = document.querySelectorAll('div[class*="sc-839c587"]');
    for (const container of containers) {
      const ps = container.querySelectorAll("p");
      if (ps.length >= 2) {
        const label = ps[0].textContent.trim().toLowerCase();
        const value = ps[1].textContent.trim();

        if (label.includes("equipment") && data.equipment === "None") {
          data.equipment = value;
        }
        if (
          label.includes("primary muscle") &&
          data.primary_muscle === "None"
        ) {
          data.primary_muscle = value;
        }
        if (
          label.includes("secondary muscle") &&
          data.secondary_muscle === "None"
        ) {
          data.secondary_muscle = value;
        }
      }
    }
  }

  // Extract How To instructions
  data.howTo = extractHowTo();

  console.log("Hevy Scraper: Extracted details:", {
    name: data.name,
    equipment: data.equipment,
    primary: data.primary_muscle,
    secondary: data.secondary_muscle,
    video: data.video ? "found" : "none",
    howTo: data.howTo ? data.howTo.substring(0, 50) + "..." : "none",
  });

  return data;
}

function extractHowTo() {
  // Hevy uses h5 for step numbers and p for instruction text
  // Structure: div > div > h5 (number like "1.") + p (instruction)
  const instructions = [];

  const h5s = document.querySelectorAll("h5");
  for (const h5 of h5s) {
    const numText = h5.textContent.trim();
    // Check if it's a step number like "1." or "2."
    if (/^\d+\.$/.test(numText)) {
      const parent = h5.parentElement;
      if (parent) {
        const p = parent.querySelector("p");
        if (p) {
          const instruction = p.textContent.trim();
          if (instruction.length > 3) {
            instructions.push(`${numText} ${instruction}`);
          }
        }
      }
    }
  }

  if (instructions.length >= 1) {
    console.log(
      "Hevy Scraper: Found",
      instructions.length,
      "How To steps via h5+p",
    );
    return instructions.join(" | ");
  }

  // Fallback: Look for ordered list
  const ols = document.querySelectorAll("ol");
  for (const ol of ols) {
    const items = ol.querySelectorAll("li");
    if (items.length >= 2) {
      const text = Array.from(items)
        .map((li, idx) => `${idx + 1}. ${li.textContent.trim()}`)
        .filter((t) => t.length > 5)
        .join(" | ");
      if (text.length > 20) return text;
    }
  }

  return "";
}

async function startScraping() {
  const listPanel = findExerciseListPanel();

  if (!listPanel) {
    updateStatus("ERROR: Could not find exercise list panel!");
    return;
  }

  updateStatus("Scrolling to All Exercises section...");

  // First, scroll to find "All Exercises" header and skip "Popular Exercises"
  listPanel.scrollTop = 0;
  await sleep(300);

  let foundAllExercises = false;
  let scrollAttempts = 0;

  while (!foundAllExercises && scrollAttempts < 30) {
    // Look for "All Exercises" text
    const headers = listPanel.querySelectorAll("p, h2, h3, span, div");
    for (const header of headers) {
      if (header.textContent.trim() === "All Exercises") {
        // Scroll this into view
        header.scrollIntoView({ block: "start", behavior: "instant" });
        await sleep(300);
        foundAllExercises = true;
        updateStatus("Found All Exercises section!");
        break;
      }
    }

    if (!foundAllExercises) {
      listPanel.scrollBy({ top: 200, behavior: "instant" });
      await sleep(200);
      scrollAttempts++;
    }
  }

  if (!foundAllExercises) {
    updateStatus(
      "WARNING: Could not find All Exercises header, starting from top...",
    );
    listPanel.scrollTop = 0;
  }

  await sleep(500);

  const allExercises = new Map();
  let lastCount = 0;
  let noNewCount = 0;

  while (noNewCount < 5) {
    const found = findExerciseItems(true); // Only get exercises after "All Exercises" header

    for (const ex of found) {
      if (!allExercises.has(ex.name)) {
        allExercises.set(ex.name, ex);
      }
    }

    updateStatus(`Collecting: ${allExercises.size} exercises found...`);

    if (allExercises.size === lastCount) {
      noNewCount++;
    } else {
      noNewCount = 0;
      lastCount = allExercises.size;
    }

    listPanel.scrollBy({ top: 300, behavior: "instant" });
    await sleep(400);
  }

  const exercises = Array.from(allExercises.values());
  updateStatus(`Found ${exercises.length} exercises. Starting scrape...`);

  if (exercises.length === 0) {
    updateStatus("ERROR: No exercises found!");
    return;
  }

  const results = [];

  for (let i = 0; i < exercises.length; i++) {
    const exercise = exercises[i];
    updateStatus(`Scraping ${i + 1}/${exercises.length}: ${exercise.name}`);

    listPanel.scrollTop = 0;
    await sleep(200);

    let foundEl = null;
    let scrollAttempts = 0;

    while (!foundEl && scrollAttempts < 50) {
      const currentItems = findExerciseItems(false); // Get all items when searching
      const match = currentItems.find((item) => item.name === exercise.name);

      if (match) {
        foundEl = match.el;
        break;
      }

      listPanel.scrollBy({ top: 200, behavior: "instant" });
      await sleep(150);
      scrollAttempts++;
    }

    if (!foundEl) {
      console.log("Hevy Scraper: Could not find:", exercise.name);
      continue;
    }

    // Click the exercise
    foundEl.scrollIntoView({ block: "center", behavior: "instant" });
    await sleep(100);
    foundEl.click();
    await sleep(1200);

    // Click "How to" tab
    const howToTabs = [
      ...document.querySelectorAll("p, span, button, div, a"),
    ].filter((el) => {
      const text = el.textContent.trim();
      return (
        (text === "How to" || text === "How To") && el.childElementCount === 0
      );
    });

    for (const tab of howToTabs) {
      try {
        tab.scrollIntoView({ block: "center" });
        tab.click();

        const rect = tab.getBoundingClientRect();
        const opts = {
          bubbles: true,
          clientX: rect.left + 5,
          clientY: rect.top + 5,
        };
        tab.dispatchEvent(new PointerEvent("pointerdown", opts));
        tab.dispatchEvent(new PointerEvent("pointerup", opts));
        tab.dispatchEvent(new MouseEvent("click", opts));
      } catch (e) {
        console.log("Hevy Scraper: Error clicking How To tab", e);
      }
    }
    await sleep(800);

    // Extract details
    const data = extractExerciseDetails(exercise.thumbnailUrl, exercise.name);

    if (!data.name || data.name.length < 2) {
      data.name = exercise.name;
    }

    if (data.name && data.name.length > 2) {
      results.push(data);
      console.log("Hevy Scraper: Scraped:", data.name);
    }

    await sleep(200);
  }

  updateStatus(`Done! Scraped ${results.length} exercises. Downloading CSV...`);
  downloadCSV(results);

  setTimeout(() => {
    if (statusOverlay) {
      statusOverlay.textContent = `Hevy Scraper: ✅ Downloaded ${results.length} exercises!`;
      setTimeout(() => statusOverlay?.remove(), 10000);
    }
  }, 1000);
}

function downloadCSV(results) {
  const esc = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const headers = [
    "name",
    "equipment",
    "primary_muscle",
    "secondary_muscle",
    "video",
    "thumbnail",
    "howTo",
  ];

  const csv = [
    headers.join(","),
    ...results.map((r) => headers.map((h) => esc(r[h])).join(",")),
  ].join("\n");

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);

  const a = document.createElement("a");
  a.href = url;
  a.download = "exercises.csv";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);

  console.log("Hevy Scraper: CSV downloaded with", results.length, "exercises");
}
