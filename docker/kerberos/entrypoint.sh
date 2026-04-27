#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[kerberos] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    fail "$name must not be empty"
  fi
}

trim() {
  local value="$*"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

realm_principal() {
  local principal
  principal="$(trim "$1")"
  [ -n "$principal" ] || return 1
  if [[ "$principal" == *@* ]]; then
    printf '%s' "$principal"
  else
    printf '%s@%s' "$principal" "$KRB5_REALM"
  fi
}

principal_without_realm() {
  local principal="$1"
  printf '%s' "${principal%@*}"
}

keytab_name() {
  local principal="$1"
  principal="$(principal_without_realm "$principal")"
  principal="${principal//\//_}"
  principal="${principal//:/_}"
  principal="${principal//@/_}"
  principal="${principal// /_}"
  printf '%s.keytab' "$principal"
}

password_for() {
  local principal="$1"
  local kind="$2"
  local short
  short="$(principal_without_realm "$principal")"

  if [ -n "${KRB5_PASSWORD_MAP:-}" ]; then
    while IFS= read -r line; do
      line="$(trim "$line")"
      [ -n "$line" ] || continue
      [[ "$line" = \#* ]] && continue
      local key="${line%%=*}"
      local value="${line#*=}"
      key="$(trim "$key")"
      value="$(trim "$value")"
      if [ "$key" = "$principal" ] || [ "$key" = "$short" ]; then
        printf '%s' "$value"
        return 0
      fi
    done <<< "$KRB5_PASSWORD_MAP"
  fi

  if [ "$kind" = "client" ] && [ -n "${KRB5_CLIENT_PASSWORD:-}" ]; then
    printf '%s' "$KRB5_CLIENT_PASSWORD"
    return 0
  fi

  if [ "$kind" = "service" ] && [ -n "${KRB5_SERVICE_PASSWORD:-}" ]; then
    printf '%s' "$KRB5_SERVICE_PASSWORD"
    return 0
  fi

  printf '%s' "$KRB5_DEFAULT_PASSWORD"
}

principal_exists() {
  local principal="$1"
  kadmin.local -q "getprinc $principal" 2>/dev/null | grep -q "^Principal: $principal"
}

ensure_principal() {
  local principal="$1"
  local password="$2"

  if principal_exists "$principal"; then
    log "principal exists: $principal"
    if [ "${KRB5_RESET_EXISTING_PASSWORDS,,}" = "true" ]; then
      log "resetting password: $principal"
      kadmin.local -q "cpw -pw $password $principal" >/dev/null
    fi
  else
    log "creating principal: $principal"
    kadmin.local -q "addprinc -pw $password $principal" >/dev/null
  fi
}

export_keytab() {
  local principal="$1"
  local file="$KRB5_KEYTAB_DIR/$(keytab_name "$principal")"

  log "exporting keytab: $file"
  rm -f "$file"
  kadmin.local -q "ktadd -norandkey -k $file $principal" >/dev/null
  chmod 0640 "$file"

  if [ "${KRB5_GENERATE_COMBINED_KEYTAB,,}" = "true" ]; then
    kadmin.local -q "ktadd -norandkey -k $KRB5_KEYTAB_DIR/all.keytab $principal" >/dev/null
    chmod 0640 "$KRB5_KEYTAB_DIR/all.keytab"
  fi
}

for_each_csv() {
  local values="$1"
  local kind="$2"
  local item principal password

  [ -n "$(trim "$values")" ] || return 0
  IFS=',' read -ra items <<< "$values"
  for item in "${items[@]}"; do
    item="$(trim "$item")"
    [ -n "$item" ] || continue
    principal="$(realm_principal "$item")"
    password="$(password_for "$principal" "$kind")"
    ensure_principal "$principal" "$password"
    export_keytab "$principal"
  done
}

render_config() {
  export KRB5_REALM KRB5_DOMAIN KRB5_KDC_HOST KRB5_ADMIN_SERVER
  envsubst < /opt/kerberos/templates/krb5.conf.template > /etc/krb5.conf
  envsubst < /opt/kerberos/templates/kdc.conf.template > /etc/krb5kdc/kdc.conf
  printf '*/admin@%s *\n' "$KRB5_REALM" > /etc/krb5kdc/kadm5.acl

  mkdir -p "$KRB5_EXPORT_CONFIG_DIR"
  cp /etc/krb5.conf "$KRB5_EXPORT_CONFIG_DIR/krb5.conf"
  cp /etc/krb5kdc/kdc.conf "$KRB5_EXPORT_CONFIG_DIR/kdc.conf"
}

initialize_database() {
  if [ -f /var/lib/krb5kdc/principal ]; then
    log "KDC database already exists"
    return 0
  fi

  log "creating KDC database for realm $KRB5_REALM"
  kdb5_util create -s -r "$KRB5_REALM" -P "$KRB5_MASTER_PASSWORD"
}

main() {
  KRB5_ADMIN_PASSWORD="${KRB5_ADMIN_PASSWORD:-admin}"
  KRB5_DEFAULT_PASSWORD="${KRB5_DEFAULT_PASSWORD:-changeme}"
  KRB5_CLIENT_PASSWORD="${KRB5_CLIENT_PASSWORD:-}"
  KRB5_SERVICE_PASSWORD="${KRB5_SERVICE_PASSWORD:-}"
  KRB5_PASSWORD_MAP="${KRB5_PASSWORD_MAP:-}"
  KRB5_MASTER_PASSWORD="${KRB5_MASTER_PASSWORD:-$KRB5_ADMIN_PASSWORD}"
  KRB5_RESET_EXISTING_PASSWORDS="${KRB5_RESET_EXISTING_PASSWORDS:-false}"

  require_env KRB5_REALM
  require_env KRB5_DOMAIN
  require_env KRB5_KDC_HOST
  require_env KRB5_ADMIN_SERVER
  require_env KRB5_ADMIN_PRINCIPAL
  require_env KRB5_ADMIN_PASSWORD
  require_env KRB5_DEFAULT_PASSWORD

  mkdir -p "$KRB5_KEYTAB_DIR" "$KRB5_EXPORT_CONFIG_DIR" /var/log/kerberos
  rm -f "$KRB5_KEYTAB_DIR/all.keytab"

  render_config
  initialize_database

  ensure_principal "$(realm_principal "$KRB5_ADMIN_PRINCIPAL")" "$KRB5_ADMIN_PASSWORD"
  for_each_csv "$KRB5_CLIENT_PRINCIPALS" client
  for_each_csv "$KRB5_SERVICE_PRINCIPALS" service

  log "starting krb5kdc"
  krb5kdc -n &
  kdc_pid="$!"

  log "starting kadmind"
  kadmind -nofork &
  kadmind_pid="$!"

  trap 'kill "$kdc_pid" "$kadmind_pid" 2>/dev/null || true; wait' INT TERM
  wait -n "$kdc_pid" "$kadmind_pid"
}

main "$@"
