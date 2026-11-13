// Live demo check: a student phone and the studio manager's laptop.
//
// 1. Resets the demo data (as the fictional administrator).
// 2. Opens the app in a browser as the studio manager.
// 3. "Phone" side (through the API, like the app does): Yasmine books,
//    Vie Étudiante approves level 1.
// 4. Checks the manager's screen updated by itself, then approves in the UI.
// 5. Checks forbidden actions fail on the server.
// Screenshots go to e2e/out/.
import { chromium } from 'playwright';
import fs from 'node:fs';

const URL = 'https://otywhgcmayylalzldjvw.supabase.co';
const KEY = 'sb_publishable_pkYJ6uY-C_KaT_0u5eZRIA_giFhtl2_';
const PASSWORD = 'Studio-Demo-2026!';
const APP = process.env.APP_URL ?? 'http://localhost:8080/';
fs.mkdirSync('e2e/out', { recursive: true });
const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'} · ${name}${detail ? ' · ' + detail : ''}`);
};

async function signIn(slug) {
  const r = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `${slug}@demo.euromed-studios.test`, password: PASSWORD }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error(`sign-in ${slug}: ${JSON.stringify(j)}`);
  return j.access_token;
}
async function rpc(token, fn, params = {}) {
  const r = await fetch(`${URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey: KEY, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(params),
  });
  const text = await r.text();
  return { ok: r.ok, status: r.status, body: text ? JSON.parse(text) : null };
}

// A free weekday ~10 weekdays ahead, 16:00–17:00 Casablanca (UTC+1).
function slot() {
  const d = new Date();
  let n = 0;
  while (n < 10) { d.setUTCDate(d.getUTCDate() + 1); const w = d.getUTCDay(); if (w !== 0 && w !== 6) n++; }
  const day = d.toISOString().slice(0, 10);
  return { start: `${day}T15:00:00Z`, end: `${day}T16:00:00Z` };
}

const admin = await signIn('idrissi');
check('reset demo as admin', (await rpc(admin, 'reset_demo')).ok);

const browser = await chromium.launch();
const laptop = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
laptop.on('pageerror', (e) => errors.push(e.message));
await laptop.goto(`${APP}?as=tazi#/validations`);
await laptop.waitForTimeout(12000);
await laptop.screenshot({ path: 'e2e/out/1-manager-before.png' });

const yasmine = await signIn('yasmine');
const s = slot();
const sent = await rpc(yasmine, 'submit_booking', {
  p_studio: 'montage', p_start: s.start, p_end: s.end, p_activity: 'editing',
  p_note: 'Montage du court-métrage de fin de semestre.',
});
check('student submits a booking', sent.ok, sent.ok ? sent.body.reference : JSON.stringify(sent.body));
const id = sent.body?.id;

const again = await rpc(await signIn('adam'), 'submit_booking', {
  p_studio: 'montage', p_start: s.start, p_end: s.end, p_activity: 'editing',
});
check('same slot is locked for others', !again.ok && String(again.body?.message).startsWith('slot_taken'), again.body?.message);

const self = await rpc(yasmine, 'approve_booking', { p_id: id });
check('student cannot approve', !self.ok && self.body?.message === 'not_allowed');

const patch = await fetch(`${URL}/rest/v1/bookings?id=eq.${id}`, {
  method: 'PATCH',
  headers: { apikey: KEY, Authorization: `Bearer ${yasmine}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
  body: JSON.stringify({ status: 'approved' }),
});
const patched = await patch.json().catch(() => []);
check('direct table edits are blocked', Array.isArray(patched) ? patched.length === 0 : !patch.ok);

const amrani = await signIn('amrani');
const l1 = await rpc(amrani, 'approve_booking', { p_id: id, p_comment: 'Validé par la Vie Étudiante.' });
check('level 1 approves', l1.ok && l1.body?.status === 'pendingStudio', l1.body?.status ?? JSON.stringify(l1.body));
const l1twice = await rpc(amrani, 'approve_booking', { p_id: id });
check('level 1 approver cannot give level 2', !l1twice.ok);

await laptop.waitForTimeout(4000);
await laptop.screenshot({ path: 'e2e/out/2-manager-live-update.png' });

// Approve in the manager's UI (Flutter exposes its accessibility tree).
try {
  await laptop.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await laptop.waitForTimeout(2000);
  fs.writeFileSync('e2e/out/semantics.txt',
    (await laptop.locator('flt-semantics[role], [aria-label]').evaluateAll(
      (els) => els.map((e) => `${e.getAttribute('role')} | ${e.getAttribute('aria-label') ?? e.textContent}`).join('\n'))));
  await laptop.getByRole('button', { name: /Espace Montage/ }).first().click();
  await laptop.waitForTimeout(1500);
  await laptop.getByRole('button', { name: /Valider la séance/ }).first().click();
  await laptop.waitForTimeout(1200);
  await laptop.screenshot({ path: 'e2e/out/3-manager-confirm.png' });
  await laptop.getByRole('button', { name: /Valider la séance/ }).last().click();
  await laptop.waitForTimeout(4000);
  await laptop.screenshot({ path: 'e2e/out/4-manager-after.png' });
} catch (e) {
  check('manager clicks through the UI', false, e.message.split('\n')[0]);
}

const mine = await fetch(`${URL}/rest/v1/bookings?id=eq.${id}&select=status,history`, {
  headers: { apikey: KEY, Authorization: `Bearer ${yasmine}` },
}).then((r) => r.json());
check('student sees the final status', mine[0]?.status === 'approved', mine[0]?.status);

const phone = await browser.newPage({ viewport: { width: 390, height: 844 } });
await phone.goto(`${APP}?as=yasmine#/bookings`);
await phone.waitForTimeout(12000);
await phone.screenshot({ path: 'e2e/out/5-student-phone.png' });

check('no app errors in the browser', errors.length === 0, errors.slice(0, 3).join(' | '));
await browser.close();
fs.writeFileSync('e2e/out/results.json', JSON.stringify(results, null, 2));
// Leave the demo clean for the next viewer.
await rpc(admin, 'reset_demo');
if (results.some((r) => !r.ok)) process.exit(1);
