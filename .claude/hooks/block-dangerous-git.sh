#!/usr/bin/env bash
# PreToolUse hook: blocks destructive / rule-breaking git commands before Claude runs them.
# Wired up in .claude/settings.json for the Bash and PowerShell tools. Exit 2 = block, and
# stderr is shown to Claude. Matches against the raw hook JSON, so no jq is required.
# A human can still run any of these deliberately with the `!` prefix in the prompt.

INPUT=$(cat)

# Only inspect commands that actually invoke git.
echo "$INPUT" | grep -qE 'git[[:space:]]' || exit 0

block() {
  echo "BLOCKED by .claude/hooks/block-dangerous-git.sh: $1. This repo's rules forbid it for Claude; if it's truly needed, ask the user to run it themselves." >&2
  exit 2
}

# End of an argument: whitespace, closing JSON quote, or a shell separator.
END='([[:space:]]|"|;|&|\||$)'

echo "$INPUT" | grep -qE "push[^;&|]*(--force|--force-with-lease|[[:space:]]-f$END|[[:space:]]\+)" \
  && block "force-push rewrites shared history"
echo "$INPUT" | grep -qE "push[^;&|]*([[:space:]]|:)(main|master)$END" \
  && block "pushing directly to main bypasses the PR + squash-merge flow"
echo "$INPUT" | grep -qE 'reset[[:space:]]+(.*[[:space:]])?--hard' \
  && block "git reset --hard discards uncommitted work"
echo "$INPUT" | grep -qE 'clean[[:space:]]+(.*[[:space:]])?-[a-zA-Z]*f' \
  && block "git clean -f permanently deletes untracked files"
echo "$INPUT" | grep -qE 'branch[[:space:]]+(.*[[:space:]])?(-D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)' \
  && block "git branch -D deletes a branch even if it is unmerged"
echo "$INPUT" | grep -qE "(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.$END" \
  && block "checkout/restore . discards all uncommitted changes"
echo "$INPUT" | grep -qE -- '--no-verify' \
  && block "--no-verify skips the hooks that keep main green"

exit 0
