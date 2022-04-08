## Setup:

```bash
pushd "$HOME/.config/ranger"
git submodule sync
git submodule update --init
popd

sudo apt update && sudo apt install -y transmission-cli mediainfo \
poppler-utils caca-utils sqlite3 atool unrar p7zip p7zip-rar pandoc catdoc \
highlight w3m odt2txt elinks webp imagemagick unrar
pip3 install --user -U ranger-fm xlsx2csv mdv Pygments
```

