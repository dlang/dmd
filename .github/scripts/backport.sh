#!/usr/bin/env bash

set -ueo pipefail

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

comment()
{
    gh pr comment "$PR_NUMBER" --body "$1"
}

for branch in $(jq -r '.[] | select(startswith("Backport:")) | ltrimstr("Backport:")' <<< "$PR_LABELS"); do
    if ! git rev-parse --verify --quiet "origin/$branch" > /dev/null; then
        comment "Backport to \`$branch\` skipped: no such branch."
        continue
    fi

    if git merge-base --is-ancestor "$PR_SHA" "origin/$branch"; then
        continue
    fi

    head="backport/$PR_NUMBER-$branch"
    if git ls-remote --exit-code --heads origin "$head" > /dev/null; then
        continue
    fi

    git checkout -B "$head" "origin/$branch"

    merged_as_merge_commit=$([ "$(git rev-list --parents -n 1 "$PR_SHA" | wc -w)" -eq 3 ] && echo 1 || echo 0)
    merged_as_squash=$([[ "$(git log -1 --format=%s "$PR_SHA")" == *"(#$PR_NUMBER)" ]] && echo 1 || echo 0)

    if [ "$merged_as_merge_commit" -eq 1 ]; then
        pick=(-m 1 "$PR_SHA")
    elif [ "$merged_as_squash" -eq 0 ] && [ "$PR_COMMITS" -gt 1 ]; then
        pick=("$PR_SHA~$PR_COMMITS..$PR_SHA")
    else
        pick=("$PR_SHA")
    fi

    if ! git cherry-pick -x "${pick[@]}"; then
        git cherry-pick --abort || true
        comment "Backport to \`$branch\` failed to apply cleanly, please do it manually:
\`\`\`sh
git checkout -b $head upstream/$branch
git cherry-pick -x ${pick[*]}
\`\`\`"
        continue
    fi

    git push origin "$head"
    gh pr create --base "$branch" --head "$head" \
        --title "[$branch] $PR_TITLE" \
        --body "Backport of #$PR_NUMBER to \`$branch\`."
done
