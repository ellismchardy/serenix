#!/usr/bin/env bash
# Tests for block-dangerous-git.sh: feeds it PreToolUse JSON and checks the exit code
# (2 = blocked, 0 = allowed). Run after any change to the hook:
#   bash .claude/hooks/block-dangerous-git.test.sh
#
# The hook deliberately over-blocks: it matches the raw tool input, so text that merely
# mentions e.g. "push ... main" (a heredoc PR body) is blocked too. Write such text with the
# file tools instead. Narrowing the patterns risks letting real commands through; the
# regression cases below are the shapes that slipped past an attempt.

HOOK="$(dirname "$0")/block-dangerous-git.sh"
FAILED=0

# $1 = expected exit code, $2 = the command string exactly as it appears inside the JSON
# (so `\"` is a quote, `\\` a backslash, `\n` a line break).
check() {
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" | bash "$HOOK" 2>/dev/null
  local got=$?
  if [ "$got" -ne "$1" ]; then
    echo "FAIL (want $1, got $got): $2"
    FAILED=$((FAILED + 1))
  fi
}
block() { check 2 "$1"; }
allow() { check 0 "$1"; }

# Dangerous commands are blocked.
block 'git push origin main'
block 'git push -u origin main'
block 'git push origin HEAD:main'
block 'git push origin master'
block 'cd repo && git push origin main'
block 'git -C /c/repo push origin main'
block 'git -C C:\\Users\\me\\repo push origin main'
block 'git -c core.x=y push origin main'
block 'git push --force origin feat/x'
block 'git push --force-with-lease origin feat/x'
block 'git push -f origin feat/x'
block 'git push origin +feat/x'
block 'git reset --hard HEAD~1'
block 'git reset -q --hard'
block 'git clean -fd'
block 'git clean -q -fd'
block 'git branch -D feat/x'
block 'git branch --delete --force feat/x'
block 'git checkout .'
block 'git restore -- .'
block 'git commit --no-verify -m wip'
block 'git commit -m wip --no-verify'

# ...however the command is quoted, split across lines, or pointed at another directory.
# Regression cases for bypass shapes found in review.
block 'git commit -m \"wip\" --no-verify'
block 'git commit -am \"fix: a | b\" --no-verify'
block "git commit -m \\\"\$(cat <<'EOF'\\nmsg\\nEOF\\n)\\\" --no-verify"
block 'git commit -m '"'"'a\\b; c'"'"' --no-verify'
block 'git push origin \"feat/x\" --force'
block 'git reset \"HEAD~1\" --hard'
block 'git push \"origin\" main'
block 'git -C \"C:\\my repo\" push origin main'
block 'git -C '"'"'my dir'"'"' push origin main'
block 'git \\\n  push origin main'
block 'git push \\\n  origin main'
block 'git push origin `\n  main'
block 'git reset `\n  --hard'

# Ordinary commands pass.
allow 'git status'
allow 'git push -u origin chore/x'
allow 'git push -q -u origin chore/x 2>&1 | grep -v remote; gh pr create --base main --body-file b.md'
allow 'git branch -d feat/x'
allow 'git checkout main'

# Near-misses at the edges of each pattern pass too.
allow 'git push origin main-fix'
allow 'git push origin feat/main'
allow 'git reset --soft HEAD~1'
allow 'git clean -n'
allow 'git checkout ./src'

if [ "$FAILED" -eq 0 ]; then echo "all hook tests passed"; else echo "$FAILED failed"; fi
[ "$FAILED" -eq 0 ]
