Built on GitHub CI by `.github/workflows/docker-bump.yml` — push an empty
commit to `gh-pages` with the bump message:

```shell
git commit --allow-empty -m "bump(docker): docker/jenkins-build-agent"
git push
```

The workflow auto-increments the `0.1.x` tag on
`ghcr.io/openprojectx/jenkins-build-agent` (and moves `latest`). Downloaded
artifacts (Temurin / Node tarballs) are cached across runs via the
`/var/cache/downloads` BuildKit cache mount + `actions/cache`; image layers
are cached in the `-cache:latest` registry ref.

Node patch versions are pinned as `ARG NODE22_VERSION` / `NODE24_VERSION` in
the Dockerfile — edit them to bump. Bun is pinned as `ARG BUN_VERSION` (the
binary zip is fetched from the oven-sh/bun GitHub release). JDK 17/21 pull the
latest Temurin GA patch when not already cached; JDK 25 comes from the
`jenkins/inbound-agent:trixie-jdk25` base tag.

To use it, point the pod template's jnlp container at this image (k8s-infra:
`jenkins.agent.longRunning` state values) — the `jdk17`/`jdk21` sidecar
containers and the ci.yaml `container:` option are then no longer needed.

For Testcontainers, the image starts an internal Docker daemon on
`unix:///var/run/docker.sock` before launching the Jenkins inbound agent. The
agent pod must run the container as root with `privileged: true`; otherwise
`JENKINS_AGENT_DIND=true` is ignored and the Jenkins agent still starts
without Docker-in-Docker. Set `JENKINS_AGENT_DIND=false` to disable the daemon
explicitly.
