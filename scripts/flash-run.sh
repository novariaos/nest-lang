#!/bin/sh

echo "→ mv out.bin ~/novariaos/rootfs/bin/test.bin"
mv out.bin ~/novariaos/rootfs/bin/test.bin

echo '→ sh -c "cd ~/novariaos && chorus iso run"'
sh -c "cd ~/novariaos && chorus iso run"