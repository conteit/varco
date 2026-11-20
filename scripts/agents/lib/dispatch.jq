# Pure selection logic shared by the dispatcher and the workflows.

# Issue numbers named on "Depends on:" lines of an issue body.
def deps: [(.body // "") | split("\n")[] | select(test("^\\s*depends on:"; "i")) | match("#([0-9]+)"; "g") | .captures[0].string | tonumber];

# Input: {closed: <issue number>, issues: [open issues from the REST API]}.
# Output: numbers of open issues that the closing of `closed` leaves with no open dependency.
# Only issues by the owner or varco-impl[bot] are considered, never pull requests or already-labelled ones.
def unblocked:
  (.issues | map(.number)) as $open
  | .closed as $closed
  | [.issues[]
     | select(.pull_request == null)
     | select(.author_association == "OWNER" or .user.login == "varco-impl[bot]")
     | select([.labels[].name] - ["agent-ready", "in-progress", "needs-design", "needs-replan", "needs-human"] == [.labels[].name])
     | deps as $d
     | select(($d | index($closed)) != null and all($d[]; . as $n | $open | index($n) == null))
     | .number];
