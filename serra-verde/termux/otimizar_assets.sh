#!/data/data/com.termux/files/usr/bin/bash
# Reduz texturas (máx. 1024 px) e converte áudio para .ogg.
# Uso: ./termux/otimizar_assets.sh pasta_de_origem pasta_destino
set -e
src="$1"; dst="$2"; mkdir -p "$dst"
for f in "$src"/*.{png,jpg,jpeg}; do [ -f "$f" ] && convert "$f" -resize '1024x1024>' -quality 88 "$dst/$(basename "${f%.*}").jpg"; done
for f in "$src"/*.{wav,mp3,flac,m4a}; do [ -f "$f" ] && ffmpeg -y -loglevel error -i "$f" -c:a libvorbis -q:a 4 "$dst/$(basename "${f%.*}").ogg"; done
echo "Assets otimizados em $dst"
