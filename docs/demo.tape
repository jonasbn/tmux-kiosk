# VHS tape for the README demo GIF.
#
# Regenerate after any user-visible behavior change:
#   vhs docs/demo.tape
# Run from the repo root (the tape shells out to ./tmux-kiosk.tmux).
# Requires: vhs (https://github.com/charmbracelet/vhs), tmux, bash.

Output docs/demo.gif

Set Shell bash
Set FontSize 18
Set Width 860
Set Height 480
Set Padding 20
Set Theme "Dracula"

# --- Setup (hidden): three windows standing in for dashboards the way the
# README's Motivation section describes, plus the status bar indicator and
# a fast 3s interval so the cycle is visible without a long recording.
Hide

Type `tmux new-session -d -s kiosk-demo -n dashboard "while true; do clear; printf '\n\n  \e[1;36m▣ DASHBOARD\e[0m\n\n  %s\n' \"\$(date +%T)\"; sleep 1; done"`
Enter
Type `tmux new-window -t kiosk-demo -n logs "while true; do clear; printf '\n\n  \e[1;33m▤ LOGS\e[0m\n\n  %s\n' \"\$(date +%T)\"; sleep 1; done"`
Enter
Type `tmux new-window -t kiosk-demo -n metrics "while true; do clear; printf '\n\n  \e[1;35m▥ METRICS\e[0m\n\n  %s\n' \"\$(date +%T)\"; sleep 1; done"`
Enter
Type `tmux set-option -t kiosk-demo -g @kiosk-interval 3`
Enter
Type `tmux set-option -t kiosk-demo -g status-right "#{@kiosk-status-active} | %H:%M"`
Enter
Type "tmux select-window -t kiosk-demo:1"
Enter
Type "./tmux-kiosk.tmux"
Enter
Type "clear"
Enter
Sleep 500ms
Show

# --- Recorded from here: attach, then toggle kiosk mode with prefix+W.
Type "tmux attach -t kiosk-demo"
Enter
Sleep 2s

Ctrl+B
Sleep 200ms
Type "W"
Sleep 11s

Ctrl+B
Sleep 200ms
Type "W"
Sleep 2s

Hide
Type "tmux kill-session -t kiosk-demo"
Enter
