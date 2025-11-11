import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 20 },   // ramp to 20 VUs
    { duration: '1m',  target: 200 },  // ramp to 200 VUs (adjust)
    { duration: '2m',  target: 200 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% < 500ms
    http_req_failed: ['rate<0.01'],
  },
};

const url = 'https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp';
const payload = JSON.stringify({"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}});
const params = {
  headers: {
    'Content-Type': 'application/json',
    'Ocp-Apim-Subscription-Key': 'f4ace77560b34bd4b84bf24bfe0dd35c',
  },
};

export default function () {
  const res = http.post(url, payload, params);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1); // virtual user wait; tune or remove for higher RPS
}
