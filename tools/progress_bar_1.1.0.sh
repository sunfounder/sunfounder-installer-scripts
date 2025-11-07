#!/bin/bash
# https://github.com/pollev/bash_progress_bar - See license at end of file

# Usage:
# Source this script
# progress_bar_enable_trapping <- optional to clean up properly if user presses ctrl-c
# progress_bar_setup_scroll_area <- create empty progress bar
# progress_bar_draw 10 <- advance progress bar
# progress_bar_draw 40 <- advance progress bar
# progress_bar_block 45 <- turns the progress bar yellow to indicate some action is requested from the user
# progress_bar_draw 90 <- advance progress bar
# progress_bar_destroy_scroll_area <- remove progress bar

# Constants
PROGRESS_BAR_CODE_SAVE_CURSOR="\033[s"
PROGRESS_BAR_CODE_RESTORE_CURSOR="\033[u"
PROGRESS_BAR_CODE_CURSOR_IN_SCROLL_AREA="\033[1A"
PROGRESS_BAR_COLOR_FG="\e[92m"
PROGRESS_BAR_COLOR_BG="\e[49m"
PROGRESS_BAR_COLOR_BG_BLOCKED="\e[43m"
PROGRESS_BAR_RESTORE_FG="\e[90m"
PROGRESS_BAR_RESTORE_BG="\e[49m"
PROGRESS_BAR_START_CHARACTER=""
PROGRESS_BAR_FILL_CHARACTER="━" # ■
PROGRESS_BAR_EMPTY_CHARACTER="━"
PROGRESS_BAR_END_CHARACTER=""


# Variables
PROGRESS_BAR_PROGRESS_BLOCKED="false"
PROGRESS_BAR_TRAPPING_ENABLED="false"
PROGRESS_BAR_ETA_ENABLED="false"
PROGRESS_BAR_TRAP_SET="false"

PROGRESS_BAR_CURRENT_NR_LINES=0
PROGRESS_BAR_PROGRESS_TITLE=""
PROGRESS_BAR_PROGRESS_TOTAL=100
PROGRESS_BAR_PROGRESS_START=0
PROGRESS_BAR_BLOCKED_START=0

# shellcheck disable=SC2120
progress_bar_setup_scroll_area() {
    # If trapping is enabled, we will want to activate it whenever we setup the scroll area and remove it when we break the scroll area
    if [ "$PROGRESS_BAR_TRAPPING_ENABLED" = "true" ]; then
        progress_bar_trap_on_interrupt
    fi

    # Handle first parameter: alternative progress bar title
    [ -n "$1" ] && PROGRESS_BAR_PROGRESS_TITLE="$1" || PROGRESS_BAR_PROGRESS_TITLE="Progress"

    # Handle second parameter : alternative total count
    [ -n "$2" ] && PROGRESS_BAR_PROGRESS_TOTAL=$2 || PROGRESS_BAR_PROGRESS_TOTAL=100

    lines=$(tput lines)
    PROGRESS_BAR_CURRENT_NR_LINES=$lines
    lines=$((lines-1))
    # Scroll down a bit to avoid visual glitch when the screen area shrinks by one row
    echo -en "\n"

    # Save cursor
    echo -en "$PROGRESS_BAR_CODE_SAVE_CURSOR"
    # Set scroll region (this will place the cursor in the top left)
    echo -en "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echo -en "$PROGRESS_BAR_CODE_RESTORE_CURSOR"
    echo -en "$PROGRESS_BAR_CODE_CURSOR_IN_SCROLL_AREA"

    # Store start timestamp to compute ETA
    if [ "$PROGRESS_BAR_ETA_ENABLED" = "true" ]; then
      PROGRESS_BAR_PROGRESS_START=$( date +%s )
    fi

    # Start empty progress bar
    progress_bar_draw 0
}

progress_bar_destroy_scroll_area() {
    lines=$(tput lines)
    # Save cursor
    echo -en "$PROGRESS_BAR_CODE_SAVE_CURSOR"
    # Set scroll region (this will place the cursor in the top left)
    echo -en "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echo -en "$PROGRESS_BAR_CODE_RESTORE_CURSOR"
    echo -en "$PROGRESS_BAR_CODE_CURSOR_IN_SCROLL_AREA"

    # We are done so clear the scroll bar
    progress_bar_clear

    # Scroll down a bit to avoid visual glitch when the screen area grows by one row
    echo -en "\n\n"

    # Reset title for next usage
    PROGRESS_BAR_PROGRESS_TITLE=""

    # Once the scroll area is cleared, we want to remove any trap previously set. Otherwise, ctrl+c will exit our shell
    if [ "$PROGRESS_BAR_TRAP_SET" = "true" ]; then
        trap - EXIT
    fi
}

progress_bar_format_eta() {
    local T=$1
    local D=$((T/60/60/24))
    local H=$((T/60/60%24))
    local M=$((T/60%60))
    local S=$((T%60))
    [ $D -eq 0 -a $H -eq 0 -a $M -eq 0 -a $S -eq 0 ] && echo "--:--:--" && return
    [ $D -gt 0 ] && printf '%d days, ' $D
    printf 'ETA: %d:%02.f:%02.f' $H $M $S
}

progress_bar_draw() {
    eta=""
    if [ "$PROGRESS_BAR_ETA_ENABLED" = "true" -a $1 -gt 0 ]; then
        if [ "$PROGRESS_BAR_PROGRESS_BLOCKED" = "true" ]; then
            blocked_duration=$(($(date +%s)-$PROGRESS_BAR_BLOCKED_START))
            PROGRESS_BAR_PROGRESS_START=$((PROGRESS_BAR_PROGRESS_START+blocked_duration))
        fi
        running_time=$(($(date +%s)-PROGRESS_BAR_PROGRESS_START))
        total_time=$((PROGRESS_BAR_PROGRESS_TOTAL*running_time/$1))
        eta=$( progress_bar_format_eta $(($total_time-$running_time)) )
    fi

    percentage=$1
    if [ $PROGRESS_BAR_PROGRESS_TOTAL -ne 100 ]
    then
	[ $PROGRESS_BAR_PROGRESS_TOTAL -eq 0 ] && percentage=100 || percentage=$((percentage*100/$PROGRESS_BAR_PROGRESS_TOTAL))
    fi
    extra=$2

    lines=$(tput lines)
    lines=$((lines))

    # Check if the window has been resized. If so, reset the scroll area
    if [ "$lines" -ne "$PROGRESS_BAR_CURRENT_NR_LINES" ]; then
        progress_bar_setup_scroll_area
    fi

    # Save cursor
    echo -en "$PROGRESS_BAR_CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    PROGRESS_BAR_PROGRESS_BLOCKED="false"
    progress_bar_print_bar_text $percentage "$extra" "$eta"

    # Restore cursor position
    echo -en "$PROGRESS_BAR_CODE_RESTORE_CURSOR"
}

progress_bar_block() {
    percentage=$1
    lines=$(tput lines)
    lines=$((lines))
    # Save cursor
    echo -en "$PROGRESS_BAR_CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    PROGRESS_BAR_PROGRESS_BLOCKED="true"
    PROGRESS_BAR_BLOCKED_START=$( date +%s )
    progress_bar_print_bar_text $percentage

    # Restore cursor position
    echo -en "$PROGRESS_BAR_CODE_RESTORE_CURSOR"
}

progress_bar_clear() {
    lines=$(tput lines)
    lines=$((lines))
    # Save cursor
    echo -en "$PROGRESS_BAR_CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # clear progress bar
    tput el

    # Restore cursor position
    echo -en "$PROGRESS_BAR_CODE_RESTORE_CURSOR"
}

progress_bar_print_bar_text() {
    local percentage=$1
    local extra=$2
    [ -n "$extra" ] && extra=" ($extra)"
    local eta=$3
    if [ -n "$eta" ]; then
        [ -n "$extra" ] && extra="$extra "
        extra="$extra$eta"
    fi
    local cols=$(tput cols)
    bar_size=$((cols-9-${#PROGRESS_BAR_PROGRESS_TITLE}-${#extra}))

    local color="${PROGRESS_BAR_COLOR_FG}${PROGRESS_BAR_COLOR_BG}"
    if [ "$PROGRESS_BAR_PROGRESS_BLOCKED" = "true" ]; then
        color="${PROGRESS_BAR_COLOR_FG}${PROGRESS_BAR_COLOR_BG_BLOCKED}"
    fi

    # Prepare progress bar
    complete_size=$(((bar_size*percentage)/100))
    remainder_size=$((bar_size-complete_size))
    progress_bar=$(\
        echo -ne $PROGRESS_BAR_START_CHARACTER; \
        echo -en "${color}"; \
        progress_bar_printf_new "$PROGRESS_BAR_FILL_CHARACTER" $complete_size; \
        echo -en "${PROGRESS_BAR_RESTORE_FG}${PROGRESS_BAR_RESTORE_BG}"; \
        progress_bar_printf_new "$PROGRESS_BAR_EMPTY_CHARACTER" $remainder_size; \
        echo -ne $PROGRESS_BAR_END_CHARACTER);

    # Print progress bar
    echo -ne " $PROGRESS_BAR_PROGRESS_TITLE ${percentage}% ${progress_bar}${extra}"
}

progress_bar_enable_trapping() {
    PROGRESS_BAR_TRAPPING_ENABLED="true"
}

progress_bar_trap_on_interrupt() {
    # If this function is called, we setup an interrupt handler to cleanup the progress bar
    PROGRESS_BAR_TRAP_SET="true"
    progress_bar_enable_trapping
    trap progress_bar_cleanup_on_interrupt SIGINT EXIT
}

progress_bar_cleanup_on_interrupt() {
    progress_bar_destroy_scroll_area
    exit
}

progress_bar_printf_new() {
    str=$1
    num=$2
    v=$(printf "%-${num}s" "$str")
    echo -ne "${v// /$str}"
}


# SPDX-License-Identifier: MIT
#
# Copyright (c) 2018--2020 Polle Vanhoof
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.