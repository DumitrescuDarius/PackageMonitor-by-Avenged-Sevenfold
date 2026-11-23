LOG_FILE="/var/log/dpkg.log"
DATA_DIR="./data"

if [[ "$DATA_DIR" ]]; then 
    echo "Removing current database..."
    rm -rf "$DATA_DIR/"
fi

mkdir -p "$DATA_DIR/packages"
mkdir -p "$DATA_DIR/dates"
touch "$DATA_DIR/installed.db"
touch "$DATA_DIR/removed.db"

printf '%s\t%s\t%s\n' "name" "version" "date" \
        >> "$DATA_DIR/installed.db"

printf '%s\t%s\t%s\n' "name" "date" \
        >> "$DATA_DIR/removed.db"

echo "Initializing package database..."

declare -A packages
declare -A dates

while read -r date time action field4 field5 field6; do
    PACKAGE=""
    VERSION=""

    if [[ "$action" == "install" ]]; then
        PACKAGE="$field4"
        VERSION="$field5"
        packages["$field4"]="$field6"
        dates["$field4"]="$date"

    elif [[ "$action" == "upgrade" ]]; then
        PACKAGE="$field4"
        VERSION="$field5"
        packages["$field4"]="$field6"

    elif [[ "$action" == "status" && "$field4" == "installed" ]]; then
        PACKAGE="$field5"
        VERSION="$field6"
        packages["$field5"]="$field6"

    elif [[ "$action" == "remove" || "$action" == "purge" ]]; then
        PACKAGE="$field4"
        VERSION="$field5"
        unset 'packages[$PACKAGE]'
        unset 'dates[$PACKAGE]'
        printf '%s\t%s\t%s\n' "$PACKAGE" "$date" \
            >> "$DATA_DIR/removed.db"
    fi

    [[ -z "$PACKAGE" ]] && continue

    if [[ ! -f "$DATA_DIR"/packages/"$PACKAGE".log ]]; then
        touch "$DATA_DIR"/packages/"$PACKAGE".log
    fi
    printf '%s\t%s\t%s\t%s\n' "$date" "$time" "$action" "$VERSION" \
        >> "$DATA_DIR"/packages/"$PACKAGE".log

    if [[ ! -f "$DATA_DIR"/dates/"$date" ]]; then
        touch "$DATA_DIR"/dates/"$date".log
    fi
    printf '%s\t%s\t%s\t%s\n' "$date" "$time" "$action" "$VERSION" \
        >> "$DATA_DIR"/dates/"$date".log

done < "$LOG_FILE"

for package in "${!packages[@]}"; do
    echo -e "$package\t${packages[$package]}\t${dates[$package]}" >> "$DATA_DIR/installed.db"
done

wc -c < "$LOG_FILE" > "$DATA_DIR/checkpoint"

echo "Initialization complete!"


echo "Starting monitor..."
./monitor.sh