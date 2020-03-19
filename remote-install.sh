#!/bin/bash

echo "Downloading dotfiles...";
echo "";

dotfiles="https://github.com/hiroppy/dotfiles/archive/master.tar.gz"
tmpDir="dotfiles-master"

curl -L "$dotfiles" | tar zxv
cd $tmpDir
make install
cd ..
rm -rf $tmpDir
