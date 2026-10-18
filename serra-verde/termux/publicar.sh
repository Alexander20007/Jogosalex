#!/data/data/com.termux/files/usr/bin/bash
# Uso: ./termux/publicar.sh "mensagem do commit"
# Envia tudo para o GitHub; o Actions gera o APK sozinho (aba Actions / Releases).
set -e
msg="${1:-atualização}"
git add -A
git commit -m "$msg" || echo "(nada novo para commitar)"
git push
echo "Enviado. Acompanhe em: https://github.com/$(git config --get remote.origin.url | sed -E 's#.*github.com[:/](.*)\.git#\1#')/actions"
