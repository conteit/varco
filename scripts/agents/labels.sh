#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Idempotently creates the labels used by the agent loop (ADR-0016). Usage: labels.sh [<owner>/<name>]
set -euo pipefail
repo="${1:-}"

# name|color|description
while IFS='|' read -r name color desc; do
  gh label create "$name" --force --color "$color" --description "$desc" ${repo:+--repo "$repo"}
done <<'LABELS'
agent-ready|0E8A16|Ready for an implementer session
in-progress|FBCA04|An agent session is working on it
needs-design|D93F0B|Waiting for a Design comment
design:ready|0E8A16|Design comment posted
needs-replan|D93F0B|Escalated; planner must revise the Design
needs-human|B60205|Needs the owner; blocks the review gate
model:haiku|5319E7|Implement with Haiku
model:sonnet|5319E7|Implement with Sonnet
model:opus|5319E7|Implement with Opus
round:1|C5DEF5|Review fix round 1
round:2|C5DEF5|Review fix round 2
risk:low|BFD4F2|Reviewer risk rating
risk:medium|FEF2C0|Reviewer risk rating
risk:high|F9D0C4|Reviewer risk rating
size:L|FEF2C0|Over the PR size budget
human-review:pending|FBCA04|Merged; awaiting owner review
human-review:ok|0E8A16|Owner reviewed after merge
disagreement|B60205|Owner disagrees with a merged change
bug|D73A4A|Something is broken
rc:testing|FBCA04|Release candidate under manual test
rc:passed|0E8A16|Release candidate passed manual tests
rc:failed|B60205|Release candidate failed manual tests
docs:none|EDEDED|No docs change needed (justification required)
LABELS
