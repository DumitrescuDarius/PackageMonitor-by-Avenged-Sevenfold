LOG_FILE="/var/log/dpkg.log"
DATA_DIR="./data"

INSTALLED_DB="$DATA_DIR/installed.db"
CHECKPOINT="$DATA_DIR/checkpoint"

if [[ ! -f "$CHECKPOINT" ]]; then
    echo "Database not initialized. Run init.sh first."
    exit 1
fi

declare -A packages
declare -A dates

while IFS=$'\t' read -r package version date; do
    packages["$package"]="$version"
    dates["$package"]="$date"
done < "$INSTALLED_DB"

OFFSET=$(cat "$CHECKPOINT")
CURRENT_SIZE=$(wc -c < "$LOG_FILE")

if (( CURRENT_SIZE < OFFSET )); then
    echo "Log rotation detected. Reinitialization required."
    ./init.sh
    exit 0
fi

tail -c +$((OFFSET + 1)) "$LOG_FILE" |
while read -r date time action field4 field5 field6; do

    package=""
    version=""

    if [[ "$action" == "install" ]]; then
        package="$field4"
        version="$field6"

        packages["$package"]="$version"
        dates["$package"]="$date"

    elif [[ "$action" == "upgrade" ]]; then
        package="$field4"
        version="$field6"

        packages["$package"]="$version"

    elif [[ "$action" == "status" && "$field4" == "installed" ]]; then
        package="$field5"
        version="$field6"

        packages["$package"]="$version"

    elif [[ "$action" == "remove" || "$action" == "purge" ]]; then
        package="$field4"

        unset 'packages[$package]'
        unset 'dates[$package]'

    else
        continue
    fi

    mkdir -p "$DATA_DIR/packages/$package"

    echo "$date $time $action $version" \
        >> "$DATA_DIR/packages/$package/history.log"

    echo "$date $time $package $action $version" \
        >> "$DATA_DIR/dates/$date.log"

    echo "Detected: $action $package"

    : > "$INSTALLED_DB"

    for pkg in "${!packages[@]}"; do
        printf '%s\t%s\t%s\n' \
            "$pkg" \
            "${packages[$pkg]}" \
            "${dates[$pkg]}" >> "$INSTALLED_DB"
    done

done

wc -c < "$LOG_FILE" > "$CHECKPOINT"

