#!/usr/bin/env bash
set -euo pipefail

INSTANCE_ID="maicroverse"
INSTANCE_KEY="maicrog2a"
REPO_TARBALL_URL="https://github.com/bloxez/maicroverse/archive/refs/heads/main.tar.gz"
REPO_BRANCH="main"

MAICRO_CLI_CONFIG="${MAICRO_CLI_CONFIG:-/tmp/maicro-cli.config.json}"
export MAICRO_CLI_CONFIG

log() {
  printf "[create-mv] %s\n" "$*"
}

fail() {
  printf "[create-mv] ERROR: %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

escape_graphql_string() {
  local s
  s="$(cat)"
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "${s}"
}

resolve_mc_cmd() {
  command -v maicro-cli >/dev/null 2>&1 && {
    MC=(maicro-cli)
    return
  }

  fail "maicro-cli was not found in this runtime. Run this inside the maicro container shell."
}

mc_run() {
  "${MC[@]}" "$@"
}

ensure_project() {
  local create_output

  set +e
  create_output="$(mc_run project create --id "${INSTANCE_ID}" --key "${INSTANCE_KEY}" 2>&1)"
  local create_rc=$?
  set -e

  if [[ ${create_rc} -eq 0 ]]; then
    log "Created instance '${INSTANCE_ID}'."
  elif printf '%s' "${create_output}" | grep -qiE "already exists|duplicate|exists"; then
    log "Instance '${INSTANCE_ID}' already exists. Continuing."
  else
    printf '%s\n' "${create_output}" >&2
    fail "Could not create instance '${INSTANCE_ID}'."
  fi

  mc_run project set-key --id "${INSTANCE_ID}" --key "${INSTANCE_KEY}" >/dev/null
  mc_run config default-instance --action set --project "${INSTANCE_ID}" >/dev/null || true
  log "Configured local CLI key/default instance for '${INSTANCE_ID}'."
}

read_openrouter_key() {
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    OPENROUTER_API_KEY_VALUE="${OPENROUTER_API_KEY}"
    return
  fi

  while true; do
    IFS= read -r -s -p "Enter OPENROUTER_API_KEY: " OPENROUTER_API_KEY_VALUE
    printf "\n"

    if [[ -n "${OPENROUTER_API_KEY_VALUE}" ]]; then
      break
    fi

    printf "[create-mv] OPENROUTER_API_KEY cannot be empty.\n"
  done
}

sync_courses() {
  local source_root="$1"
  local courses_root="${source_root}/courses"

  [[ -d "${courses_root}" ]] || fail "Missing courses folder in cloned repository."

  log "Syncing courses -> scripts/courses (create or overwrite)."

  while IFS= read -r -d '' dir; do
    local rel="${dir#"${courses_root}/"}"
    [[ "${rel}" == "${dir}" ]] && continue
    [[ -z "${rel}" ]] && continue
    mc_run script mkdir --project "${INSTANCE_ID}" --path "scripts/courses/${rel}" >/dev/null 2>&1 || true
  done < <(find "${courses_root}" -type d -print0)

  local count=0
  while IFS= read -r -d '' file; do
    local rel="${file#"${courses_root}/"}"
    mc_run script upload --project "${INSTANCE_ID}" --path "scripts/courses/${rel}" --file "${file}" >/dev/null
    count=$((count + 1))
  done < <(find "${courses_root}" -type f -print0)

  log "Synced ${count} course file(s)."
}

sync_file_storage() {
  local source_root="$1"
  local storage_root="${source_root}/file_storage"

  [[ -d "${storage_root}" ]] || fail "Missing file_storage folder in cloned repository."

  log "Syncing file_storage -> maicroverse/* (overwrite enabled)."
  local count=0

  while IFS= read -r -d '' file; do
    local rel="${file#"${storage_root}/"}"
    local remote_path="maicroverse/${rel}"
    mc_run file upload --project "${INSTANCE_ID}" --file "${file}" --path "${remote_path}" --overwrite >/dev/null
    count=$((count + 1))
  done < <(find "${storage_root}" -type f -print0)

  log "Synced ${count} storage file(s)."
}

load_config_sections() {
  PROVIDERS_JSON='{"openrouter":{"enabled":true,"baseUrl":"https://openrouter.ai/api/v1","apiKeySecretName":"OPENROUTER_API_KEY"}}'
  MODELS_JSON='{"vision":{"provider":"openrouter","model":"google/gemma-4-26b-a4b-it","cost_prompt":0.06,"cost_completion":0.33,"pricing_source":"openrouter","pricing_fetched_at":"2026-07-10"},"ocr":{"provider":"openrouter","model":"google/gemma-4-26b-a4b-it","cost_prompt":0.06,"cost_completion":0.33,"pricing_source":"openrouter","pricing_fetched_at":"2026-07-10"},"embedding":{"provider":"openrouter","model":"openai/text-embedding-3-small","dimensions":1536,"cost_prompt":0.02,"cost_completion":0,"pricing_source":"openrouter","pricing_fetched_at":"2026-06-17"},"completion":{"provider":"openrouter","model":"google/gemma-4-26b-a4b-it","cost_prompt":0.06,"cost_completion":0.33,"pricing_source":"openrouter","pricing_fetched_at":"2026-07-10"},"transcribe":{"provider":"openrouter","model":"openai/whisper-1","cost_prompt":6,"cost_completion":0,"pricing_source":"openrouter","pricing_fetched_at":"2026-06-17","cost_audio_per_minute":0.006}}'
}

configure_openrouter() {
  local secret_mutation
  secret_mutation="mutation { SecretUpdate(key: \"OPENROUTER_API_KEY\", value: \"\"\"${OPENROUTER_API_KEY_VALUE}\"\"\", service: \"OpenRouter\", description: \"AI models\") }"
  mc_run gql run --project "${INSTANCE_ID}" --gql "${secret_mutation}" >/dev/null
  log "Stored OPENROUTER_API_KEY in instance secrets."

  local maiql_json config_mutation
  maiql_json="{\"providers\":${PROVIDERS_JSON},\"models\":${MODELS_JSON}}"
  config_mutation="mutation { ConfigOptionSet(key: \"maiql\", value: \"\"\"${maiql_json}\"\"\") }"

  mc_run gql run --project "${INSTANCE_ID}" --gql "${config_mutation}" >/dev/null
  log "Updated 'maiql.providers' and 'maiql.models' in instance config."
}

main() {
  require_cmd curl
  require_cmd tar
  require_cmd find
  require_cmd awk
  resolve_mc_cmd

  : "${ROOT_INSTANCE:?ROOT_INSTANCE is required in this runtime}"
  : "${ROOT_KEY:?ROOT_KEY is required in this runtime}"

  log "Using CLI command: ${MC[*]}"

  log "Checking backend health and auto-detecting base URL if needed."
  mc_run system health >/dev/null

  ensure_project
  read_openrouter_key
  load_config_sections

  local tmpdir archive_path source_root
  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" EXIT

  archive_path="${tmpdir}/maicroverse.tar.gz"
  log "Downloading ${REPO_BRANCH} archive from ${REPO_TARBALL_URL}."
  curl -fsSL "${REPO_TARBALL_URL}" -o "${archive_path}"
  tar -xzf "${archive_path}" -C "${tmpdir}"

  source_root="$(find "${tmpdir}" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [[ -n "${source_root}" ]] || fail "Could not resolve extracted repository folder."

  sync_courses "${source_root}"
  sync_file_storage "${source_root}"
  configure_openrouter

  log "Completed. Instance '${INSTANCE_ID}' is ready."
}

main "$@"