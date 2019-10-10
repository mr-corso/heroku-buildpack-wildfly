#!/usr/bin/env bash

# Recursively find files with Shebang for sh/bash/ksh
# and check them using shellcheck
grep -RE '^#!(/.*/|/usr/bin/env )(sh|bash|ksh)' bin/ lib/ | \
  sed 's/:.*$//' | \
  xargs shellcheck --format=tty