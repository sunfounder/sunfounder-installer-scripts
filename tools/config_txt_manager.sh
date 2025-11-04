#!/bin/bash

config_txt_find() {
    # Check possible config.txt paths
    possible_paths=(
        "/boot/firmware/config.txt"   # New Raspberry Pi OS path
        "/boot/firmware/current/config.txt" # New Ubuntu path
        "/boot/config.txt"            # Traditional path
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Function to read configuration parameter
config_txt_read() {
    local config_file=$1
    local param=$2
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    # Find uncommented parameter
    local value=$(grep -E "^$param=" "$config_file" | cut -d'=' -f2-)
    
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    else
        # Find possibly commented parameter
        local commented_value=$(grep -E "^#$param=" "$config_file" | cut -d'=' -f2-)
        if [ -n "$commented_value" ]; then
            echo "$commented_value"
            return 0
        else
            echo "Parameter '$param' does not exist"
            return 1
        fi
    fi
}

# Function to add or modify configuration parameter
config_txt_set() {
    local config_file=$1
    local line=$2
    local section=${3:-""}  # Optional section parameter, default is empty
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check if parameter exists (uncommented state)
    if grep -q "^$line" "$config_file"; then
        # Parameter exists, modify it
        sed -i "s/^$line.*/$line/" "$config_file"
        echo "Modified line '$line'"
    else
        # Check if parameter exists (commented state)
        if grep -q "^#$line" "$config_file"; then
            # Parameter exists but is commented, uncomment and modify value
            sed -i "s/^#$line.*/$line/" "$config_file"
            echo "Uncommented and modified line '$line'"
        else
            # Parameter doesn't exist, add after section if specified
            if [ -n "$section" ] && grep -q "^\[$section\]" "$config_file"; then
                # Add parameter after section
                sed -i "/^\[$section\]/a $line" "$config_file"
                echo "Added line '$line' in [$section] section"
            else
                # Add parameter at the end of file
                echo "$line" >> "$config_file"
                echo "Added line '$line' at the end of file"
            fi
        fi
    fi
    
    return 0
}

# Function to comment configuration parameter
config_txt_comment() {
    local config_file=$1
    local param=$2
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check if parameter exists (uncommented state)
    if grep -q "^$param" "$config_file"; then
        # Parameter is not commented, add comment symbol
        sed -i "s/^$param/#$param/" "$config_file"
        echo "Commented parameter '$param'"
        return 0
    else
        echo "Parameter '$param' is already commented or does not exist"
        return 1
    fi
}

# Function to remove configuration parameter
config_txt_remove() {
    local config_file=$1
    local param=$2
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    # Remove both uncommented and commented parameters
    local count=$(grep -c "^#*$param=" "$config_file")
    
    if [ $count -gt 0 ]; then
        sed -i "/^#*$param=/d" "$config_file"
        echo "Removed all '$param' related configurations (total $count occurrences)"
        return 0
    else
        echo "Parameter '$param' does not exist"
        return 1
    fi
}

# Function to list all configuration parameters
config_txt_list() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    echo "=== Configuration File Content ($config_file) ==="
    cat "$config_file"
    echo "===================================="
    
    echo "\n=== Uncommented Configuration Parameters ==="
    grep -v "^#" "$config_file" | grep -v "^$" | grep -v "^\["
    
    echo "\n=== Commented Configuration Parameters ==="
    grep "^#" "$config_file" | grep "="
    
    return 0
}

# Function to backup configuration file
config_txt_backup() {
    local config_file=$1
    local backup_file="${config_file}.bak"
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    cp "$config_file" "$backup_file"
    echo "Created backup of configuration file: $backup_file"
    return 0
}

# Function to restore backup
config_txt_restore_backup() {
    local config_file=$1
    local backup_file="${config_file}.bak"
    
    if [ ! -f "$backup_file" ]; then
        echo "Backup file not found: $backup_file"
        return 1
    fi
    
    cp "$backup_file" "$config_file"
    echo "Restored configuration file from backup: $config_file"
    return 0
}
