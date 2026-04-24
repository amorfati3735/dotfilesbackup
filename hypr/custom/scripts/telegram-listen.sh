#!/bin/bash
# Telegram bot listener — long-polls for messages and shows desktop notifications
# Also downloads files sent from phone to ~/Downloads/telegram/

CONF="$HOME/.config/telegram-send.conf"
TOKEN=$(grep '^token' "$CONF" | sed 's/.*= *//')
CHAT_ID=$(grep '^chat_id' "$CONF" | sed 's/.*= *//')
API="https://api.telegram.org/bot${TOKEN}"
DL_DIR="$HOME/Downloads"
OFFSET=0

mkdir -p "$DL_DIR"

download_file() {
    local file_id="$1"
    local filename="$2"

    local file_info
    file_info=$(curl -s "${API}/getFile?file_id=${file_id}")
    local file_path
    file_path=$(echo "$file_info" | jq -r '.result.file_path // empty')

    if [[ -n "$file_path" ]]; then
        [[ -z "$filename" ]] && filename=$(basename "$file_path")
        # Avoid overwriting
        local dest="$DL_DIR/$filename"
        if [[ -e "$dest" ]]; then
            local base="${filename%.*}"
            local ext="${filename##*.}"
            [[ "$base" == "$ext" ]] && ext=""
            dest="$DL_DIR/${base}_$(date +%s).${ext}"
        fi
        curl -s "https://api.telegram.org/file/bot${TOKEN}/${file_path}" -o "$dest"
        notify-send -a "Telegram" "📥 File received" "$filename → ~/Downloads/" -t 5000
    fi
}

while true; do
    RESPONSE=$(curl -s --max-time 120 "${API}/getUpdates?offset=${OFFSET}&timeout=60" 2>/dev/null)

    if [[ $? -ne 0 || -z "$RESPONSE" ]]; then
        sleep 5
        continue
    fi

    COUNT=$(echo "$RESPONSE" | jq '.result | length' 2>/dev/null)
    if [[ "$COUNT" -gt 0 ]]; then
        for i in $(seq 0 $((COUNT - 1))); do
            update_id=$(echo "$RESPONSE" | jq -r ".result[$i].update_id")
            msg_chat_id=$(echo "$RESPONSE" | jq -r ".result[$i].message.chat.id")

            if [[ "$msg_chat_id" != "$CHAT_ID" ]]; then
                OFFSET=$((update_id + 1))
                continue
            fi

            text=$(echo "$RESPONSE" | jq -r ".result[$i].message.text // empty")
            if [[ -n "$text" ]]; then
                notify-send -a "Telegram" "📱 From phone" "$text" -t 8000
            fi

            # Document (PDF, etc.)
            doc_id=$(echo "$RESPONSE" | jq -r ".result[$i].message.document.file_id // empty")
            doc_name=$(echo "$RESPONSE" | jq -r ".result[$i].message.document.file_name // empty")
            if [[ -n "$doc_id" ]]; then
                download_file "$doc_id" "$doc_name"
            fi

            # Photo (grab largest size)
            photo_id=$(echo "$RESPONSE" | jq -r ".result[$i].message.photo[-1].file_id // empty")
            if [[ -n "$photo_id" ]]; then
                download_file "$photo_id" "photo_$(date +%Y%m%d_%H%M%S).jpg"
            fi

            # Video
            video_id=$(echo "$RESPONSE" | jq -r ".result[$i].message.video.file_id // empty")
            video_name=$(echo "$RESPONSE" | jq -r ".result[$i].message.video.file_name // empty")
            if [[ -n "$video_id" ]]; then
                download_file "$video_id" "$video_name"
            fi

            # Audio/Voice
            audio_id=$(echo "$RESPONSE" | jq -r ".result[$i].message.audio.file_id // empty")
            [[ -z "$audio_id" ]] && audio_id=$(echo "$RESPONSE" | jq -r ".result[$i].message.voice.file_id // empty")
            if [[ -n "$audio_id" ]]; then
                download_file "$audio_id" "audio_$(date +%Y%m%d_%H%M%S).ogg"
            fi

            OFFSET=$((update_id + 1))
        done
    fi
done
