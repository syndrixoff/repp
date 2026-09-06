document.getElementById('start').addEventListener('click', async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  if (!tab || !tab.url || !tab.url.includes('hevy.com/exercise')) {
    document.getElementById('start').textContent = '⚠️ Open hevy.com/exercise first';
    document.getElementById('start').style.background = 'linear-gradient(135deg, #f59e0b, #ef4444)';
    setTimeout(() => {
      document.getElementById('start').textContent = '⚡ Start Scraping';
      document.getElementById('start').style.background = 'linear-gradient(135deg, #4ade80, #22d3ee)';
    }, 2000);
    return;
  }

  // Inject content script first to ensure it's loaded
  try {
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      files: ['content.js']
    });
  } catch (e) {
    // Script might already be injected, that's fine
    console.log('Script injection note:', e.message);
  }

  // Small delay to let the script initialize
  setTimeout(() => {
    chrome.tabs.sendMessage(tab.id, { action: 'start_scraping' });
    document.getElementById('start').textContent = '✅ Scraping Started!';
    document.getElementById('start').style.background = 'linear-gradient(135deg, #22c55e, #059669)';
  }, 300);
});
