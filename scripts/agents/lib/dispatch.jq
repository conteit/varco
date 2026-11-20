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

def label_names: [.labels[].name];
def labelled($n): label_names | index($n) != null;
# "[T1] Title" -> T1, otherwise GH<number>
def issue_id: (.title | capture("^\\[(?<id>[A-Za-z0-9]+)\\]").id) // "GH\(.number)";
def slug: .title | sub("^\\[[A-Za-z0-9]+\\]\\s*"; "") | ascii_downcase | gsub("[^a-z0-9]+"; "-") | .[0:40] | sub("^-+"; "") | sub("-+$"; "");
def branch_type:
  if labelled("bug") or labelled("disagreement") then "fix" elif labelled("area:docs") then "docs" else "feat" end;
# <type>/<ID>-<slug>; -r<N> when the branch already exists on the remote (after a re-plan).
def branch($existing):
  "\(branch_type)/\(issue_id)-\(slug)" as $b
  | if ($existing | index($b)) == null then $b
    else first(range(2; 100) | "\($b)-r\(.)" | select(. as $c | $existing | index($c) == null)) end;

# Input: {issues: all open issues, prs: open PRs, branches: remote branch names}.
# Output: runnable issues of the milestone, best first, as {number, id, branch, model}.
# Order: disagreement > bug > lowest wave > lowest number.
def next_issues($milestone):
  (.issues | map(.number)) as $open
  | (.prs | map(.head.ref)) as $heads
  | .branches as $branches
  | [.issues[]
     | select(.pull_request == null and .milestone.title == $milestone)
     | select(.author_association == "OWNER" or .user.login == "varco-impl[bot]")
     | select(labelled("agent-ready"))
     | . as $i | select(any("in-progress", "needs-design", "needs-replan", "needs-human"; . as $n | $i | labelled($n)) | not)
     | select(deps | all(. as $d | ($open | index($d)) == null))
     | issue_id as $id | select(all($heads[]; contains("/\($id)-") | not))
     | {number, id: $id, branch: branch($branches),
        model: ((label_names | map(select(startswith("model:")) | .[6:]) | first) // "sonnet"),
        key: [(if labelled("disagreement") then 0 elif labelled("bug") then 1 else 2 end),
              ((label_names | map(select(startswith("wave:")) | .[5:] | tonumber) | first) // 99), .number]}]
  | sort_by(.key) | map(del(.key))[];
