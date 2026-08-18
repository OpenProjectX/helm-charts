# Playwright server

Offline-ready Playwright server image. It combines the upstream Playwright
browser image with the exactly matching npm package and `run-server` CLI.

```shell
docker run --rm --init -i -p 3000:3000 \
  ghcr.io/openprojectx/playwright-server:latest
```

No npm or browser download occurs when the container starts. Network access is
only needed to pull the completed image and for websites opened by tests.

`verify-offline.sh` disables container networking, starts the server, connects
a Playwright client, launches Chromium, and renders a page.

To publish a new image, update `PLAYWRIGHT_VERSION` and commit with:

```text
bump(docker): docker/playwright-server
```
