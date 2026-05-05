# Global Speech Dictation Into Codex CLI on Linux

This is to be able to speak to AI coding tools within a CLI. It works like voice typing on Android. 

## What it does

Press a hotkey (ie `Ctrl+Alt+Space`).

The app (speech note) will take what you say and put it in the command box of the AI you are using (ie Gemini, Codex, Claude, Deepseek, Kimi, etc)

Full breakdown:

The wrapper starts Speech Note and shows desktop notifications for visual confirmation.

When Speech Note finishes dictation and updates the clipboard, the script switches back to the terminal window you were using and pastes the text with `Ctrl+Shift+V`.

This matters because many terminals use `Ctrl+Shift+V` for paste. Plain `Ctrl+V` may not work.

## Requirements

Install or check that these commands exist:

    command -v xdotool
    command -v copyq
    command -v flatpak
    command -v autokey-gtk
    command -v notify-send
    command -v flock

Speech Note should be installed as a Flatpak.

The Speech Note Flatpak app ID is:

    net.mkiol.SpeechNote

You can check the active Speech Note speech-to-text model with:

    flatpak run net.mkiol.SpeechNote --print-active-model stt

## Why use AutoKey?

This was done in Cinnamon. I found Autokey more reliable than its native system. YMMV.

Full breakdown:

    Ctrl+Alt+Space
    -> AutoKey
    -> shell script
    -> Speech Note
    -> clipboard
    -> terminal paste

## Create the shell script

Create this file:

    ~/.local/bin/speechnote_to_focused_window.sh

Put this inside it:

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

Make it executable:

    chmod +x ~/.local/bin/speechnote_to_focused_window.sh

## Create the AutoKey script

Create the folder:

    mkdir -p ~/.config/autokey/data/Codex

Create this file:

    ~/.config/autokey/data/Codex/Speech Note Dictation.py

Put this inside it:

    system.exec_command("/bin/bash -lc 'printf \"%s\\n\" \"$(date -Is) AutoKey Ctrl+Alt+Space fired\" >> /tmp/autokey-speechnote-dictation.log; nohup /bin/bash \"$HOME/.local/bin/speechnote_to_focused_window.sh\" >> /tmp/autokey-speechnote-dictation.log 2>&1 &'")

Now create this file:

    ~/.config/autokey/data/Codex/Speech Note Dictation.json

Put this inside it:

    {
        "type": "script",
        "description": "Speech Note Dictation",
        "store": {},
        "modes": [],
        "usageCount": 0,
        "prompt": false,
        "omitTrigger": false,
        "showInTrayMenu": false,
        "abbreviation": {
            "abbreviations": [],
            "backspace": true,
            "ignoreCase": false,
            "immediate": false,
            "triggerInside": false,
            "wordChars": "[\\w]"
        },
        "hotkey": {
            "modifiers": [
                "<ctrl>",
                "<alt>"
            ],
            "hotKey": " "
        },
        "filter": {
            "regex": null,
            "isRecursive": false
        }
    }

Important: the space key must be written as a literal space:

    "hotKey": " "

Do not write:

    "hotKey": "space"

## Start AutoKey

AutoKey may already start automatically.

To start it manually:

    DISPLAY=:0 \
    XAUTHORITY="$HOME/.Xauthority" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
    XDG_RUNTIME_DIR="/run/user/$(id -u)" \
    setsid -f autokey-gtk >/tmp/autokey-gtk.log 2>&1

Check that AutoKey is running:

    ps -ef | grep -i '[a]utokey'

## Test 

IMPORTANT: Focus (click / select) the terminal text-entry box running your AI coding tool.

Press `Ctrl+Alt+Space`.

Speak. The wrapper should show desktop notifications for hotkey recognition and speech processing.

When dictation finishes, the text should automatically paste into the terminal.

## Common problems

Use `Ctrl+Shift+V` for terminal paste.

Do not use `Ctrl+V` in Tilix or many other terminals. It may not paste text correctly.

Do not copy other text while Speech Note is listening. The wrapper treats a clipboard change as the signal that dictation finished.

## More debugging:

Check whether AutoKey fired:

    tail -40 /tmp/autokey-speechnote-dictation.log

Check the wrapper log:

    tail -80 /tmp/speechnote-to-focused-window.log

A successful log should look roughly like this:

    === 2026-05-05T13:23:09+09:30 starting Speech Note wrapper ===
    DISPLAY=:0
    XDG_SESSION_TYPE=x11
    target_window=56623111
    started Speech Note clipboard action pid=...
    clipboard changed; pasting into target window




This setup is for X11. It may not work the same way on Wayland because xdotool depends on X11 window control.
