#!/bin/sh

set -e

: "${WORKDIR:=/app/downloads}"
: "${SLEEPTIME:=600}"
: "${BASE_OUTPUT:=/app/output}"
: "${OUTPUTFOLDER:=streamername}"

convert_ts_to_mp4() {
    processed_dir="${WORKDIR}/processed"
    mkdir -p "${processed_dir}"
    echo "Starting conversion of .ts files in ${WORKDIR}..."

    find "${WORKDIR}" -maxdepth 1 -type f -name "*.ts" | while read -r ts_file; do
        year=$(stat -c %y "${ts_file}" | cut -d- -f1)
        month=$(stat -c %y "${ts_file}" | cut -d- -f2)
        
        base_folder="${BASE_OUTPUT}/${OUTPUTFOLDER}-${year}/${month}"
        mkdir -p "${base_folder}"

        mp4_file="${base_folder}/$(basename "${ts_file%.ts}").mp4"
        
        echo "Converting '${ts_file}' to '${mp4_file}'..."

        ffmpeg -i "${ts_file}" \
          -hide_banner -loglevel error \
          -map 0:v -map 0:a? \
          -af "loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=-33.0:measured_TP=-4.9:measured_LRA=19.3:measured_thresh=-45.4:offset=0.3:linear=true:print_format=summary" \
          -c:v copy -c:a aac -b:a 192k \
          "${mp4_file}"

        if [ $? -eq 0 ]; then
            echo "Successfully converted to '${mp4_file}'."
            echo "Moving original .ts file to processed directory..."
            mv "${ts_file}" "${processed_dir}/"
        else
            echo "Failed to convert '${ts_file}'."
        fi
    done
}

convert_ts_to_mp4

echo "All tasks completed successfully. Sleeping for $SLEEPTIME seconds..."
sleep $SLEEPTIME
