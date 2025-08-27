#!/bin/sh

# Security measure: clear .bash_history by default on login
# For more info: https://github.com/nextcloud/vm/issues/2481#issuecomment-1529175048
truncate -s0 "$HOME/.bash_history"

exit 0
