import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

const BASE = __ENV.BASE_URL;
const INV = __ENV.TOKEN_INVESTIGATOR;
const AUD = __ENV.TOKEN_AUDITOR;
const PROFILE = __ENV.PROFILE || 'baseline';
const served = new Counter('served_by');

const profiles = {
  smoke: [{ duration: '30s', target: 5 }],
  baseline: [
    { duration: '30s', target: 20 },
    { duration: '2m', target: 20 },
    { duration: '30s', target: 0 },
  ],
  stress: [
    { duration: '1m', target: 50 },
    { duration: '1m', target: 100 },
    { duration: '1m', target: 200 },
    { duration: '30s', target: 0 },
  ],
};

export const options = {
  insecureSkipTLSVerify: true,
  stages: profiles[PROFILE],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{kind:read}': ['p(95)<300'],
    'http_req_duration{kind:write}': ['p(95)<800'],
  },
  summaryTrendStats: ['avg', 'p(50)', 'p(95)', 'p(99)', 'max'],
};

export function setup() {
  const ids = [];
  for (let i = 0; i < 20; i++) {
    const r = http.post(`${BASE}/api/evidence`, {
      case_no: `CASE-LOAD-${i % 4}`,
      title: `load seed ${i}`,
      file: http.file(`dummy-evidence-${i}-`.repeat(200), `seed-${i}.bin`),
    }, { headers: { Authorization: `Bearer ${INV}` }, tags: { kind: 'write' } });
    if (r.status === 201) ids.push(r.json('id'));
  }
  return { ids };
}

export default function (data) {
  const auth = (t) => ({ headers: { Authorization: `Bearer ${t}` } });
  const id = data.ids[Math.floor(Math.random() * data.ids.length)];
  const roll = Math.random();
  let r;
  if (roll < 0.6) {
    r = http.get(`${BASE}/api/evidence/${id}`, Object.assign(auth(INV), { tags: { kind: 'read' } }));
  } else if (roll < 0.85) {
    r = http.get(`${BASE}/api/evidence?case_no=CASE-LOAD-${id % 4}`, Object.assign(auth(AUD), { tags: { kind: 'read' } }));
  } else if (roll < 0.95) {
    r = http.get(`${BASE}/api/evidence/${id}/custody`, Object.assign(auth(AUD), { tags: { kind: 'read' } }));
  } else {
    r = http.post(`${BASE}/api/evidence`, {
      case_no: 'CASE-LOAD-W',
      title: 'load write',
      file: http.file('w'.repeat(4096), 'w.bin'),
    }, Object.assign(auth(INV), { tags: { kind: 'write' } }));
  }
  check(r, { 'status 2xx': (x) => x.status >= 200 && x.status < 300 });
  const node = r.headers['X-Served-By'];
  if (node) served.add(1, { node });
  sleep(0.2);
}
