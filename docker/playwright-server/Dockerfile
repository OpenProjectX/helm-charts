# syntax=docker/dockerfile:1.7

ARG PLAYWRIGHT_VERSION=1.62.1
FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}

ARG PLAYWRIGHT_VERSION

LABEL org.opencontainers.image.title="Playwright server" \
      org.opencontainers.image.description="Offline-ready Playwright browser server with the matching npm package and browsers" \
      org.opencontainers.image.source="https://github.com/OpenProjectX/openprojectx-helm-charts"

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    NODE_ENV=production

USER root

# The upstream image contains browser binaries and native dependencies, but it
# intentionally does not contain the Playwright npm package or run-server CLI.
# Install the exactly matching package while the image is being built.
RUN npm install --global --omit=dev --no-audit --no-fund \
      "playwright@${PLAYWRIGHT_VERSION}" \
    && npm cache clean --force

# Build-time proof that the runtime CLI no longer needs npm or network access.
RUN --network=none playwright --version \
    && find /ms-playwright -maxdepth 1 -type d -name 'chromium-*' -print -quit \
      | grep -q .

USER pwuser
WORKDIR /home/pwuser

EXPOSE 3000

ENTRYPOINT ["playwright", "run-server"]
CMD ["--host", "0.0.0.0", "--port", "3000"]
