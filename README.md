## Setup:
```bash
pushd /tmp
rm -rf ranger_devicons
git clone https://github.com/alexanderjeurissen/ranger_devicons.git
pushd ranger_devicons
make install
popd
rm -rf ranger_devicons
popd

sudo apt update && sudo apt install transmission-cli mediainfo poppler-utils caca-utils sqlite3 atool unrar p7zip-full pandoc catdoc highlight w3m odt2txt elinks webp imagemagick unrar
pip3 install --user -U ranger-fm xlsx2csv
```

