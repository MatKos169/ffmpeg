: '
entrypoint.sh - Script to convert .ts files to .mp4 using ffmpeg with audio normalization.

Overview:
----------
This script automates the conversion of .ts (MPEG-TS) files to .mp4 format, applying audio normalization using ffmpeg. It organizes output files by year and month, and moves processed .ts files to a separate directory. The script is intended for use in automated workflows, such as Docker containers.

Environment Variables:
----------------------
- WORKDIR:       Directory to scan for .ts files. Default: /app/downloads
- SLEEPTIME:     Time (in seconds) to sleep after processing. Default: 600
- BASE_OUTPUT:   Base directory for output .mp4 files. Default: /app/output
- OUTPUTFOLDER:  Subfolder name for organizing output (e.g., streamer name). Default: streamername

Behavior:
---------
- Warns if OUTPUTFOLDER is not overridden from its default value.
- For each .ts file in WORKDIR:
    - Determines year and month from file modification time.
    - Creates output directory structure: BASE_OUTPUT/OUTPUTFOLDER-YYYY/MM
    - Converts .ts to .mp4 using ffmpeg:
        - Copies video stream, encodes audio to AAC (192k), applies loudness normalization.
        - Only the first video and (optionally) first audio stream are mapped.
    - Handles filename collisions by appending an incrementing suffix.
    - Moves successfully processed .ts files to WORKDIR/processed.
    - Tracks and reports failed conversions.
- Sleeps for SLEEPTIME seconds after processing.

Functions:
----------
- convert_ts_to_mp4: Handles the conversion and organization logic.

Exit Codes:
-----------
- The script exits on any unhandled error due to 'set -e'.

Usage:
------
Override environment variables as needed, then run the script.
Example:
    OUTPUTFOLDER=my_streamer WORKDIR=/input SLEEPTIME=300 ./entrypoint.sh
'
#!/bin/sh

set -e

: "${WORKDIR:=/app/downloads}"
: "${SLEEPTIME:=600}"
: "${BASE_OUTPUT:=/app/output}"
# Set OUTPUTFOLDER to the streamer's name; override this variable to avoid using the default placeholder.
: "${OUTPUTFOLDER:=streamername}"

if [ "${OUTPUTFOLDER}" = "streamername" ]; then
    echo "Warning: OUTPUTFOLDER is set to the default value 'streamername'. Please override this variable for correct output organization."
fi

convert_ts_to_mp4() {
    processed_dir="${WORKDIR}/processed"
    mkdir -p "${processed_dir}"
    echo "Starting conversion of .ts files in ${WORKDIR}..."
    failed_count=0

    find "${WORKDIR}" -maxdepth 1 -type f -name "*.ts" -print0 | while IFS= read -r -d '' ts_file; do
        year=$(date -r "${ts_file}" "+%Y")
        month=$(date -r "${ts_file}" "+%m")

        base_folder="${BASE_OUTPUT}/${OUTPUTFOLDER}-${year}/${month}"
        mkdir -p "${base_folder}"

        filename=$(basename "${ts_file%.ts}")
        mp4_file="${base_folder}/${filename}.mp4"

        if [ -e "${mp4_file}" ]; then
            i=1
            while [ -e "${base_folder}/${filename}_${i}.mp4" ]; do
                i=$((i + 1))
            done
            mp4_file="${base_folder}/${filename}_${i}.mp4"
        fi

        echo "Converting '${ts_file}' to '${mp4_file}'..."

        ffmpeg -y -i "${ts_file}" \
          -hide_banner -loglevel error \
          # Map the first video stream and (optionally) the first audio stream; if multiple streams exist, only the first of each is selected.
          -map 0:v -map 0:a? \
          -af "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=summary" \
          -c:v copy -c:a aac -b:a 192k \
          "${mp4_file}"

        if [ $? -eq 0 ]; then
            echo "Successfully converted to '${mp4_file}'."
            echo "Moving original .ts file to processed directory..."
            mv "${ts_file}" "${processed_dir}/"
        else
            echo "Failed to convert '${ts_file}'."
            failed_count=$((failed_count + 1))
        fi
    done

    export FAILED_COUNT=$failed_count
}

convert_ts_to_mp4

if [ "${FAILED_COUNT:-0}" -eq 0 ]; then
    echo "All tasks completed successfully. Sleeping for $SLEEPTIME seconds..."
else
    echo "Some conversions failed (${FAILED_COUNT}). Sleeping for $SLEEPTIME seconds..."
fi

sleep "$SLEEPTIME"
