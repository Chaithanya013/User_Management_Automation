#!/usr/bin/env bash

set -euo pipefail

# ----------------------
# Defaults & CLI parsing
# ----------------------
INPUT_FILE=""
RESET_EXISTING=false

usage() {
  cat <<EOF
Usage: sudo $0 -f users.txt [--reset-password]
  -f, --file         Path to input file (required)
  --reset-password   Reset passwords for existing users
  -h, --help         Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file) INPUT_FILE="$2"; shift 2;;
    --reset-password) RESET_EXISTING=true; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1" >&2; usage;;
  esac
done

# ----------------------
# Locate script directory and default files (keeps logs/passwords next to script)
# ----------------------
# Use system-wide secure directories as required by the task
PASS_DIR="/var/secure"
PASS_FILE="$PASS_DIR/user_passwords.txt"

LOG_FILE="/var/log/user_management.log"

# Ensure secure directory exists with correct permissions
mkdir -p "$PASS_DIR"
chmod 700 "$PASS_DIR"

# Ensure log + password files exist and have correct permissions
touch "$PASS_FILE" "$LOG_FILE"
chmod 600 "$PASS_FILE" "$LOG_FILE"
chown root:root "$PASS_FILE" "$LOG_FILE"

# BASE_DIR still used for script location (do not modify)
BASE_DIR="$(dirname "$(readlink -f "$0")")"

# Default input file stays in script directory
INPUT_FILE="${INPUT_FILE:-$BASE_DIR/users.txt}"

# ----------------------
# Must be root
# ----------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi

# ----------------------
# Ensure environment & permissions
# ----------------------
mkdir -p "$PASS_DIR"
touch "$PASS_FILE" "$LOG_FILE"
chown root:root "$PASS_FILE" "$LOG_FILE"
chmod 600 "$PASS_FILE" "$LOG_FILE"
chmod 700 "$PASS_DIR" || true

# Logging function (UTC ISO)
log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '%s [%s] %s\n' "$ts" "$level" "$msg" | tee -a "$LOG_FILE"
}

log "INFO" "Starting user creation (input=$INPUT_FILE reset_existing=$RESET_EXISTING)"

# Preflight checks
if [[ ! -r "$INPUT_FILE" ]]; then
  log "ERROR" "Input file not found or unreadable: $INPUT_FILE"
  exit 1
fi

if [[ ! -w /etc/shadow ]]; then
  log "ERROR" "/etc/shadow not writable. Cannot change passwords. Fix permissions and retry."
  exit 1
fi

# Robust password generator (12 chars)
generate_password() {
  local pass
  pass=$(LC_ALL=C tr -dc 'A-Za-z0-9@#%&*+=_?-' </dev/urandom 2>/dev/null | head -c 12) || true
  if [[ -z "$pass" ]]; then
    if command -v openssl >/dev/null 2>&1; then
      pass=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9@#%&*+=_?-' | head -c 12) || true
    else
      pass=$(date +%s%N | sha256sum | base64 | head -c 12)
    fi
  fi
  printf '%s' "$pass"
}

# Atomic append helper using flock if available
append_passfile() {
  local entry="$1"
  if command -v flock >/dev/null 2>&1; then
    exec 200>>"$PASS_FILE"
    flock --exclusive 200
    printf '%s\n' "$entry" >&200
    flock --unlock 200
    exec 200>&-
  else
    printf '%s\n' "$entry" >> "$PASS_FILE"
  fi
}

# Username validation (conservative)
valid_username() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

# ----------------------
# Process file
# ----------------------
while IFS= read -r rawline || [[ -n "${rawline:-}" ]]; do
  # strip BOM, trim leading/trailing whitespace
  line=$(printf '%s' "$rawline" | sed -E 's/^\xEF\xBB\xBF//; s/^[[:space:]]+//; s/[[:space:]]+$//')
  [[ -z "$line" ]] && continue
  case "$line" in \#*) log "INFO" "Skipping comment: $line"; continue;; esac

  # Check semicolon
  if [[ "$line" != *";"* ]]; then
    log "ERROR" "Malformed line (missing ';'): $line"
    continue
  fi

  username=$(printf '%s' "$line" | cut -d';' -f1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  groups_raw=$(printf '%s' "$line" | cut -d';' -f2-)

  # username cannot contain spaces; do not strip inner valid chars (just validate)
  if [[ -z "$username" ]]; then
    log "ERROR" "Empty username in line: $line"
    continue
  fi

  if ! valid_username "$username"; then
    log "ERROR" "Invalid username '$username' - must match [a-z_][a-z0-9_-]{0,31}"
    continue
  fi

  # Normalize groups: remove spaces around commas, trim ends
  groups_norm=$(printf '%s' "$groups_raw" | sed -E 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:],]+//; s/[[:space:],]+$//')
  IFS=',' read -r -a group_list <<< "$groups_norm"
  # clean empty
  clean_groups=()
  for g in "${group_list[@]:-}"; do
    g=$(printf '%s' "$g" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [[ -n "$g" ]] && clean_groups+=("$g")
  done

  log "INFO" "Processing user: $username (groups: ${clean_groups[*]:-none})"

  # Ensure primary group exists
  if ! getent group "$username" >/dev/null 2>&1; then
    if groupadd "$username"; then
      log "INFO" "Created primary group: $username"
    else
      log "ERROR" "Failed to create primary group: $username"
      continue
    fi
  fi

  # Create user if missing
  if id -u "$username" >/dev/null 2>&1; then
    log "WARN" "User already exists: $username"
    # Ensure home dir ownership/perms
    if [[ ! -d "/home/$username" ]]; then
      mkdir -p "/home/$username"
    fi
    chown "$username:$username" "/home/$username" || log "ERROR" "chown failed /home/$username"
    chmod 700 "/home/$username" || log "ERROR" "chmod failed /home/$username"
  else
    # Create any missing supplementary groups first
    for g in "${clean_groups[@]:-}"; do
      if ! getent group "$g" >/dev/null 2>&1; then
        if groupadd "$g"; then
          log "INFO" "Created supplementary group: $g"
        else
          log "ERROR" "Failed to create supplementary group: $g"
        fi
      fi
    done

    # Build -G only if we have groups
    if [[ ${#clean_groups[@]} -gt 0 ]]; then
      supp_list=$(IFS=,; echo "${clean_groups[*]}")
      if useradd -m -d "/home/$username" -s /bin/bash -g "$username" -G "$supp_list" "$username"; then
        log "INFO" "Created user: $username with groups: $supp_list"
      else
        # fallback: try without -G then add groups
        if useradd -m -d "/home/$username" -s /bin/bash -g "$username" "$username"; then
          log "WARN" "Created user $username without -G; will add groups"
          if usermod -a -G "$supp_list" "$username"; then
            log "INFO" "Added $username to groups: $supp_list"
          else
            log "ERROR" "Failed to add groups to $username: $supp_list"
          fi
        else
          log "ERROR" "Failed to create user: $username"
          continue
        fi
      fi
    else
      if useradd -m -d "/home/$username" -s /bin/bash -g "$username" "$username"; then
        log "INFO" "Created user: $username (no supplementary groups)"
      else
        log "ERROR" "Failed to create user: $username"
        continue
      fi
    fi

    chown "$username:$username" "/home/$username" || log "ERROR" "chown failed /home/$username"
    chmod 700 "/home/$username" || log "ERROR" "chmod failed /home/$username"
  fi

  # Ensure supplementary groups exist & add user
  if [[ ${#clean_groups[@]} -gt 0 ]]; then
    to_add=()
    for g in "${clean_groups[@]}"; do
      if ! getent group "$g" >/dev/null 2>&1; then
        if groupadd "$g"; then
          log "INFO" "Created supplementary group: $g"
        else
          log "ERROR" "Failed to create group: $g"
          continue
        fi
      fi
      to_add+=("$g")
    done
    if [[ ${#to_add[@]} -gt 0 ]]; then
      if usermod -a -G "$(IFS=,; echo "${to_add[*]}")" "$username"; then
        log "INFO" "Added $username to groups: ${to_add[*]}"
      else
        log "ERROR" "Failed to add $username to groups: ${to_add[*]}"
      fi
    fi
  fi

  # Password handling
  if id -u "$username" >/dev/null 2>&1 && [[ "$RESET_EXISTING" == false ]]; then
    # existing user & not resetting password
    log "INFO" "Skipping password change for existing user $username (use --reset-password)"
  else
    newpass=$(generate_password)
    if echo "$username:$newpass" | chpasswd; then
      append_passfile "$username:$newpass" || log "ERROR" "Failed to record password for $username"
      # force change at first login
      chage -d 0 "$username" || log "WARN" "chage failed for $username"
      log "INFO" "Set password for $username and saved to $PASS_FILE"
    else
      log "ERROR" "Failed to set password for $username"
    fi
  fi

done < "$INPUT_FILE"

log "INFO" "Processing complete. Passwords saved to $PASS_FILE, logs to $LOG_FILE"
exit 0
