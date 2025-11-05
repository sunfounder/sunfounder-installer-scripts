#!/bin/bash
# https://github.com/pollev/bash_progress_bar - Optimized version
# Version: 1.1.0

# Usage:
# Source this script
# enable_trapping <- optional to clean up properly if user presses ctrl-c
# setup_scroll_area <- create empty progress bar
# draw_progress_bar 10 <- advance progress bar
# draw_progress_bar 40 <- advance progress bar
# block_progress_bar 45 <- turns the progress bar yellow to indicate some action is requested from the user
# draw_progress_bar 90 <- advance progress bar
# destroy_scroll_area <- remove progress bar

# Check for required commands
if ! command -v tput &> /dev/null || ! command -v date &> /dev/null; then
    echo "Error: Required commands (tput, date) are not available." >&2
    return 1
fi

# Check if we're in an interactive terminal
if [ ! -t 1 ] && [ -z "$TERM" ]; then
    echo "Warning: Running in non-interactive mode. Progress bar may not display correctly." >&2
fi

# Constants
readonly CODE_SAVE_CURSOR="\033[s"
readonly CODE_RESTORE_CURSOR="\033[u"
readonly CODE_CURSOR_IN_SCROLL_AREA="\033[1A"
readonly COLOR_FG="\e[30m"
readonly COLOR_BG="\e[42m"
readonly COLOR_BG_BLOCKED="\e[43m"
readonly RESTORE_FG="\e[39m"
readonly RESTORE_BG="\e[49m"
readonly MAX_BAR_SIZE=100

# Global Variables (minimized and properly initialized)
PROGRESS_BLOCKED="false"
TRAPPING_ENABLED="false"
ETA_ENABLED="false"
TRAP_SET="false"

CURRENT_NR_LINES=0
PROGRESS_TITLE=""
PROGRESS_TOTAL=100
PROGRESS_START=0
BLOCKED_START=0

# Function to validate percentage values
validate_percentage() {
    local percentage=$1
    if ! [[ "$percentage" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid percentage value: $percentage" >&2
        return 1
    fi
    if [ "$percentage" -lt 0 ] || [ "$percentage" -gt 100 ]; then
        echo "Warning: Percentage value ($percentage) is outside valid range (0-100), clamping to range." >&2
        percentage=$((percentage < 0 ? 0 : percentage > 100 ? 100 : percentage))
    fi
    echo "$percentage"
    return 0
}

# Setup scroll area for progress bar
setup_scroll_area() {
    # If trapping is enabled, activate it
    if [ "$TRAPPING_ENABLED" = "true" ] && [ "$TRAP_SET" = "false" ]; then
        trap_on_interrupt
    fi

    # Handle parameters with proper validation
    local title="${1:-Progress}"
    local total=${2:-100}
    
    # Validate total parameter
    if ! [[ "$total" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid total value: $total" >&2
        total=100
    fi
    
    # Set global variables
    PROGRESS_TITLE="$title"
    PROGRESS_TOTAL=$total

    # Get terminal lines safely
    local lines
    lines=$(tput lines 2>/dev/null || echo 24)
    CURRENT_NR_LINES=$lines
    lines=$((lines > 1 ? lines - 1 : 1))
    
    # Scroll down a bit to avoid visual glitch
    echo -en "\n"

    # Save cursor and set scroll region
    echo -en "$CODE_SAVE_CURSOR"
    echo -en "\033[0;${lines}r"
    echo -en "$CODE_RESTORE_CURSOR"
    echo -en "$CODE_CURSOR_IN_SCROLL_AREA"

    # Store start timestamp for ETA calculation
    if [ "$ETA_ENABLED" = "true" ]; then
        PROGRESS_START=$(date +%s 2>/dev/null || echo 0)
    fi

    # Start with empty progress bar
    draw_progress_bar 0
}

# Destroy scroll area and clean up
destroy_scroll_area() {
    local lines
    lines=$(tput lines 2>/dev/null || echo 24)
    
    # Save cursor and reset scroll region
    echo -en "$CODE_SAVE_CURSOR"
    echo -en "\033[0;${lines}r"
    echo -en "$CODE_RESTORE_CURSOR"
    echo -en "$CODE_CURSOR_IN_SCROLL_AREA"

    # Clear progress bar
    clear_progress_bar

    # Scroll down to avoid visual glitch
    echo -en "\n\n"

    # Reset state for next usage
    PROGRESS_TITLE=""
    PROGRESS_BLOCKED="false"

    # Remove trap if set
    if [ "$TRAP_SET" = "true" ]; then
        trap - EXIT
        TRAP_SET="false"
    fi
}

# Format ETA time
format_eta() {
    local T=$1
    
    # Validate input
    if ! [[ "$T" =~ ^[0-9]+$ ]] || [ "$T" -lt 0 ]; then
        echo "--:--:--"
        return
    fi
    
    # Calculate time components safely
    local D=$((T/60/60/24))
    local H=$((T/60/60%24))
    local M=$((T/60%60))
    local S=$((T%60))
    
    # Handle zero case
    if [ "$D" -eq 0 ] && [ "$H" -eq 0 ] && [ "$M" -eq 0 ] && [ "$S" -eq 0 ]; then
        echo "--:--:--"
        return
    fi
    
    # Format output
    if [ "$D" -gt 0 ]; then
        printf '%d days, ' "$D"
    fi
    printf 'ETA: %d:%02d:%02d' "$H" "$M" "$S"
}

# Draw progress bar
draw_progress_bar() {
    local input_percentage=${1:-0}
    local extra="${2:-}"
    local eta=""
    
    # Validate percentage
    local percentage
    percentage=$(validate_percentage "$input_percentage") || return 1
    
    # Calculate ETA if enabled and valid
    if [ "$ETA_ENABLED" = "true" ] && [ "$percentage" -gt 0 ] && [ "$PROGRESS_START" -gt 0 ]; then
        local current_time
        current_time=$(date +%s 2>/dev/null || echo 0)
        
        if [ "$PROGRESS_BLOCKED" = "true" ] && [ "$BLOCKED_START" -gt 0 ]; then
            local blocked_duration=$((current_time - BLOCKED_START))
            PROGRESS_START=$((PROGRESS_START + blocked_duration))
        fi
        
        if [ "$current_time" -gt "$PROGRESS_START" ]; then
            local running_time=$((current_time - PROGRESS_START))
            
            # Avoid division by zero and large numbers
            if [ "$percentage" -ne 0 ] && [ "$running_time" -lt 86400 ]; then  # Less than 24 hours
                local total_time=$((PROGRESS_TOTAL * running_time / percentage))
                local remaining=$((total_time - running_time))
                
                # Cap remaining time to avoid unrealistic ETA
                if [ "$remaining" -lt 604800 ]; then  # Less than a week
                    eta=$(format_eta "$remaining")
                fi
            fi
        fi
    fi
    
    # Adjust percentage based on total if needed
    if [ "$PROGRESS_TOTAL" -ne 100 ]; then
        if [ "$PROGRESS_TOTAL" -eq 0 ]; then
            percentage=100
        else
            # Safe calculation with range check
            local calc_percentage=$((percentage * 100 / PROGRESS_TOTAL))
            percentage=$((calc_percentage > 100 ? 100 : calc_percentage))
        fi
    fi
    
    # Get terminal lines safely
    local lines
    lines=$(tput lines 2>/dev/null || echo 24)
    
    # Handle window resize
    if [ "$lines" -ne "$CURRENT_NR_LINES" ]; then
        setup_scroll_area "$PROGRESS_TITLE" "$PROGRESS_TOTAL"
    fi
    
    # Save cursor and move to last row
    echo -en "$CODE_SAVE_CURSOR"
    echo -en "\033[${lines};0f"
    
    # Clear line
    tput el 2>/dev/null || echo -en "\r\033[K"
    
    # Update state and draw
    PROGRESS_BLOCKED="false"
    print_bar_text "$percentage" "$extra" "$eta"
    
    # Restore cursor
    echo -en "$CODE_RESTORE_CURSOR"
}

# Block progress bar (show as yellow)
block_progress_bar() {
    local input_percentage=${1:-0}
    
    # Validate percentage
    local percentage
    percentage=$(validate_percentage "$input_percentage") || return 1
    
    # Get terminal lines safely
    local lines
    lines=$(tput lines 2>/dev/null || echo 24)
    
    # Save cursor and move to last row
    echo -en "$CODE_SAVE_CURSOR"
    echo -en "\033[${lines};0f"
    
    # Clear line
    tput el 2>/dev/null || echo -en "\r\033[K"
    
    # Update state and draw
    PROGRESS_BLOCKED="true"
    BLOCKED_START=$(date +%s 2>/dev/null || echo 0)
    print_bar_text "$percentage"
    
    # Restore cursor
    echo -en "$CODE_RESTORE_CURSOR"
}

# Clear progress bar
clear_progress_bar() {
    local lines
    lines=$(tput lines 2>/dev/null || echo 24)
    
    # Save cursor and move to last row
    echo -en "$CODE_SAVE_CURSOR"
    echo -en "\033[${lines};0f"
    
    # Clear line
    tput el 2>/dev/null || echo -en "\r\033[K"
    
    # Restore cursor
    echo -en "$CODE_RESTORE_CURSOR"
}

# Print progress bar text with formatting
print_bar_text() {
    local percentage=$1
    local extra="${2:-}"
    local eta="${3:-}"
    local bar_size
    
    # Format extra text
    if [ -n "$extra" ]; then
        extra=" ($extra)"
    fi
    
    # Add ETA if available
    if [ -n "$eta" ]; then
        if [ -n "$extra" ]; then
            extra="$extra $eta"
        else
            extra="$eta"
        fi
    fi
    
    # Calculate bar size safely
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    
    # Ensure minimum space for essential elements
    local min_required=$((9 + ${#PROGRESS_TITLE} + ${#extra}))
    if [ "$cols" -le "$min_required" ]; then
        # Not enough space, just show basic progress
        echo -ne " $PROGRESS_TITLE ${percentage}%"
        return
    fi
    
    # Calculate bar size with reasonable maximum
    bar_size=$((cols - min_required))
    if [ "$bar_size" -gt "$MAX_BAR_SIZE" ]; then
        bar_size=$MAX_BAR_SIZE
    fi
    
    # Determine color based on state
    local color="${COLOR_FG}${COLOR_BG}"
    if [ "$PROGRESS_BLOCKED" = "true" ]; then
        color="${COLOR_FG}${COLOR_BG_BLOCKED}"
    fi
    
    # Calculate progress components
    local complete_size=$(((bar_size * percentage) / 100))
    local remainder_size=$((bar_size - complete_size))
    
    # Generate progress bar string
    local progress_bar
    progress_bar="["$(echo -ne "${color}")"
    progress_bar+="$(printf_new "#" "$complete_size")"
    progress_bar+="$(echo -ne "${RESTORE_FG}${RESTORE_BG}")"
    progress_bar+="$(printf_new "." "$remainder_size")"
    progress_bar+"]"
    
    # Print complete progress bar
    echo -ne " $PROGRESS_TITLE ${percentage}% ${progress_bar}${extra}"
}

# Enable signal trapping
enable_trapping() {
    TRAPPING_ENABLED="true"
}

# Set up interrupt trap
trap_on_interrupt() {
    # Only set trap once
    if [ "$TRAP_SET" = "false" ]; then
        TRAP_SET="true"
        trap cleanup_on_interrupt EXIT INT TERM
    fi
}

# Clean up on interrupt (more graceful exit)
cleanup_on_interrupt() {
    # Save exit code
    local exit_code=$?
    
    # Clean up progress bar
    if [ -n "$PROGRESS_TITLE" ]; then
        destroy_scroll_area
    fi
    
    # Don't force exit, let the calling script handle it
    return "$exit_code"
}

# Helper function to print repeated characters
printf_new() {
    local str="${1:-}"
    local num=${2:-0}
    
    # Validate inputs
    if [ -z "$str" ] || [ "$num" -lt 1 ]; then
        return
    fi
    
    # Create repeated string safely
    printf -v v "%-${num}s" "$str"
    echo -ne "${v// /$str}"
}

# Enable/disable ETA calculation
enable_eta() {
    ETA_ENABLED="true"
}

disable_eta() {
    ETA_ENABLED="false"
}

# SPDX-License-Identifier: MIT
#
# Copyright (c) 2018--2020 Polle Vanhoof
# Copyright (c) 2023--2024 Optimized Version
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