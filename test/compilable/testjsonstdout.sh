#!/usr/bin/env bash

set -ueo pipefail

name="$(basename "$0" .sh)"
dir="${RESULTS_DIR}/compilable/"
out="$dir/${name}.json.out"

"$DMD" -X > "$out"
diff "$out" compilable/extra-files/$name.json
rm "$out"

"$DMD" -Xf=- > "$out"
diff "$out" compilable/extra-files/$name.json
rm "$out"

"$DMD" -Xf="$out"
diff "$out" compilable/extra-files/$name.json
rm "$out"

echo "OK" > "${dir}/${name}.sh.out"
