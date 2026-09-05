#!/usr/bin/env bash
set -ueo pipefail

results="$1"
clone="$RUNNER_TEMP/perf-data"
key=~/.ssh/perf_data

mkdir -p ~/.ssh
printf '%s\n' "$PERF_DATA_KEY" > "$key"
chmod 600 "$key"
ssh-keyscan github.com >> ~/.ssh/known_hosts 2> /dev/null
export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes"

git clone "git@github.com:$PERF_DATA_REPO.git" "$clone"
cd "$clone"
git config user.name dmd-perf-bot
git config user.email dmd-perf-bot@users.noreply.github.com

dest="data/${COMMITTED_AT:0:4}/${COMMITTED_AT:5:2}"
mkdir -p "$dest"
cp "$results" "$dest/$SHA.json"
git add "$dest/$SHA.json"

if git diff --cached --quiet; then
    echo "$SHA already published"
    exit 0
fi

git commit -m "$SHA"

for _ in 1 2 3; do
    if git push; then
        exit 0
    fi
    git pull --rebase
done
exit 1
