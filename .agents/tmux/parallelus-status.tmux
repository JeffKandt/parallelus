# Parallelus-specific tmux status bar overlay
set -g status on
set -g status-interval 5
set -g status-justify centre
set -g status-left-length 80
set -g status-right-length 120
set -g status-style bg=colour236,fg=colour248

set -g status-left " #[bold]#S #[fg=colour244]|#[fg=colour248] \#(.agents/bin/subagent_prompt_phase.py) #[fg=colour244]|#[fg=colour248] #I:#W "

set -g status-right " #[fg=colour244]#{pane_current_command} #[fg=colour240]|#[fg=colour248] \#(.agents/bin/subagent_prompt_phase.py --worktree) \#(.agents/bin/subagent_prompt_phase.py --branch) \#(.agents/bin/subagent_prompt_phase.py --git-status) #[fg=colour240]|#[fg=colour248] \#(.agents/bin/subagent_prompt_phase.py --heartbeat) "

setw -g window-status-style fg=colour244,bg=colour236
setw -g window-status-current-style fg=colour255,bg=colour31,bold
setw -g window-status-format " #I:#W "
setw -g window-status-current-format " #I:#W "
