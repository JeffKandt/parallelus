# Parallelus-specific tmux status bar overlay
set -g status on
set -g status-interval 5
set -g status-justify centre
set -g status-left-length 80
set -g status-right-length 120
set -g status-style bg=colour24,fg=colour253

set -g status-left " #[fg=colour253]#{pane_current_command} #[fg=colour244]|#[fg=colour253] #[bold]#S #[fg=colour244]|#[fg=colour253] \#(parallelus/engine/bin/subagent_prompt_phase.py --branch) "

set -g status-right " #[fg=colour253]#I:#W #[fg=colour244]|#[fg=colour253] \#(parallelus/engine/bin/subagent_prompt_phase.py) #[fg=colour244]|#[fg=colour253] \#(parallelus/engine/bin/subagent_prompt_phase.py --worktree) \#(parallelus/engine/bin/subagent_prompt_phase.py --git-status) #[fg=colour244]|#[fg=colour253] \#(parallelus/engine/bin/subagent_prompt_phase.py --heartbeat) "

setw -g window-status-style fg=colour244,bg=colour24
setw -g window-status-current-style fg=colour255,bg=colour31,bold
setw -g window-status-format " #I:#W "
setw -g window-status-current-format " #I:#W "
