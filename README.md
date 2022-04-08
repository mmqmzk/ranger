## Setup:

```bash
pushd "$HOME/.config/ranger"
git submodule sync
git submodule update --init
popd

pkg install -y transmission mediainfo \
poppler libcaca sqlite unrar p7zip pandoc catdoc \
w3m odt2txt elinks libwebp imagemagick unrar
pip3 install --user -U ranger-fm xlsx2csv mdv Pygments
```

