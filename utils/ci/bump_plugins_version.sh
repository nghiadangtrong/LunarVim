#!/usr/bin/env bash
set -eo pipefail

REPO_DIR=$(git rev-parse --show-toplevel)

plugins="$REPO_DIR/lua/lvim/plugins.lua"
temp="$(mktemp)"
commits="$PWD/commits.lua"

lvim --headless -c "lua require('lvim.utils.git').generate_plugins_sha()" -c 'qall'

# remove the first paragraph 'local commits = ..'
sed -e '1,/^$/ d' "$plugins" >"$temp"

# overwrite the plugins file with updated values (while adding a line-break)
awk 'NR>1 && FNR==1{print ""};1' "$commits" "$temp" >"$plugins"
