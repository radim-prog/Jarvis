#!/bin/bash
# merge-guard — pre-merge governance check for GitHub PRs.
#
# Usage: merge-guard.sh <owner/repo> <pr_number> [--auto-merge]
#   --auto-merge: actually execute `gh pr merge --squash` if all checks pass
#   Without flag: dry-run, prints verdict only
#
# Rejects merge if:
#   1. PR is draft
#   2. mergeable != MERGEABLE (conflicts, unknown)
#   3. last CI run conclusion != SUCCESS (NEUTRAL is allowed)
#   4. PR body / comments / labels contain block-words:
#      REVISE / NO-GO / CRITICAL / MAJOR / REQUEST CHANGES / DO NOT MERGE
#      / CHANGES_REQUESTED
#
# Requires: gh CLI authenticated, python3.

set -e

REPO="$1"
PR="$2"
AUTOMERGE="${3:-}"

if [ -z "$REPO" ] || [ -z "$PR" ]; then
  echo "Usage: $0 <owner/repo> <pr_number> [--auto-merge]"
  exit 1
fi

DATA=$(gh pr view "$PR" --repo "$REPO" --json isDraft,mergeable,statusCheckRollup,body,labels,comments,title,reviewDecision 2>&1)
if [ $? -ne 0 ] || [ -z "$DATA" ]; then
  echo "FAIL: Cannot fetch PR data — $DATA"
  exit 2
fi

# Check 1: draft
IS_DRAFT=$(echo "$DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['isDraft'])")
if [ "$IS_DRAFT" = "True" ]; then
  echo "REJECT: PR is draft"
  exit 3
fi

# Check 2: mergeable
MERGEABLE=$(echo "$DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['mergeable'])")
if [ "$MERGEABLE" != "MERGEABLE" ]; then
  echo "REJECT: mergeable=$MERGEABLE (need MERGEABLE)"
  exit 4
fi

# Check 3: last CI conclusion
CI_RESULT=$(echo "$DATA" | python3 -c "
import sys, json
d = json.load(sys.stdin)
checks = d.get('statusCheckRollup', [])
if not checks:
    print('NONE')
else:
    last = checks[-1]
    conclusion = last.get('conclusion')
    status = last.get('status')
    print(conclusion or status or 'UNKNOWN')
")
if [ "$CI_RESULT" != "SUCCESS" ] && [ "$CI_RESULT" != "NEUTRAL" ]; then
  echo "REJECT: CI=$CI_RESULT (need SUCCESS)"
  exit 5
fi

# Check 4: block-words in body/comments/labels
BLOCKER=$(echo "$DATA" | python3 -c "
import sys, json, re
d = json.load(sys.stdin)
text_blob = (d.get('title','') + ' ' + d.get('body','') or '')
for c in d.get('comments', []):
    text_blob += ' ' + c.get('body','')
for lbl in d.get('labels', []):
    text_blob += ' ' + lbl.get('name','')

patterns = [
    r'\bREVISE\b', r'\bNO-GO\b', r'\bCRITICAL\b', r'\bMAJOR\b',
    r'\bREQUEST.{0,5}CHANGES\b', r'\bDO\s+NOT\s+MERGE\b',
    r'\bCHANGES_REQUESTED\b',
]
for p in patterns:
    m = re.search(p, text_blob, re.IGNORECASE)
    if m:
        print(m.group(0))
        sys.exit(0)
print('')
")
if [ -n "$BLOCKER" ]; then
  echo "REJECT: blocker found in body/comments/labels: '$BLOCKER'"
  exit 6
fi

echo "OK: PR #$PR ready to merge"
echo "  isDraft=$IS_DRAFT mergeable=$MERGEABLE ci=$CI_RESULT no-blocker-keywords"

if [ "$AUTOMERGE" = "--auto-merge" ]; then
  echo "Executing: gh pr merge $PR --repo $REPO --squash"
  gh pr merge "$PR" --repo "$REPO" --squash 2>&1
  exit $?
else
  echo "Dry-run. Add --auto-merge to execute."
fi
