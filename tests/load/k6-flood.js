import http from 'k6/http';
import { Counter } from 'k6/metrics';

const BASE = __ENV.BASE_URL;
const byStatus = {
  s200: new Counter('status_200'),
  s401: new Counter('status_401'),
  s429: new Counter('status_429'),
  other: new Counter('status_other'),
};

export const options = {
  insecureSkipTLSVerify: true,
  scenarios: {
    flood: {
      executor: 'constant-arrival-rate',
      rate: 300,
      timeUnit: '1s',
      duration: '10s',
      preAllocatedVUs: 50,
      maxVUs: 100,
    },
  },
  summaryTrendStats: ['avg', 'p(95)', 'max'],
};

export default function () {
  const r = http.get(`${BASE}/api/evidence?case_no=x`, {
    headers: { Authorization: `Bearer forged-${__VU}-${__ITER}` },
  });
  if (r.status === 200) byStatus.s200.add(1);
  else if (r.status === 401) byStatus.s401.add(1);
  else if (r.status === 429) byStatus.s429.add(1);
  else byStatus.other.add(1);
}
