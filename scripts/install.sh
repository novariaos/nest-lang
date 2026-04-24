#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_RB="$SCRIPT_DIR/src/main.rb"

if [ ! -f "$MAIN_RB" ]; then
    echo "install.sh: $MAIN_RB not found."
    exit 1
fi

cat > /usr/bin/nest << EOF
#!/bin/sh

exec ruby "$MAIN_RB" "\$@"
EOF

chmod +x /usr/bin/nest

echo "Complete."