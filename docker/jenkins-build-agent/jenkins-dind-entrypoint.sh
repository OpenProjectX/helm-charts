#!/bin/sh
set -eu

: "${JENKINS_AGENT_DIND:=true}"
: "${DOCKER_HOST:=unix:///var/run/docker.sock}"
: "${DOCKER_TLS_CERTDIR:=}"
: "${TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE:=/var/run/docker.sock}"

export DOCKER_HOST DOCKER_TLS_CERTDIR TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE

if [ "$JENKINS_AGENT_DIND" != "false" ]; then
	if [ "$(id -u)" != "0" ]; then
		echo >&2 "warning: JENKINS_AGENT_DIND is enabled but the container is not running as root; skipping dockerd startup"
	else
		mkdir -p /var/lib/docker /var/run
		rm -f /var/run/docker.pid

		dockerd-entrypoint.sh dockerd ${JENKINS_AGENT_DOCKERD_ARGS:-} > /tmp/dockerd.log 2>&1 &
		dockerd_pid="$!"

		trap 'kill "$dockerd_pid" 2>/dev/null || true' INT TERM EXIT

		i=0
		until docker info > /dev/null 2>&1; do
			if ! kill -0 "$dockerd_pid" 2>/dev/null; then
				echo >&2 "dockerd exited before becoming ready"
				cat >&2 /tmp/dockerd.log || true
				exit 1
			fi
			i=$((i + 1))
			if [ "$i" -gt 60 ]; then
				echo >&2 "timed out waiting for dockerd"
				cat >&2 /tmp/dockerd.log || true
				exit 1
			fi
			sleep 1
		done

		echo "dockerd is ready"
	fi
fi

exec /usr/local/bin/jenkins-agent "$@"
