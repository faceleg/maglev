#!/usr/bin/env bash
set -e

apply_theme() {
    left_separator=''
    left_separator_black=''
    right_separator=''
    right_separator_black=''
    session_symbol=''

    # panes
    pane_border_fg=colour8 # gray
    pane_active_border_fg=colour4 # blue

    tmux set -g pane-border-style fg=$pane_border_fg \; set -g pane-active-border-style fg=$pane_active_border_fg
    #uncomment for fat borders
    #tmux set -ga pane-border-style bg=$pane_border_fg \; set -ga pane-active-border-style bg=$pane_active_border_fg

    display_panes_active_colour=colour4 # blue
    display_panes_colour=colour4 # blue
    tmux set -g display-panes-active-colour $display_panes_active_colour \; set -g display-panes-colour $display_panes_colour

    # messages
    message_fg=colour16           # black
    message_bg=colour11 # yellow
    message_attr=bold
    tmux set -g message-style fg=$message_fg,bg=$message_bg,$message_attr

    message_command_fg=colour16   # black
    message_command_bg=colour160  # light yellow
    tmux set -g message-command-style fg=$message_command_fg,bg=$message_command_bg,$message_attr

    # windows mode
    mode_fg=colour16   # black
    mode_bg=colour11 # yellow
    mode_attr=bold
    tmux setw -g mode-style fg=$mode_fg,bg=$mode_bg,$mode_attr

    # status line
    status_fg=colour253 # white
    status_bg=colour0 # dark gray
    tmux set -g status-style fg=$status_fg,bg=$status_bg

    session_fg=colour16  # black
    session_bg=colour11 # yellow
    status_left="#[fg=$session_fg,bg=$session_bg,bold] ❐ #S #[fg=$session_bg,bg=$status_bg,nobold]$left_separator_black"
    if [ x"`tmux -q -L tmux_theme_status_left_test -f /dev/null new-session -d \; show -g -v status-left \; kill-session`" = x"[#S] " ] ; then
        status_left="$status_left "
    fi
    tmux set -g status-left-length 32 \; set -g status-left "$status_left"

    window_status_fg=colour8 # gray
    window_status_bg=colour0 # dark gray
    window_status_format="#I #W"
    tmux setw -g window-status-style fg=$window_status_fg,bg=$window_status_bg \; setw -g window-status-format "$window_status_format"

    window_status_current_fg=colour16 # black
    window_status_current_bg=colour4 # blue
    window_status_current_format="#[fg=$window_status_bg,bg=$window_status_current_bg]$left_separator_black#[fg=$window_status_current_fg,bg=$window_status_current_bg,bold] #I $left_separator #W #[fg=$window_status_current_bg,bg=$status_bg,nobold]$left_separator_black"
    tmux setw -g window-status-current-format "$window_status_current_format"
    tmux set -g status-justify left

    window_status_activity_fg=default
    window_status_activity_bg=default
    window_status_activity_attr=underscore
    tmux setw -g window-status-activity-style fg=$window_status_activity_fg,bg=$window_status_activity_bg,$window_status_activity_attr

    window_status_bell_fg=colour11 # yellow
    window_status_bell_bg=default
    window_status_bell_attr=blink,bold
    tmux setw -g window-status-bell-style fg=$window_status_bell_fg,bg=$window_status_bell_bg,$window_status_bell_attr

    window_status_last_fg=colour4 # blue
    window_status_last_attr=default
    tmux setw -g window-status-last-style $window_status_last_attr,fg=$window_status_last_fg

    time_date_fg=colour8      # gray
    time_date_bg=colour0 # dark gray
    whoami_fg=colour254         # white
    whoami_bg=colour160         # red
    host_fg=colour16            # black
    host_bg=colour254           # white
    status_right="︎#[fg=$time_date_fg,nobold]$right_separator %R $right_separator %a %d %b #[fg=$host_bg]$right_separator_black#[fg=$host_fg,bg=$host_bg,bold]"
    tmux set -g status-right-length 64 \; set -g status-right "$status_right"

    # clock
    clock_mode_colour=colour4 # blue
    tmux setw -g clock-mode-colour $clock_mode_colour
}

circled_digit() {
    circled_digits='⓪①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳'
    if [ $1 -lt 20 ] 2>/dev/null ; then
        echo ${circled_digits:$1:1}
    else
        echo $1
    fi
}

maximize_pane() {
    tmux -q -L swap-pane-test -f /dev/null new-session -d \; new-window \; new-window \; swap-pane -t :1 \; kill-session || { tmux display 'your tmux version has a buggy swap-pane command - see ticket #108, fixed in upstream commit 78e783e'; exit; }
    __current_pane=$(tmux display -p '#{pane_id}')

    __dead_panes=$(tmux list-panes -s -F '#{pane_dead} #{pane_id} #{pane_start_command}' | grep -o '^1 %.\+maximized.\+$' || true)
    __restore=$(echo "${__dead_panes}" | sed -n -E -e "s/^1 ${__current_pane} .+maximized.+(%[0-9]+)$/tmux swap-pane -s \1 -t ${__current_pane} \; kill-pane -t ${__current_pane}/p" -e "s/^1 (%[0-9]+) .+maximized.+${__current_pane}$/tmux swap-pane -s \1 -t ${__current_pane} \; kill-pane -t \1/p" )

    if [ x"${__restore}" = x ] ; then
        [ x"$(tmux list-panes | wc -l | sed 's/^ *//g')" = x1 ] && tmux display "Can't maximize with only one pane" && return
        __window=$(tmux new-window -P "exec maximized& tmux setw remain-on-exit on; clear; tmux clear-history; printf 'Pane has been maximized, press <prefix>+ to restore. %s' \\${__current_pane};")
        __window=${__window%.*}

        __guard=50
        while ( [ x"$(tmux list-panes -t ${__window} -F '#{session_name}:#{window_index} #{pane_dead}')" != x"${__window} "1 ] && [ x"${__guard}" != x0 ] ) ; do sleep 0.01 ; __guard=$((__guard - 1)); done
        if [ x"${__guard}" = 0 ] ; then
        exit 1
        fi

        __new_pane=$(tmux display -p '#{pane_id}')
        tmux setw remain-on-exit off \; swap-pane -s "${__current_pane}" -t "${__new_pane}"
    else
        ${__restore} || tmux kill-pane
    fi
}

apply_theme
