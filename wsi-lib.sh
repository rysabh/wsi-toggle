#!/usr/bin/env bash
set -euo pipefail

wsi_die() { wsi_note "$*"; exit 1; }

wsi_require() {
  command -v "$1" >/dev/null 2>&1 || wsi_die "Missing dependency: $1"
}

wsi_notify() {
  local msg="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a wsi "WSI Model Cache" "$msg" >/dev/null 2>&1 || true
  elif command -v gdbus >/dev/null 2>&1; then
    gdbus call --session --dest org.freedesktop.Notifications \
      --object-path /org/freedesktop/Notifications \
      --method org.freedesktop.Notifications.Notify \
      wsi 0 "" "WSI Model Cache" "$msg" [] {} 3000 >/dev/null 2>&1 || true
  fi
}

wsi_note() {
  local msg="$1" log_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  wsi_notify "$msg"
  printf '%s\n' "$msg" >&2
  mkdir -p "$log_dir" 2>/dev/null || true
  { printf '%s %s\n' "$(date '+%F %T')" "$msg" >> "$log_dir/wsi-model.log"; } 2>/dev/null || true
}

wsi_other_jobs_active() {
  if pgrep -af '(^|/)(wsi-file|wsi-manual|transcribe|rec)( |$)' | grep -Eqv "^$BASHPID "; then
    return 0
  fi
  return 1
}

wsi_prep_model_in_shm() {
  local model_on_disk="${1:-}"
  [[ -n "$model_on_disk" ]] || wsi_die "Model path not configured (set WMODEL or MODEL_ON_DISK)."
  [[ -f "$model_on_disk" ]] || wsi_die "Model file not found: $model_on_disk"

  local model_name model_in_shm
  model_name="$(basename "$model_on_disk")"
  model_in_shm="/dev/shm/$model_name"

  if [[ ! -f "$model_in_shm" ]]; then
    cp -f "$model_on_disk" "$model_in_shm" || wsi_die "Failed to load $model_name into /dev/shm"
    wsi_note "[wsi-model] Loaded $model_name into /dev/shm"
  fi

  local model stale_in_shm
  for model in ${WSI_MODELS:-}; do
    stale_in_shm="/dev/shm/ggml-$model.bin"
    [[ "$stale_in_shm" == "$model_in_shm" || ! -f "$stale_in_shm" ]] && continue
    if wsi_other_jobs_active; then
      wsi_note "[wsi-model] Did not remove stale $(basename "$stale_in_shm") from /dev/shm because another job is active"
      continue
    fi
    rm -f -- "$stale_in_shm" || wsi_die "Failed to remove stale $(basename "$stale_in_shm") from /dev/shm"
    wsi_note "[wsi-model] Removed stale $(basename "$stale_in_shm") from /dev/shm"
  done

  export WHISPER_DMODEL="$model_in_shm"
  export WMODEL="$model_in_shm"
}

wsi_to_wav16k_mono() {
  local input_path="$1"
  local out_wav="$2"

  # Fast path: if the input is already a 16kHz mono WAV, avoid re-encoding.
  # This saves time for common cases like re-transcribing saved recordings.
  if [[ "$input_path" == *.wav || "$input_path" == *.WAV ]] && command -v soxi >/dev/null 2>&1; then
    local rate channels
    rate="$(soxi -r "$input_path" 2>/dev/null || true)"
    channels="$(soxi -c "$input_path" 2>/dev/null || true)"
    if [[ "$rate" == "16000" && "$channels" == "1" ]]; then
      # If input_path is relative, a symlink created in /tmp would be broken.
      # Resolve to an absolute path before linking.
      local abs_input
      abs_input="$(readlink -f -- "$input_path" 2>/dev/null || true)"
      if [[ -n "${abs_input:-}" ]]; then
        ln -sf "$abs_input" "$out_wav" 2>/dev/null || cp -f "$abs_input" "$out_wav"
      else
        cp -f "$input_path" "$out_wav"
      fi
      return 0
    fi
  fi

  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -v error -y -i "$input_path" -ac 1 -ar 16000 -f wav "$out_wav"
  elif command -v sox >/dev/null 2>&1; then
    sox "$input_path" -r 16000 -c 1 -b 16 "$out_wav"
  else
    wsi_die "Install ffmpeg (recommended) or sox."
  fi
}

wsi_cleanup_text() {
  local s="$1"
  s="${s/\(*\)}"
  s="${s/\[*\]}"
  s="${s#$'\n'}"
  s="${s#$'\n'}"
  shopt -s extglob 2>/dev/null || true
  s="${s##+([[:space:]])}"
  printf '%s' "${s^}"
}
