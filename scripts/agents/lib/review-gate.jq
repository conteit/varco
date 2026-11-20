# Review gate (ADR-0016 section 5, a-e). Input: state JSON; --arg owner, --argjson budget.
# Output: one failure string per violated rule; empty output = pass.
def bad: ["failure", "cancelled", "timed_out", "action_required", "error"];
# Generated files do not count against the size budget; later tasks extend this list.
def generated: test("(^|/)pnpm-lock\\.yaml$|^frontend/src/app/api/schema\\.d\\.ts$|/__screenshots__/|\\.snap$");

.pr.head.sha as $head
| (.pr.user.login == "dependabot[bot]" and .pr.user.type == "Bot") as $dependabot
| (.reviews | sort_by(.submitted_at)) as $reviews

# (a) latest decisive review by the reviewer App on the head SHA approves; nothing requested changes after it
| ([$reviews[] | select(.user.login == "varco-reviewer[bot]" and .user.type == "Bot"
      and .commit_id == $head and (.state == "APPROVED" or .state == "CHANGES_REQUESTED"))] | last) as $decision
| (if $decision == null or $decision.state != "APPROVED"
   then "FAIL (a): no current approval from varco-reviewer[bot] on the head commit"
   elif any($reviews[]; .state == "CHANGES_REQUESTED" and .submitted_at > $decision.submitted_at)
   then "FAIL (a): changes were requested after the approval"
   else empty end),

# (b) needs-human absent; once added, only the owner may have removed it
  (if any(.pr.labels[]?; .name == "needs-human") then "FAIL (b): needs-human is set" else empty end),
  (([.events[] | select(.label.name == "needs-human" and .event == "unlabeled")] | sort_by(.created_at) | last) as $removed
   | if $removed != null and $removed.actor.login != $owner then "FAIL (b): needs-human was removed by \($removed.actor.login), not the owner" else empty end),

# (c) no other check or status failed (pending ones are left to the ruleset's required checks)
  (.checks[] | select(.name != "review-gate" and .name != "review-gate-eval"
      and (.result as $r | $r != null and (bad | index($r)) != null)) | "FAIL (c): check \(.name) concluded \(.result)"),

# (d) size budget, unless the owner approved the head commit
  ([.files[] | select(.filename | generated | not) | .additions + .deletions] | add // 0) as $size
  | (any($reviews[]; .user.login == $owner and .state == "APPROVED" and .commit_id == $head)) as $ownerApproved
  | (if $size > $budget and ($ownerApproved | not) then "FAIL (d): \($size) changed lines exceed the \($budget) budget" else empty end),

# (e) exactly one issue reference, pointing at an open issue (not a PR)
  ([(.pr.body // "") | match("(closes|fixes|resolves|part of) #([0-9]+)"; "gi") | .captures[1].string | tonumber]) as $refs
  | if $dependabot then empty
    elif ($refs | length) != 1 then "FAIL (e): PR body needs exactly one Closes/Fixes/Resolves/Part of #n reference (found \($refs | length))"
    elif .issue == null or .issue.number != $refs[0] or .issue.state != "open" or .issue.pull_request != null
    then "FAIL (e): #\($refs[0]) is not an open issue"
    else empty end
