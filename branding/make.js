// Renders the icon variants: rounded (any), full-bleed (maskable / Apple / Android) and admin.
const { chromium } = require('playwright');
const fs = require('fs');
const base = fs.readFileSync(__dirname + '/icon.html', 'utf8');
const label = '<g><rect x="166" y="392" width="180" height="50" rx="25" fill="#00d632"/><text x="256" y="429" text-anchor="middle" font-family="P" font-size="34" fill="#fff" letter-spacing="3">ADMIN</text></g>';
const variants = {
  rounded: { ROUND: 112, BORDERX: 10, BORDERW: 492, BORDERR: 104, BORDERS: 6, BORDERO: .9, SHIFTY: 262, SCALE: 1, LABEL: '' },
  full: { ROUND: 0, BORDERX: 0, BORDERW: 0, BORDERR: 0, BORDERS: 0, BORDERO: 0, SHIFTY: 262, SCALE: 1, LABEL: '' },
  maskable: { ROUND: 0, BORDERX: 0, BORDERW: 0, BORDERR: 0, BORDERS: 0, BORDERO: 0, SHIFTY: 262, SCALE: .78, LABEL: '' },
  admin: { ROUND: 112, BORDERX: 10, BORDERW: 492, BORDERR: 104, BORDERS: 6, BORDERO: .9, SHIFTY: 222, SCALE: .9, LABEL: label },
  adminfull: { ROUND: 0, BORDERX: 0, BORDERW: 0, BORDERR: 0, BORDERS: 0, BORDERO: 0, SHIFTY: 222, SCALE: .9, LABEL: label },
  adminmask: { ROUND: 0, BORDERX: 0, BORDERW: 0, BORDERR: 0, BORDERS: 0, BORDERO: 0, SHIFTY: 236, SCALE: .7, LABEL: label.replace('y="392"', 'y="372"').replace('y="429"', 'y="409"') },
};
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-proxy-server'] });
  const p = await b.newPage({ viewport: { width: 512, height: 512 } });
  for (const [name, v] of Object.entries(variants)) {
    let html = base;
    for (const [k, val] of Object.entries(v)) html = html.split(k).join(String(val));
    fs.writeFileSync(__dirname + '/v_' + name + '.html', html);
    await p.goto('file://' + __dirname + '/v_' + name + '.html');
    await p.evaluate(() => document.fonts.ready);
    await p.waitForTimeout(200);
    await p.locator('#s').screenshot({ path: __dirname + '/' + name + '.png', omitBackground: true });
  }
  await b.close();
})();
