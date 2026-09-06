# Hevy Exercise Scraper Extension

This browser extension allows you to scrape exercise data from Hevy.com, including names, equipment, muscles, media URLs, and how-to instructions.

## Installation

1. Download or clone this repository.
2. Open your browser (Chrome recommended).
3. Go to `chrome://extensions/`.
4. Enable "Developer mode" in the top right.
5. Click "Load unpacked" and select the `hevy_scraper_extension` folder.

## Usage

1. Log in to Hevy.com in your browser.
2. Navigate to `https://hevy.com/exercise/`.
3. Click the extension icon in the toolbar.
4. Click "Start Scraping".
5. The extension will scroll through the exercise list, click each exercise, extract the "How to" content, and download a CSV file named `exercises.csv` (this is the file the app expects by default).

## Notes

- Ensure you are logged in to access all exercises.
- The scraping may take some time depending on the number of exercises.
- If the "How to" tab doesn't load, it might not extract the instructions.
- This extension is for personal use; respect Hevy's terms of service.