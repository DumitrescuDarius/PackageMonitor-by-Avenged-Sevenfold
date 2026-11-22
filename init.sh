LOG_FILE="/var/log/dpkg.log"
DATA_DIR="./data"

mkdir -p "$DATA_DIR/packages"
mkdir -p "$DATA_DIR/dates"

if [[ ! -f "$DATA_DIR/checkpoint" ]]; then
    echo "Initializing package database..."

    declare -A packages
    declare -A dates

    while read -r date time action field4 field5 field6; do

        if [[ "$action" == "install" ]]; then
            packages["$field4"]="$field6"
            dates["$field4"]="$date"

        elif [[ "$action" == "upgrade" ]]; then
            packages["$field4"]="$field6"

        elif [[ "$action" == "status" && "$field4" == "installed" ]]; then
            packages["$field5"]="$field6"

        elif [[ "$action" == "remove" || "$action" == "purge" ]]; then
            unset 'packages[$field4]'
            unset 'dates[$field4]'
        fi

    done < "$LOG_FILE"

    for package in "${!packages[@]}"; do
        echo -e "$package\t${packages[$package]}\t${dates[$package]}" >> "$DATA_DIR/installed.db"
    done

    wc -c < "$LOG_FILE" > "$DATA_DIR/checkpoint"

    echo "Initialization complete!"
else
    echo "Database already initialized."
fi

echo "Starting monitor..."
./monitor.sh