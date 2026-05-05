#!/usr/bin/env bash
set -u

log_file=/tmp/speechnote-to-focused-window.log
lock_file=/tmp/speechnote-to-focused-window.lock
notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name="Speech Note" --icon=net.mkiol.SpeechNote --expire-time=1800 "$@" >>"$log_file" 2>&1 || true
  fi
}

exec 9>"$lock_file"
if ! flock -n 9; then
  echo "Speech Note wrapper already running; ignoring duplicate trigger" >>"$log_file"
  notify "Speech Note" "Dictation already running."
  exit 0
fi

{
  echo
  echo "=== $(date -Is) starting Speech Note wrapper ==="
  echo "DISPLAY=${DISPLAY:-}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
} >>"$log_file"

target_window="$(xdotool getwindowfocus 2>>"$log_file" || true)"
before_clipboard="$(copyq clipboard 2>>"$log_file" || true)"
echo "target_window=${target_window:-none}" >>"$log_file"

notify "Speech Note" "Hotkey recognised. Starting dictation..."
pkill -f 'dsnote --action start-listening-clipboard' >>"$log_file" 2>&1 || true
pkill -f 'dsnote --action start-listening-active-window' >>"$log_file" 2>&1 || true

flatpak run net.mkiol.SpeechNote --action start-listening-clipboard >>"$log_file" 2>&1 &
speech_note_pid=$!
echo "started Speech Note clipboard action pid=$speech_note_pid" >>"$log_file"
notify "Speech Note" "Listening and processing speech..."

cleanup() {
  pkill -f 'dsnote --action start-listening-clipboard' >>"$log_file" 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 900); do
  sleep 0.1
  current_clipboard="$(copyq clipboard 2>>"$log_file" || true)"

  if [ -n "$current_clipboard" ] && [ "$current_clipboard" != "$before_clipboard" ]; then
    if [ -n "$target_window" ]; then
      xdotool windowactivate --sync "$target_window" >>"$log_file" 2>&1 || true
    fi
    echo "clipboard changed; pasting into target window" >>"$log_file"
    xdotool key --clearmodifiers ctrl+shift+v >>"$log_file" 2>&1
    notify "Speech Note" "Dictation pasted."
    exit 0
  fi
done

echo "Timed out waiting for Speech Note to update clipboard" >>"$log_file"
notify "Speech Note" "Dictation timed out."
exit 1
