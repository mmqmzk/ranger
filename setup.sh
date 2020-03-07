#!/usr/bin/env bash

DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}"
pushd "$DIR"
if [[ ! -e ranger ]]; then
  git clone git@github.com:mmqmzk/ranger.git || git clone https://github.com/mmqmzk/ranger.git
fi
pushd ranger
eval "$(sed -n '0,/```/d;/```/q;p' README.md)"
popd
popd
