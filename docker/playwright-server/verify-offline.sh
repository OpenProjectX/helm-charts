#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: verify-offline.sh IMAGE}"

docker run --rm --network none --shm-size=1g \
  --entrypoint /bin/bash "$image" -ceu '
playwright run-server \
  --host 127.0.0.1 \
  --port 3000 \
  --path /smoke \
  < <(tail -f /dev/null) \
  >/tmp/playwright-server.log 2>&1 &
server_pid=$!
trap "kill $server_pid 2>/dev/null || true" EXIT

for attempt in $(seq 1 30); do
  if grep -q "Listening on" /tmp/playwright-server.log; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat /tmp/playwright-server.log
    exit 1
  fi
  sleep 1
done

grep "Listening on" /tmp/playwright-server.log
NODE_PATH=$(npm root --global) node -e "
const { chromium } = require(\"playwright\");
(async () => {
  const browser = await chromium.connect(\"ws://127.0.0.1:3000/smoke\");
  const page = await browser.newPage();
  await page.setContent(\"<h1>offline-ready</h1>\");
  const text = await page.textContent(\"h1\");
  if (text !== \"offline-ready\") throw new Error(\"Unexpected page content: \" + text);
  console.log(text);
  await browser.close();
})().catch(error => {
  console.error(error);
  process.exit(1);
});
"
'
