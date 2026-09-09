#!/bin/bash
set -euo pipefail

echo "cinema-engine — installing…"
echo

curl -fsSL https://raw.githubusercontent.com/jotx19/cinema-engine/main/install.sh | bash

echo
echo "Done. You can close this window."
read -r -p "Press Return to exit… " _
