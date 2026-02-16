#!/usr/bin/env python3
import subprocess
import json
import sys
import os
from pathlib import Path

import yaml


# -------------------------
# Constants
# -------------------------

CONFIG_PATH = "config.yaml"


# -------------------------
# Utilities
# -------------------------

def die(msg: str):
    print(f"[FATAL] {msg}", file=sys.stderr)
    sys.exit(1)


def run_rc_json(args: list[str]) -> dict:
    """
    Run rc command with --json and return parsed JSON.
    """
    cmd = ["rc"] + args + ["--json"]
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
    )

    if proc.returncode != 0:
        die(f"rc failed: {' '.join(cmd)}\n{proc.stderr}")

    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as e:
        die(f"Invalid JSON from rc: {e}\nOutput:\n{proc.stdout}")


def run_rc(args: list[str]):
    """
    Run rc command (no JSON expected).
    """
    cmd = ["rc"] + args
    proc = subprocess.run(cmd)

    if proc.returncode != 0:
        die(f"rc failed: {' '.join(cmd)}")


# -------------------------
# Load config
# -------------------------

def load_config() -> dict:
    path = Path(CONFIG_PATH)
    if not path.exists():
        die(f"Config file not found: {CONFIG_PATH}")

    with path.open() as f:
        return yaml.safe_load(f)


# -------------------------
# Alias handling (ROOT AK/SK)
# -------------------------

def alias_exists(alias: str) -> bool:
    data = run_rc_json(["alias", "list"])
    aliases = data.get("aliases", [])
    return any(a["name"] == alias for a in aliases)


def ensure_alias(alias: str, url: str):
    if alias_exists(alias):
        print(f"[SKIP] Alias exists: {alias}")
        return

    ak = os.getenv("RC_ROOT_ACCESS_KEY")
    sk = os.getenv("RC_ROOT_SECRET_KEY")

    if not ak or not sk:
        die("RC_ROOT_ACCESS_KEY / RC_ROOT_SECRET_KEY env vars not set")

    print(f"[CREATE] Alias: {alias} -> {url}")
    run_rc([
        "alias", "set",
        alias,
        url,
        ak,
        sk,
    ])


# -------------------------
# Observe current state
# -------------------------

def list_users(alias: str) -> set[str]:
    data = run_rc_json(["admin", "user", "list", f"{alias}"])
    return {u["access_key"] for u in data.get("users", [])}


def list_buckets(alias: str) -> set[str]:
    data = run_rc_json(["ls", f"{alias}"])
    return {item["key"].rstrip("/") for item in data.get("items", [])}


def list_policies(alias: str) -> set[str]:
    data = run_rc_json(["admin", "policy", "list", f"{alias}"])
    policies = data.get("policies", [])
    return {p["name"] if isinstance(p, dict) else str(p) for p in policies}


def policy_attached(alias: str, policy: str, user: str) -> bool:
    data = run_rc_json(["admin", "policy", "info", f"{alias}", policy])
    attached = data.get("attached_users", [])
    return user in attached


# -------------------------
# Ensure operations (ADD ONLY)
# -------------------------

def ensure_policy(alias: str, name: str, file_path: str, existing: set[str]):
    if name in existing:
        print(f"[SKIP] Policy exists: {name}")
        return

    if not Path(file_path).exists():
        die(f"Policy file not found: {file_path}")

    print(f"[CREATE] Policy: {name}")
    run_rc([
        "admin", "policy", "create",
        f"{alias}",
        name,
        file_path,
    ])


def ensure_user(alias: str, user: dict, existing: set[str]):
    name = user["name"]

    if name in existing:
        print(f"[SKIP] User exists: {name}")
        return

    print(f"[CREATE] User: {name}")
    run_rc([
        "admin", "user", "add",
        f"{alias}/",
        name,
        user["secret"],
    ])


def ensure_bucket(alias: str, name: str, existing: set[str]):
    if name in existing:
        print(f"[SKIP] Bucket exists: {name}")
        return

    print(f"[CREATE] Bucket: {name}")
    run_rc([
        "mb",
        f"{alias}/{name}",
    ])


def ensure_policy_attachment(alias: str, user: str, policy: str):
    if policy_attached(alias, policy, user):
        print(f"[SKIP] Policy {policy} already attached to {user}")
        return

    print(f"[ATTACH] Policy {policy} -> {user}")
    run_rc([
        "admin", "policy", "attach",
        f"{alias}/",
        policy,
        "--user",
        user,
    ])


# -------------------------
# Main
# -------------------------

def main():
    cfg = load_config()

    endpoint = cfg["endpoint"]
    alias = endpoint["alias"]
    url = endpoint["url"]

    print("== Ensure alias (create-only) ==")
    ensure_alias(alias, url)

    print("== Observing current state ==")
    existing_users = list_users(alias)
    existing_buckets = list_buckets(alias)
    existing_policies = list_policies(alias)

    print("== Ensure policies (create-only) ==")
    for name, policy in cfg.get("policies", {}).items():
        ensure_policy(
            alias,
            name,
            policy["file"],
            existing_policies,
        )

    print("== Ensure users (create-only) ==")
    for user in cfg.get("users", []):
        ensure_user(alias, user, existing_users)

        for policy in user.get("policies", []):
            ensure_policy_attachment(alias, user["name"], policy)

    print("== Ensure buckets (create-only) ==")
    for bucket in cfg.get("buckets", []):
        ensure_bucket(alias, bucket["name"], existing_buckets)

    print("== Bootstrap completed safely (ADD-ONLY) ==")


if __name__ == "__main__":
    main()
