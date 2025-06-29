#!/bin/bash
: '
entrypoint.sh - Script to convert .ts files to .mp4 using ffmpeg with audio normalization.

Automatisiert die Konvertierung von .ts-Dateien zu .mp4 mit Audio-Normalisierung.
'

set -e

: "${WORKDIR:=/app/downloads}"
: "${SLEEPTIME:=600}"
: "${BASE_OUTPUT:=/app/output}"
: "${OUTPUTFOLDER:=streamername}"

# Logging mit Zeitstempel
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

# Warnung bei Defaultnamen
if [ "${OUTPUTFOLDER}" = "streamername" ]; then
    log "⚠️  OUTPUTFOLDER ist auf Standardwert 'streamername' gesetzt. Bitte überschreiben!"
fi

# ffmpeg prüfen
if ! command -v ffmpeg >/dev/null 2>&1; then
    log "❌ Fehler: ffmpeg nicht gefunden. Bitte installieren."
    exit 1
fi

# Variable für aktuelle Datei
CURRENT_MP4=""

# Cleanup bei Container-Stopp
cleanup_on_interrupt() {
    log "⛔ Abbruchsignal empfangen. Cleaning up..."
    if [ -n "$CURRENT_MP4" ] && [ -f "$CURRENT_MP4" ]; then
        log "🗑️  Unvollständige Ausgabedatei wird gelöscht: $CURRENT_MP4"
        rm -f "$CURRENT_MP4"
    fi
    exit 1
}

trap cleanup_on_interrupt SIGINT SIGTERM

convert_ts_to_mp4() {
    processed_dir="${WORKDIR}/processed"
    mkdir -p "${processed_dir}"
    log "🔍 Starte Konvertierung der .ts-Dateien in ${WORKDIR}..."
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

        log "🎞️  Konvertiere '${ts_file}' → '${mp4_file}'..."
        CURRENT_MP4="${mp4_file}"

        ffmpeg -y -nostdin -i "${ts_file}" \
            -hide_banner -loglevel error \
            -map 0:v -map 0:a? \
            -af "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=summary" \
            -c:v copy -c:a aac -b:a 192k \
            "${mp4_file}"

        if [ $? -eq 0 ]; then
            log "✅ Erfolgreich konvertiert: '${mp4_file}'"
            CURRENT_MP4=""
            log "📦 Verschiebe Originaldatei nach '${processed_dir}'..."
            mv "${ts_file}" "${processed_dir}/"
        else
            log "❌ Fehler bei Konvertierung: '${ts_file}'"
            failed_count=$((failed_count + 1))
            CURRENT_MP4=""
        fi
    done

    export FAILED_COUNT=$failed_count
}

convert_ts_to_mp4

if [ "${FAILED_COUNT:-0}" -eq 0 ]; then
    log "✅ Alle Konvertierungen erfolgreich. Schlafe für ${SLEEPTIME}s..."
else
    log "⚠️  Einige Konvertierungen fehlgeschlagen (${FAILED_COUNT}). Schlafe für ${SLEEPTIME}s..."
fi

sleep "$SLEEPTIME"
