// Weekly performance baseline for the staging environment.
//
// Staging runs a single small replica, so the thresholds below are trend
// guards (did this release regress vs. last week?), not capacity numbers.
// Keep the load gentle: the goal is a stable, comparable signal.
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.K6_BASE_URL || 'https://staging.volt-app.dev';

export const options = {
  scenarios: {
    baseline: {
      executor: 'constant-vus',
      vus: 5,
      duration: '2m',
    },
  },
  thresholds: {
    // Fail the run if these regress; tune after a few weeks of baselines.
    'http_req_duration{endpoint:health}': ['p(95)<300'],
    'http_req_failed{endpoint:health}': ['rate<0.02'],
  },
};

// Runs once before the VUs start iterating (not once per VU/iteration).
// /api/auth/* is rate-limited server-side (60 req/min, burst 20 per IP -
// see nginx.conf) to block brute-force login attempts. Calling it from
// every VU on every iteration looks identical to that attack pattern and
// gets throttled with 503s - this just proves the auth path is wired up,
// once, well inside that budget.
export function setup() {
  const config = http.get(`${BASE_URL}/api/auth/config`, {
    tags: { endpoint: 'auth-config' },
  });
  check(config, { 'auth config is 200': (r) => r.status === 200 });

  // DB-backed path: a rejected login exercises ingress -> backend ->
  // DocumentDB. 400/401 is the expected (passing) outcome.
  const login = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ email: 'k6-perf@example.com', password: 'wrong-on-purpose' }),
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'login' },
      responseCallback: http.expectedStatuses(200, 400, 401),
    },
  );
  check(login, { 'login answered by DB (not 5xx)': (r) => r.status < 500 });
}

// Sustained load target: only /api/health is safe to hammer repeatedly,
// since it's the only endpoint here that isn't behind the auth rate limiter.
export default function () {
  const health = http.get(`${BASE_URL}/api/health`, {
    tags: { endpoint: 'health' },
  });
  check(health, { 'health is 200': (r) => r.status === 200 });

  sleep(1);
}
