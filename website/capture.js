const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  await page.setViewport({ width: 1500, height: 3000, deviceScaleFactor: 1 });
  await page.goto('http://localhost:8081/app_store_generator.html', { waitUntil: 'networkidle0' });
  // Disable zoom so we get true rendering
  await page.evaluate(() => { document.body.style.zoom = 1; document.querySelector('.capture-panel').style.display = 'none'; });
  
  // Capture shot 3
  const element3 = await page.$('#shot3');
  await element3.screenshot({ path: 'test_shot3.png' });
  
  await browser.close();
})();
