#!/bin/bash

# Fixes https://github.com/nextcloud/vm/issues/58
a2dismod status
service apache restart

exit 0
