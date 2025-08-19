#!/usr/bin/env bash
# ct-update-all.sh — Update packages in all (or running) LXC containers on this Proxmox node.
# Supports Debian/Ubuntu (apt), RHEL/Fedora (dnf), Alpine (apk), and Arch (pacman).
# Usage:
#   ./ct-update-all.sh                  # update all RUNNING CTs, sequential
#   ./ct-update-all.sh --all            # include STOPPED CTs (will be skipped if not running)
#   ./ct-update-all.sh --parallel 3     # run up to 3 updates in parallel
#   ./ct-update-all.sh --exclude 101,105 # exclude specific CTIDs
#   ./ct-update-all.sh --yes            # no prompt
#   ./ct-update-all.sh --dry-run        # show what would run
set -euo pipefail

# --- Config / deps ---
SHARED_NAME="shared.sh"
SHARED_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/${SHARED_NAME}"

# === Default values when parameters are passed (configurable) ===
DEFAULT_INCLUDE_ALL=false   # true or false - include stopped containers by default
DEFAULT_PARALLEL=1          # 1-10 - number of parallel updates by default
DEFAULT_EXCLUDE=""          # comma-separated CTIDs to exclude by default (e.g., "101,105")
DEFAULT_DRY_RUN=false       # true or false - dry run mode by default

# shellcheck source=/dev/null
if [[ -f "./${SHARED_NAME}" ]]; then
  source "./${SHARED_NAME}"
else
  if command -v wget >/dev/null 2>&1; then
    source <(wget -qO- "${SHARED_URL}") || true
  elif command -v curl >/dev/null 2>&1; then
    source <(curl -fsSL "${SHARED_URL}") || true
  fi
fi

# Fallback minimal log funcs if shared.sh not loaded
print_title() { echo -e "\n==== $* ====\n"; }
log_step()    { echo -e "➡️  $*"; }
log_success() { echo -e "✅  $*"; }
log_warn()    { echo -e "⚠️  $*"; }
fatal_error() { echo -e "❌  $*"; exit 1; }

# --- Root check (needs pct) ---
if [[ "$(id -u)" -ne 0 ]]; then
  fatal_error "Run as root on a Proxmox node (pct required)."
fi
command -v pct >/dev/null 2>&1 || fatal_error "pct not found. Run on a Proxmox VE host."

# --- Args ---
INCLUDE_ALL=false
PARALLEL=1
EXCLUDE=""
ASSUME_YES=false
DRY_RUN=false
INTERACTIVE=true

# Store original arguments for checking what was explicitly set
ORIGINAL_ARGS="$*"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -a, --all            Include stopped CTs (they will be skipped at exec time if not running)
  -p, --parallel N     Run up to N containers in parallel (default: 1)
  -e, --exclude LIST   Comma-separated CTIDs to exclude (e.g., 101,105)
  -y, --yes            No interactive prompt
  -d, --dry-run        Show what would run without executing
  -h, --help           Show this help

Behavior:
  - NO PARAMETERS: Interactive mode - prompts for each option
  - ANY PARAMETER: Uses defaults for unspecified options (see defaults at top of script)

Current defaults when parameters are used:
  - Include stopped: $DEFAULT_INCLUDE_ALL
  - Parallel jobs: $DEFAULT_PARALLEL
  - Exclude CTIDs: ${DEFAULT_EXCLUDE:-none}
  - Dry run: $DEFAULT_DRY_RUN

Examples:
  $(basename "$0")                  # Interactive mode (asks for each option)
  $(basename "$0") -y               # Use all defaults, no prompts
  $(basename "$0") -p 3             # 3 parallel jobs, other defaults apply
  $(basename "$0") -e 101,105       # Exclude specific CTs, other defaults apply
  $(basename "$0") -a -p 2 -y       # Include all CTs, 2 parallel jobs, no prompts
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--all) INCLUDE_ALL=true; INTERACTIVE=false; shift;;
    -p|--parallel) PARALLEL="${2:-1}"; INTERACTIVE=false; shift 2;;
    -e|--exclude) EXCLUDE="${2:-}"; INTERACTIVE=false; shift 2;;
    -y|--yes) ASSUME_YES=true; INTERACTIVE=false; shift;;
    -d|--dry-run) DRY_RUN=true; INTERACTIVE=false; shift;;
    -h|--help) usage; exit 0;;
    *) log_warn "Unknown arg: $1"; usage; exit 1;;
  esac
done

# === Apply defaults when parameters are used but specific options not explicitly set ===
if [[ "$INTERACTIVE" == "false" ]]; then
  # Only apply defaults if the values weren't explicitly set via command line
  if [[ "$INCLUDE_ALL" == "false" ]] && ! [[ "$ORIGINAL_ARGS" =~ -a|--all ]]; then
    INCLUDE_ALL="$DEFAULT_INCLUDE_ALL"
  fi
  if [[ "$PARALLEL" == "1" ]] && ! [[ "$ORIGINAL_ARGS" =~ -p|--parallel ]]; then
    PARALLEL="$DEFAULT_PARALLEL"
  fi
  if [[ -z "$EXCLUDE" ]] && ! [[ "$ORIGINAL_ARGS" =~ -e|--exclude ]]; then
    EXCLUDE="$DEFAULT_EXCLUDE"
  fi
  if [[ "$DRY_RUN" == "false" ]] && ! [[ "$ORIGINAL_ARGS" =~ -d|--dry-run ]]; then
    DRY_RUN="$DEFAULT_DRY_RUN"
  fi
fi

# === Interactive prompts if no arguments provided ===
if [[ "$INTERACTIVE" == "true" ]]; then
  echo "🔧 Container Update Configuration"
  echo "Press Enter for defaults, or specify custom values:"
  echo

  # Ask about including stopped containers
  read -rp "Include stopped containers? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    INCLUDE_ALL=true
  fi

  # Ask about parallel execution
  read -rp "Number of parallel updates (1-10) [1]: " response
  if [[ "$response" =~ ^[0-9]+$ ]] && [[ "$response" -ge 1 ]] && [[ "$response" -le 10 ]]; then
    PARALLEL="$response"
  fi

  # Ask about exclusions
  read -rp "Exclude container IDs (comma-separated, e.g., 101,105) [none]: " response
  if [[ -n "$response" ]]; then
    EXCLUDE="$response"
  fi

  # Ask about dry run
  read -rp "Dry run (show what would be done without executing)? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    DRY_RUN=true
  fi

  echo
fi

print_title "PVE: Update All LXC Containers"

# --- Collect CTs ---
mapfile -t CT_ROWS < <(pct list | awk 'NR>1 {print $1":"$3}')
if [[ ${#CT_ROWS[@]} -eq 0 ]]; then
  log_warn "No containers found."
  exit 0
fi

# Exclusions
declare -A EXCL
IFS=',' read -r -a _ex <<< "${EXCLUDE}"
for e in "${_ex[@]}"; do [[ -n "${e}" ]] && EXCL["$e"]=1; done

# Filter by status
CT_IDS=()
for row in "${CT_ROWS[@]}"; do
  IFS=':' read -r id status <<< "$row"
  [[ -n "${EXCL[$id]:-}" ]] && continue
  if [[ "$INCLUDE_ALL" == "true" ]]; then
    CT_IDS+=("$id")
  else
    [[ "$status" == "running" ]] && CT_IDS+=("$id")
  fi
done

if [[ ${#CT_IDS[@]} -eq 0 ]]; then
  log_warn "No matching containers (check --all or --exclude)."
  exit 0
fi

log_step "Target containers:" "${CT_IDS[*]}"

# Prompt
if [[ "$ASSUME_YES" == "false" ]]; then
  read -rp "Proceed with updates on ${#CT_IDS[@]} container(s)? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { log_warn "Aborted."; exit 1; }
fi

# --- Update function ---
# Return codes:
#   0 success, 1 skipped (stopped/unknown), 2 failure
update_one() {
  local id="$1"
  local header="CT ${id}"

  # Is it running?
  local status
  status=$(pct status "$id" 2>/dev/null | awk '{print $2}')
  if [[ "$status" != "running" ]]; then
    log_warn "${header}: not running, skipping (use --all to include stopped)"
    return 1
  fi

  # Detect distro in CT
  local osid oslike
  if ! out=$(pct exec "$id" -- bash -lc '(. /etc/os-release >/dev/null 2>&1 || true; printf "%s|%s\n" "${ID:-}" "${ID_LIKE:-}")' 2>/dev/null); then
    log_warn "${header}: cannot detect OS, skipping"
    return 1
  fi
  osid="${out%%|*}"; oslike="${out#*|}"

  # Build command based on distro
  local cmd="export DEBIAN_FRONTEND=noninteractive; "
  if [[ "$osid" =~ (debian|ubuntu) ]] || [[ "$oslike" =~ (debian|ubuntu) ]]; then
    cmd+='apt update -y && apt full-upgrade -y && apt autoremove -y && apt clean -y && apt autoclean -y'
  elif pct exec "$id" -- bash -lc 'command -v dnf >/dev/null' >/dev/null 2>&1; then
    cmd+='dnf -y upgrade --refresh && dnf -y autoremove && dnf clean all'
  elif pct exec "$id" -- bash -lc 'test -f /etc/alpine-release' >/dev/null 2>&1; then
    cmd+='apk update && apk upgrade --no-cache'
  elif pct exec "$id" -- bash -lc 'command -v pacman >/dev/null' >/dev/null 2>&1; then
    cmd+='pacman -Syu --noconfirm'
  else
    log_warn "${header}: unsupported distro ($osid), skipping"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "${header}: would run -> ${cmd}"
    return 0
  fi

  log_step "${header}: starting updates..."
  if pct exec "$id" -- bash -lc "${cmd}"; then
    log_success "${header}: update complete"
    return 0
  else
    echo
    log_warn "${header}: update failed"
    return 2
  fi
}

# --- Execution loop with simple parallelism ---
SUCCESS=0; SKIPPED=0; FAILED=0
PIDS=()
declare -A PID2ID

run_job() {
  local id="$1"
  if [[ "$PARALLEL" -le 1 ]]; then
    if update_one "$id"; then ((SUCCESS++)); else rc=$?; [[ $rc -eq 1 ]] && ((SKIPPED++)) || ((FAILED++)); fi
  else
    ( update_one "$id"; echo "$?:$id" >/tmp/ctupd_${id}.$$ ) &
    PID=$!
    PIDS+=("$PID")
    PID2ID["$PID"]="$id"
  fi
}

for id in "${CT_IDS[@]}"; do
  # throttle
  while [[ "$PARALLEL" -gt 1 && "${#PIDS[@]}" -ge "$PARALLEL" ]]; do
    wait -n
    # harvest any finished job result files
    for f in /tmp/ctupd_* 2>/dev/null; do
      [[ -f "$f" ]] || continue
      rc="$(cut -d: -f1 "$f")"
      jid="$(cut -d: -f2 "$f")"
      rm -f "$f"
      if [[ "$rc" == "0" ]]; then ((SUCCESS++))
      elif [[ "$rc" == "1" ]]; then ((SKIPPED++))
      else ((FAILED++)); fi
    done
    # cleanup PIDs array
    tmp=(); for p in "${PIDS[@]}"; do kill -0 "$p" 2>/dev/null && tmp+=("$p"); done; PIDS=("${tmp[@]}")
  done
  run_job "$id"
done

# Wait remaining
if [[ "$PARALLEL" -gt 1 ]]; then
  wait || true
  for f in /tmp/ctupd_* 2>/dev/null; do
    [[ -f "$f" ]] || continue
    rc="$(cut -d: -f1 "$f")"
    jid="$(cut -d: -f2 "$f")"
    rm -f "$f"
    if [[ "$rc" == "0" ]]; then ((SUCCESS++))
    elif [[ "$rc" == "1" ]]; then ((SKIPPED++))
    else ((FAILED++)); fi
  done
fi

echo
print_title "Summary"
echo "Success: ${SUCCESS}"
echo "Skipped: ${SKIPPED}"
echo "Failed : ${FAILED}"

[[ "$FAILED" -gt 0 ]] && exit 2 || exit 0
