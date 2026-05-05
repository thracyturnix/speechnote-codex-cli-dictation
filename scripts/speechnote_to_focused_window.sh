#!/usr/bin/env bash
set -u

log_file=/tmp/speechnote-to-focused-window.log
{
  echo
  echo "=== $(date -Is) starting Speech Note wrapper ==="
  echo "DISPLAY=${DISPLAY:-}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
} >>"$log_file"

target_window="$(xdotool getwindowfocus 2>>"$log_file" || true)"
before_clipboard="$(copyq clipboard 2>>"$log_file" || true)"
echo "target_window=${target_window:-none}" >>"$log_file"

flatpak run net.mkiol.SpeechNote --action start-listening-clipboard >>"$log_file" 2>&1 &
echo "started Speech Note clipboard action pid=$!" >>"$log_file"

for _ in $(seq 1 900); do
  sleep 0.1
  current_clipboard="$(copyq clipboard 2>>"$log_file" || true)"

  if [ -n "$current_clipboard" ] && [ "$current_clipboard" != "$before_clipboard" ]; then
    if [ -n "$target_window" ]; then
      xdotool windowactivate --sync "$target_window" >>"$log_file" 2>&1 || true
    fi
    echo "clipboard changed; pasting into target window" >>"$log_file"
    xdotool key --clearmodifiers ctrl+shift+v >>"$log_file" 2>&1
    exit 0
  fi
done

echo "Timed out waiting for Speech Note to update clipboard" >>"$log_file"
exit 1
