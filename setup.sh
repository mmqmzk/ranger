#!/usr/bin/env bash

set -xe

DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}"
cd "$DIR"
if [[ ! -e ranger ]]; then
  git clone git@github.com:mmqmzk/ranger.git || git clone https://github.com/mmqmzk/ranger.git
fi
cd ranger
if [[ "$*" == *termux* ]]; then
  git checkout termux
fi
eval "$(sed -n '0,/```/d;/```/q;p' README.md)"
