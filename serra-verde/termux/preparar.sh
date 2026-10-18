#!/data/data/com.termux/files/usr/bin/bash
# Prepara o Termux para trabalhar no projeto (rode uma vez).
set -e
pkg update -y
pkg install -y git gh python python-numpy python-scipy python-pillow ffmpeg imagemagick openssh
echo "Pronto. Próximos passos:"
echo "  gh auth login            (entra no GitHub)"
echo "  git config --global user.name  'Seu Nome'"
echo "  git config --global user.email 'seu@email'"
