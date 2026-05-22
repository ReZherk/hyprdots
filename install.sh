#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE_DIR="${SCRIPT_DIR}/.config"
TARGET_CONFIG_DIR="${HOME}/.config"
BACKUP_ROOT="${HOME}/.config-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/mkhmtdots-${TIMESTAMP}"

CREATE_BACKUP=1
INSTALL_P10K=1
DELETE_MANAGED_FILES=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --no-backup     Skip backup of existing files
  --no-p10k       Do not install .p10k.zsh
  --delete        Delete files in managed config directories that do not exist in this repo
  -h, --help      Show this help message

The script installs only files managed by this repository.
Unrelated files in ~/.config are left untouched.
EOF
}

log() {
  printf '[install] %s\n' "$1"
}

copy_with_backup() {
  local src="$1"
  local dst="$2"
  local rel="$3"

  if [[ -e "$dst" && "$CREATE_BACKUP" -eq 1 ]]; then
    mkdir -p "${BACKUP_DIR}/$(dirname "$rel")"
    cp -a "$dst" "${BACKUP_DIR}/${rel}"
    log "Backed up ${rel}"
  fi

  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  log "Installed ${rel}"
}

sync_config_dir() {
  local src_dir="$1"
  local name
  name="$(basename "$src_dir")"
  local dst_dir="${TARGET_CONFIG_DIR}/${name}"

  if [[ -e "$dst_dir" && "$CREATE_BACKUP" -eq 1 ]]; then
    mkdir -p "${BACKUP_DIR}/.config"
    cp -a "$dst_dir" "${BACKUP_DIR}/.config/${name}"
    log "Backed up .config/${name}"
  fi

  mkdir -p "$dst_dir"

  local -a rsync_args
  rsync_args=(-a)
  if [[ "$DELETE_MANAGED_FILES" -eq 1 ]]; then
    rsync_args+=(--delete)
  fi

  rsync "${rsync_args[@]}" "${src_dir}/" "${dst_dir}/"
  log "Synced .config/${name}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-backup)
      CREATE_BACKUP=0
      ;;
    --no-p10k)
      INSTALL_P10K=0
      ;;
    --delete)
      DELETE_MANAGED_FILES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$CONFIG_SOURCE_DIR" ]]; then
  printf 'Cannot find %s\n' "$CONFIG_SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_CONFIG_DIR"

if [[ "$CREATE_BACKUP" -eq 1 ]]; then
  mkdir -p "$BACKUP_DIR"
  log "Backup directory: ${BACKUP_DIR}"
fi

while IFS= read -r config_dir; do
  sync_config_dir "$config_dir"
done < <(find "$CONFIG_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$INSTALL_P10K" -eq 1 && -f "${SCRIPT_DIR}/.p10k.zsh" ]]; then
  copy_with_backup "${SCRIPT_DIR}/.p10k.zsh" "${HOME}/.p10k.zsh" ".p10k.zsh"
fi

log "Install complete"
