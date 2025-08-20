#!/usr/bin/env bash
# ct-executor.sh — Execute any ct-script across multiple LXC containers.
# Usage:
#   ./ct-executor.sh ct-update.sh                 # run ct-update.sh on all running containers
#   ./ct-executor.sh ct-update.sh --all           # include stopped containers
#   ./ct-executor.sh ct-bootstrap.sh -n web       # run ct-bootstrap.sh with args on all containers
#   ./ct-executor.sh ct-update.sh --parallel 3    # run on up to 3 containers in parallel
#   ./ct-executor.sh ct-update.sh --exclude 101,105 # exclude specific CTIDs
#   ./ct-executor.sh ct-update.sh --include 101,105 # only include specific CTIDs
set -euo pipefail

# --- Config / deps ---
CORE_LIB_URL="https://raw.githubusercontent.com/poziel/pve-scripts/refs/heads/main/lib/core.sh"
CT_SCRIPTS_DIR="./ct-scripts"

# === Default values when parameters are passed (configurable) ===
DEFAULT_INCLUDE_ALL=false   # true or false - include stopped containers by default
DEFAULT_PARALLEL=1          # 1-10 - number of parallel executions by default
DEFAULT_EXCLUDE=""          # comma-separated CTIDs to exclude by default (e.g., "101,105")
DEFAULT_INCLUDE=""          # comma-separated CTIDs to include only (e.g., "101,105")

# Load core library (contains logging and use_lib function)
if [[ -f "./lib/core.sh" ]]; then
  source "./lib/core.sh"
else
  if command -v wget >/dev/null 2>&1; then
    source <(wget -qO- "${CORE_LIB_URL}") || {
      echo "❌ Failed to load core library from ${CORE_LIB_URL}"
      exit 1
    }
  elif command -v curl >/dev/null 2>&1; then
    source <(curl -fsSL "${CORE_LIB_URL}") || {
      echo "❌ Failed to load core library from ${CORE_LIB_URL}"
      exit 1
    }
  else
    echo "❌ Core library not found and neither wget nor curl available"
    exit 1
  fi
fi

# Load additional libraries as needed
use_lib "ui"         # For print_title function
use_lib "validation" # For validation functions

# Parse arguments first to handle --help before root checks
if [[ $# -eq 0 ]]; then
  usage() {
    cat <<EOF
Usage: $(basename "$0") <script_name> [script_args...] [executor_options]

Executor Options:
  -a, --all            Include stopped containers (default: $DEFAULT_INCLUDE_ALL)
  -p, --parallel N     Run up to N containers in parallel (default: $DEFAULT_PARALLEL)
  -e, --exclude LIST   Comma-separated CTIDs to exclude (e.g., 101,105)
  -i, --include LIST   Comma-separated CTIDs to include only (e.g., 101,105)
  -y, --yes            Skip confirmation prompt
  -d, --dry-run        Show what would be executed without running
  -h, --help           Show this help

Script Arguments:
  Any arguments before executor options will be passed to the script.
  Use -- to separate script args from executor options if needed.

Behavior:
  - NO PARAMETERS: Show usage
  - SCRIPT + NO EXECUTOR OPTIONS: Interactive mode - prompts for each option
  - SCRIPT + ANY EXECUTOR OPTION: Uses defaults for unspecified options

Current defaults when executor options are used:
  - Include stopped: $DEFAULT_INCLUDE_ALL
  - Parallel jobs: $DEFAULT_PARALLEL
  - Exclude CTIDs: ${DEFAULT_EXCLUDE:-none}
  - Include CTIDs: ${DEFAULT_INCLUDE:-all}

Available Scripts:
$(find "$CT_SCRIPTS_DIR" -name "*.sh" -type f -printf "  %f\n" 2>/dev/null | sort || echo "  (ct-scripts directory not found)")

Examples:
  $(basename "$0") ct-update.sh                    # Interactive mode
  $(basename "$0") ct-update.sh -y                 # Update all running CTs
  $(basename "$0") ct-update.sh -p 3 -a            # Parallel on all CTs
  $(basename "$0") ct-update.sh -e 101,105         # Exclude specific CTs
  $(basename "$0") ct-update.sh -i 101,105         # Only specific CTs
  $(basename "$0") ct-bootstrap.sh -n web1 -- -p 2 # Script args + executor options
  $(basename "$0") ct-update.sh --dry-run -d       # Script with dry-run + executor dry-run
EOF
  }
  usage
  exit 1
fi

# Check for help flag before other validations
for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    usage() {
      cat <<EOF
Usage: $(basename "$0") <script_name> [script_args...] [executor_options]

Executor Options:
  -a, --all            Include stopped containers (default: $DEFAULT_INCLUDE_ALL)
  -p, --parallel N     Run up to N containers in parallel (default: $DEFAULT_PARALLEL)
  -e, --exclude LIST   Comma-separated CTIDs to exclude (e.g., 101,105)
  -i, --include LIST   Comma-separated CTIDs to include only (e.g., 101,105)
  -y, --yes            Skip confirmation prompt
  -d, --dry-run        Show what would be executed without running
  -h, --help           Show this help

Script Arguments:
  Any arguments before executor options will be passed to the script.
  Use -- to separate script args from executor options if needed.

Behavior:
  - NO PARAMETERS: Show usage
  - SCRIPT + NO EXECUTOR OPTIONS: Interactive mode - prompts for each option
  - SCRIPT + ANY EXECUTOR OPTION: Uses defaults for unspecified options

Current defaults when executor options are used:
  - Include stopped: $DEFAULT_INCLUDE_ALL
  - Parallel jobs: $DEFAULT_PARALLEL
  - Exclude CTIDs: ${DEFAULT_EXCLUDE:-none}
  - Include CTIDs: ${DEFAULT_INCLUDE:-all}

Available Scripts:
$(find "$CT_SCRIPTS_DIR" -name "*.sh" -type f -printf "  %f\n" 2>/dev/null | sort || echo "  (ct-scripts directory not found)")

Examples:
  $(basename "$0") ct-update.sh                    # Interactive mode
  $(basename "$0") ct-update.sh -y                 # Update all running CTs
  $(basename "$0") ct-update.sh -p 3 -a            # Parallel on all CTs
  $(basename "$0") ct-update.sh -e 101,105         # Exclude specific CTs
  $(basename "$0") ct-update.sh -i 101,105         # Only specific CTs
  $(basename "$0") ct-bootstrap.sh -n web1 -- -p 2 # Script args + executor options
  $(basename "$0") ct-update.sh --dry-run -d       # Script with dry-run + executor dry-run
EOF
    }
    usage
    exit 0
  fi
done

# --- Root check (needs pct) ---
if [[ "$(id -u)" -ne 0 ]]; then
  fatal_error "Run as root on a Proxmox node (pct required)."
fi
command -v pct >/dev/null 2>&1 || fatal_error "pct not found. Run on a Proxmox VE host."

# --- Args ---
SCRIPT_NAME=""
SCRIPT_ARGS=()
INCLUDE_ALL=false
PARALLEL=1
EXCLUDE=""
INCLUDE=""
ASSUME_YES=false
DRY_RUN=false
INTERACTIVE=true

# Store original arguments for checking what was explicitly set
ORIGINAL_ARGS="$*"

# Parse arguments
# First argument should be script name
SCRIPT_NAME="$1"
shift

# Check if script exists
SCRIPT_PATH="${CT_SCRIPTS_DIR}/${SCRIPT_NAME}"
if [[ ! -f "$SCRIPT_PATH" ]]; then
  fatal_error "Script not found: $SCRIPT_PATH"
fi

if [[ ! -x "$SCRIPT_PATH" ]]; then
  log_warn "Making script executable: $SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
fi

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Executor options
    -a|--all) INCLUDE_ALL=true; INTERACTIVE=false; shift;;
    -p|--parallel) PARALLEL="${2:-1}"; INTERACTIVE=false; shift 2;;
    -e|--exclude) EXCLUDE="${2:-}"; INTERACTIVE=false; shift 2;;
    -i|--include) INCLUDE="${2:-}"; INTERACTIVE=false; shift 2;;
    -y|--yes) ASSUME_YES=true; INTERACTIVE=false; shift;;
    -d|--dry-run) DRY_RUN=true; INTERACTIVE=false; shift;;
    -h|--help) usage; exit 0;;
    --) shift; SCRIPT_ARGS+=("$@"); break;;  # Everything after -- goes to script
    *) SCRIPT_ARGS+=("$1"); shift;;  # Everything else goes to script
  esac
done

# Validate parallel value
if ! [[ "$PARALLEL" =~ ^[0-9]+$ ]] || [[ "$PARALLEL" -lt 1 ]] || [[ "$PARALLEL" -gt 20 ]]; then
  fatal_error "Parallel value must be between 1 and 20: $PARALLEL"
fi

# Validate exclude/include are not both set
if [[ -n "$EXCLUDE" && -n "$INCLUDE" ]]; then
  fatal_error "Cannot use both --exclude and --include"
fi

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
  if [[ -z "$INCLUDE" ]] && ! [[ "$ORIGINAL_ARGS" =~ -i|--include ]]; then
    INCLUDE="$DEFAULT_INCLUDE"
  fi
fi

# === Interactive prompts if no executor options provided ===
if [[ "$INTERACTIVE" == "true" ]]; then
  echo "🔧 Container Executor Configuration"
  echo "Script: $SCRIPT_NAME"
  echo "Script args: ${SCRIPT_ARGS[*]:-none}"
  echo "Press Enter for defaults, or specify custom values:"
  echo

  # Ask about including stopped containers
  read -rp "Include stopped containers? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    INCLUDE_ALL=true
  fi

  # Ask about parallel execution
  read -rp "Number of parallel executions (1-20) [1]: " response
  if [[ "$response" =~ ^[0-9]+$ ]] && [[ "$response" -ge 1 ]] && [[ "$response" -le 20 ]]; then
    PARALLEL="$response"
  fi

  # Ask about filtering
  read -rp "Include only specific container IDs (comma-separated, e.g., 101,105) [all]: " response
  if [[ -n "$response" ]]; then
    INCLUDE="$response"
  else
    read -rp "Exclude specific container IDs (comma-separated, e.g., 101,105) [none]: " response
    if [[ -n "$response" ]]; then
      EXCLUDE="$response"
    fi
  fi

  # Ask about dry run
  read -rp "Dry run (show what would be done without executing)? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    DRY_RUN=true
  fi

  echo
fi

print_title "PVE: Execute ${SCRIPT_NAME} on LXC Containers"

# --- Collect CTs ---
mapfile -t CT_ROWS < <(pct list | awk 'NR>1 {print $1":"$3}')
if [[ ${#CT_ROWS[@]} -eq 0 ]]; then
  log_warn "No containers found."
  exit 0
fi

# Build exclusion/inclusion sets
declare -A EXCL INCL
if [[ -n "$EXCLUDE" ]]; then
  IFS=',' read -r -a _ex <<< "${EXCLUDE}"
  for e in "${_ex[@]}"; do [[ -n "${e// /}" ]] && EXCL["${e// /}"]=1; done
fi

if [[ -n "$INCLUDE" ]]; then
  IFS=',' read -r -a _in <<< "${INCLUDE}"
  for i in "${_in[@]}"; do [[ -n "${i// /}" ]] && INCL["${i// /}"]=1; done
fi

# Filter containers
CT_IDS=()
for row in "${CT_ROWS[@]}"; do
  IFS=':' read -r id status <<< "$row"
  
  # Skip if excluded
  [[ -n "${EXCL[$id]:-}" ]] && continue
  
  # Skip if include list specified and CT not in it
  if [[ ${#INCL[@]} -gt 0 ]] && [[ -z "${INCL[$id]:-}" ]]; then
    continue
  fi
  
  # Filter by status
  if [[ "$INCLUDE_ALL" == "true" ]]; then
    CT_IDS+=("$id")
  else
    [[ "$status" == "running" ]] && CT_IDS+=("$id")
  fi
done

if [[ ${#CT_IDS[@]} -eq 0 ]]; then
  log_warn "No matching containers (check filters and --all option)."
  exit 0
fi

log_step "Target containers:" "${CT_IDS[*]}"
log_step "Script:" "$SCRIPT_NAME ${SCRIPT_ARGS[*]:-}"

# Prompt
if [[ "$ASSUME_YES" == "false" ]]; then
  read -rp "Proceed with execution on ${#CT_IDS[@]} container(s)? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { log_warn "Aborted."; exit 1; }
fi

# --- Execution function ---
execute_on_container() {
  local id="$1"
  local header="CT ${id}"

  # Check if container is running
  local status
  status=$(pct status "$id" 2>/dev/null | awk '{print $2}')
  if [[ "$status" != "running" ]]; then
    log_warn "${header}: not running, skipping"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "${header}: would copy and execute -> ${SCRIPT_NAME} ${SCRIPT_ARGS[*]:-}"
    return 0
  fi

  log_step "${header}: copying and executing ${SCRIPT_NAME}..."
  
  # Copy script to container
  local temp_script="/tmp/$(basename "$SCRIPT_NAME")"
  if ! pct push "$id" "$SCRIPT_PATH" "$temp_script"; then
    log_warn "${header}: failed to copy script"
    return 2
  fi
  
  # Make script executable and run it
  if pct exec "$id" -- bash -c "chmod +x '$temp_script' && '$temp_script' --multiple ${SCRIPT_ARGS[*]:-}"; then
    # Clean up
    pct exec "$id" -- rm -f "$temp_script" 2>/dev/null || true
    log_success "${header}: execution complete"
    return 0
  else
    local rc=$?
    # Clean up
    pct exec "$id" -- rm -f "$temp_script" 2>/dev/null || true
    echo
    log_warn "${header}: execution failed (exit code: $rc)"
    return $rc
  fi
}

# --- Execution loop with simple parallelism ---
SUCCESS=0; SKIPPED=0; FAILED=0
PIDS=()
declare -A PID2ID

run_job() {
  local id="$1"
  if [[ "$PARALLEL" -le 1 ]]; then
    if execute_on_container "$id"; then 
      ((SUCCESS++))
    else 
      rc=$?
      if [[ $rc -eq 1 ]]; then 
        ((SKIPPED++))
      else 
        ((FAILED++))
      fi
    fi
  else
    ( 
      if execute_on_container "$id"; then
        echo "0:$id" > "/tmp/ctexec_${id}.$$"
      else
        echo "$?:$id" > "/tmp/ctexec_${id}.$$"
      fi
    ) &
    PID=$!
    PIDS+=("$PID")
    PID2ID["$PID"]="$id"
  fi
}

for id in "${CT_IDS[@]}"; do
  # Throttle parallel jobs
  while [[ "$PARALLEL" -gt 1 && "${#PIDS[@]}" -ge "$PARALLEL" ]]; do
    wait -n
    # Harvest any finished job result files
    for f in /tmp/ctexec_*; do
      [[ -f "$f" ]] || continue
      rc="$(cut -d: -f1 "$f")"
      jid="$(cut -d: -f2 "$f")"
      rm -f "$f"
      if [[ "$rc" == "0" ]]; then 
        ((SUCCESS++))
      elif [[ "$rc" == "1" ]]; then 
        ((SKIPPED++))
      else 
        ((FAILED++))
      fi
    done
    # Cleanup PIDs array
    tmp=()
    for p in "${PIDS[@]}"; do 
      kill -0 "$p" 2>/dev/null && tmp+=("$p")
    done
    PIDS=("${tmp[@]}")
  done
  run_job "$id"
done

# Wait for remaining jobs
if [[ "$PARALLEL" -gt 1 ]]; then
  wait || true
  for f in /tmp/ctexec_*; do
    [[ -f "$f" ]] || continue
    rc="$(cut -d: -f1 "$f")"
    jid="$(cut -d: -f2 "$f")"
    rm -f "$f"
    if [[ "$rc" == "0" ]]; then 
      ((SUCCESS++))
    elif [[ "$rc" == "1" ]]; then 
      ((SKIPPED++))
    else 
      ((FAILED++))
    fi
  done
fi

echo
print_title "Summary"
echo "Success: ${SUCCESS}"
echo "Skipped: ${SKIPPED}"
echo "Failed : ${FAILED}"

[[ "$FAILED" -gt 0 ]] && exit 2 || exit 0
