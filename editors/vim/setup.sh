#!/bin/sh

mkdir -p ~/.config/nvim/ftdetect
mkdir -p ~/.config/nvim/after/syntax
cp ftdetect/nest.vim ~/.config/nvim/ftdetect/
cp after/syntax/nest.vim ~/.config/nvim/after/syntax/

sh -c "nvim ../../samples/pyramid.nest"