#!/usr/bin/env bash
# github-setup.sh - brings the GitHub configuration to the state described below and verifies it.
#
#   bash scripts/github-setup.sh           # apply changes, then verify
#   bash scripts/github-setup.sh --check   # verify only, change nothing
#
# Idempotent: it can be run many times with the same result.
# Requirements, token scopes and manual settings: scripts/README.md
set -uo pipefail

# ============================ TARGET STATE ============================
OWNER="Piotr-Gajewski"
REPO="$OWNER/face-access-system"
PROJECT_TITLE="face-access-system – Roadmap"
PROJECT_PUBLIC=true                      # anyone can read the board, only the owner can edit it
SPRINT_START="2026-11-23"                # Monday, first day of sprint 0
SPRINT_DAYS=14

# repository topics (shown on the repository page and used by GitHub search)
TOPICS=(
  face-recognition biometrics presentation-attack-detection anti-spoofing
  liveness-detection injection-attacks access-control computer-vision
  opencv onnx-runtime java spring-boot python fastapi react typescript
  raspberry-pi docker security masters-thesis
)

# name|colour|description
LABELS=(
  "area: backend|1D76DB|access-service (Java, Spring Boot)"
  "area: ml|5319E7|biometric-service, models, ML pipeline"
  "area: device|0E8A16|Door reader (Raspberry Pi) and simulator"
  "area: web|FBCA04|Admin panel (React)"
  "area: infra|BFD4F2|Docker, CI/CD, tooling, deployment"
  "area: docs|C5DEF5|System documentation, ADRs, README"
  "area: research|D93F0B|Experiments, datasets, metrics"
  "area: thesis|B60205|Thesis writing (text lives in the private repo)"
  "type: feature|A2EEEF|New functionality"
  "type: bug|D73A4A|Something does not work"
  "type: chore|EDEDED|Maintenance, configuration, refactoring"
  "type: spike|F9D0C4|Time-boxed research or proof of concept"
  "security|000000|Security-relevant change"
  "blocked|E99695|Waiting for something outside the ticket"
)

# title|description
MILESTONES=(
  "Phase 1 – Backbone|One verification from camera to decision. Gate: an enrolled person is recognised and a stranger is rejected."
  "Phase 2 – Skeleton|Complete material for the thesis and the demo: simulator, device, liveness (P) and challenge (W), recording and replay, experiments. Gate: results of the 6 core variants are ready."
  "Phase 3 – Extras|Optional work for learning, CV value and research extensions. Every item can be skipped."
)

# name|colour (GRAY BLUE GREEN YELLOW ORANGE RED PINK PURPLE)|description
STATUS_OPTIONS=(
  "Backlog|GRAY|Idea or task, not refined yet"
  "Ready|BLUE|Refined, has acceptance criteria, can enter a sprint"
  "In Progress|YELLOW|Being worked on (branch exists)"
  "In review|PURPLE|Pull request open, waiting for CI and review"
  "Done|GREEN|Merged or closed"
)
SIZE_OPTIONS=(
  "S|GREEN|Up to one day"
  "M|YELLOW|2-3 days"
  "L|RED|About a week - consider splitting"
)

PROJECT_DESC="Planning board for face-access-system and the master's thesis: two-week sprints, tickets with acceptance criteria."
# The backticks below are Markdown, not command substitution.
# shellcheck disable=SC2016
PROJECT_README='# face-access-system – Roadmap

Planning board for a master'\''s thesis project: a spoof-resistant face recognition access control system ([repository](https://github.com/Piotr-Gajewski/face-access-system)).

## How I work

- **Lightweight Scrum, solo:** two-week sprints, short planning at the start, a few sentences of retrospective at the end.
- **One ticket = one branch = one pull request** with `Closes #N`; merged (squash) only after CI passes.
- **Columns:** Backlog → Ready → In Progress → In review → Done. A ticket becomes *Ready* only when it meets the [Definition of Ready](https://github.com/Piotr-Gajewski/face-access-system/blob/main/CONTRIBUTING.md#definition-of-ready).
- **Size** instead of story points: S (up to a day), M (2–3 days), L (about a week – material to split).
- **Labels:** one `area:` and one `type:` per ticket; milestones are project phases with a gate.
- **Rules in full:** [CONTRIBUTING.md](https://github.com/Piotr-Gajewski/face-access-system/blob/main/CONTRIBUTING.md), with the [Definition of Done](https://github.com/Piotr-Gajewski/face-access-system/blob/main/CONTRIBUTING.md#definition-of-done).'

# protection of the default branch (ruleset)
RULESET_NAME="Protect main"
# Required CI checks (job names). Empty until there is a CI workflow.
REQUIRED_CHECKS=()

# board workflows that must be enabled (names as shown by GitHub)
REQUIRED_WORKFLOWS=("Auto-add to project" "Item added to project" "Pull request linked to issue" "Item closed" "Item reopened" "Pull request merged")
# views: name|layout|filter|visible fields (in order)
# The API cannot set grouping, sorting or the roadmap date fields; section 4 reminds about them.
REQUIRED_VIEWS=(
  "Board|BOARD_LAYOUT|sprint:@current|Title,Size,Labels,Linked pull requests"
  "Planning|TABLE_LAYOUT|-status:Done|Title,Status,Size,Sprint,Milestone,Labels"
  "Thesis|TABLE_LAYOUT|label:\"area: thesis\"|Title,Status,Size,Sprint"
  "Roadmap|ROADMAP_LAYOUT||Title"
)
# =======================================================================

# The "$name" parts below are GraphQL variables, not shell variables.
# shellcheck disable=SC2016
{
  Q_WORKFLOWS='query($login:String!){user(login:$login){projectsV2(first:100){nodes{title workflows(first:30){nodes{name enabled}}}}}}'
  Q_PROJECT='query($login:String!,$n:Int!){user(login:$login){projectV2(number:$n){
    id public shortDescription readme
    repositories(first:20){nodes{nameWithOwner}}
    fields(first:50){nodes{
      ... on ProjectV2Field{id name dataType}
      ... on ProjectV2SingleSelectField{id name dataType options{name color description}}
      ... on ProjectV2IterationField{id name dataType configuration{duration iterations{title startDate}}}}}
    views(first:30){nodes{id name layout filter configuration{visibleFields(first:30){nodes{... on ProjectV2FieldCommon{name}}}} groupByFields(first:5){nodes{... on ProjectV2FieldCommon{name}}}}}
    workflows(first:30){nodes{name enabled}}}}}'
  Q_NEW_SS='mutation($p:ID!,$n:String!,$o:[ProjectV2SingleSelectFieldOptionInput!]!){createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:$n,singleSelectOptions:$o}){clientMutationId}}'
  Q_NEW_IT='mutation($p:ID!,$n:String!,$c:ProjectV2IterationFieldConfigurationInput!){createProjectV2Field(input:{projectId:$p,dataType:ITERATION,name:$n,iterationConfiguration:$c}){clientMutationId}}'
  Q_DEL_FIELD='mutation($f:ID!){deleteProjectV2Field(input:{fieldId:$f}){clientMutationId}}'
  Q_RENAME='mutation($f:ID!,$n:String!){updateProjectV2Field(input:{fieldId:$f,name:$n}){clientMutationId}}'
  Q_UPD_PROJ='mutation($p:ID!,$d:String!,$r:String!,$pub:Boolean!){updateProjectV2(input:{projectId:$p,shortDescription:$d,readme:$r,public:$pub}){clientMutationId}}'
  Q_NEW_VIEW='mutation($p:ID!,$n:String!,$l:ProjectV2ViewLayout!){createProjectV2View(input:{projectId:$p,name:$n,layout:$l}){clientMutationId}}'
  Q_UPD_VIEW='mutation($v:ID!,$f:String!){updateProjectV2View(input:{viewId:$v,filter:$f}){clientMutationId}}'
  Q_UPD_COLS='mutation($v:ID!,$c:[ID!]!){updateProjectV2View(input:{viewId:$v,configuration:{visibleFieldIds:$c}}){clientMutationId}}'
}

# Anything other than no argument or --check is rejected before GitHub is called:
# a mistyped --check must not start the mode that changes settings.
usage() { echo "Usage: bash scripts/github-setup.sh [--check]"; }
CHECK_ONLY=false
if [[ $# -gt 1 ]]; then
  echo "Too many arguments." >&2; usage >&2; exit 2
elif [[ $# -eq 1 ]]; then
  if [[ "$1" != "--check" ]]; then
    echo "Unknown argument: '$1'" >&2; usage >&2; exit 2
  fi
  CHECK_ONLY=true
fi

PASS=0; FAIL=0; MANUAL=0
ok()     { printf '  \e[32m✔\e[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()    { printf '  \e[31m✘\e[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
manual() { printf '  \e[33m●\e[0m %s\n' "$1"; MANUAL=$((MANUAL+1)); }
step()   { printf '\n\e[1m%s\e[0m\n' "$1"; }
apply()  { ! $CHECK_ONLY; }
norm()   { sed 's/[–—-]/-/g' | tr '[:upper:]' '[:lower:]'; }
check_eq() {  # check_eq <found> <expected> <message>
  if [[ "$1" == "$2" ]]; then ok "$3"; else bad "$3 (found: ${1:-none})"; fi
}

gql() {  # gql <query> <JSON variables>
  jq -n --arg q "$1" --argjson v "$2" '{query:$q, variables:$v}' | gh api graphql --input -
}
options_json() {  # turns a "name|COLOUR|description" list into JSON for the API
  printf '%s\n' "$@" | jq -R 'split("|") | {name:.[0], color:.[1], description:.[2]}' | jq -s .
}

# --- board workflows before and after the run ---
# Changing the board can silently switch its workflows off, so their states are compared.
read_workflows() {  # prints {"workflow name": enabled}, {} if there is no board; fails if the states cannot be read
  gql "$Q_WORKFLOWS" "$(jq -n --arg l "$OWNER" '{login:$l}')" |
    jq -ce --arg t "$PROJECT_TITLE" '[.data.user.projectsV2.nodes[] | select(.title==$t)]
      | if length==0 then {} else (.[0].workflows.nodes | map({key:.name, value:.enabled}) | from_entries) end' 2>/dev/null
}
compare_workflows() {
  local after lost
  step "5. Board workflows before and after this run"
  if [[ "$WORKFLOWS_BEFORE" == "{}" ]]; then
    echo "  The board had no workflows before this run, so there is nothing to compare."
  elif ! after=$(read_workflows); then
    bad "Could not read the board workflows after the run; compare them by hand"
  else
    lost=$(jq -rn --argjson b "$WORKFLOWS_BEFORE" --argjson a "$after" \
      '$b | to_entries[] | select(.value and ($a[.key] != true)) | "\"\(.key)\" \(if $a[.key]==false then "was switched off" else "disappeared" end)"')
    if [[ -z "$lost" ]]; then
      ok "No workflow was switched off"
    else
      while IFS= read -r line; do bad "Workflow $line during this run"; done <<<"$lost"
    fi
  fi
}
abort() {  # end the run early, but still report the workflows, because earlier sections may have made changes
  compare_workflows
  step "Summary"; echo "  Aborted."; exit 1
}

# --- requirements ---
command -v gh >/dev/null || { echo "gh is missing: https://cli.github.com" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is missing: sudo apt install -y jq" >&2; exit 1; }
# --no-refresh: this command alone could otherwise replace an expiring token, also in --check mode
AUTH=$(gh auth status --active --hostname github.com --no-refresh --json hosts) \
  || { echo "Could not read the gh login state (see the message above)." >&2; exit 1; }
if [[ "$(jq -r '[.hosts["github.com"][]? | select(.active)][0].state // empty' <<<"$AUTH")" != "success" ]]; then
  echo "gh is not logged in: gh auth login" >&2; exit 1
fi
if ! jq -e '[.hosts["github.com"][]? | select(.active)][0].scopes // "" | split(", ") | index("project") != null' >/dev/null <<<"$AUTH"; then
  if $CHECK_ONLY; then
    {
      echo "The gh token does not have the 'project' scope. --check does not change the token; run:"
      echo "  gh auth refresh -h github.com -s project"
    } >&2
    exit 1
  fi
  echo "gh needs the 'project' scope:"
  gh auth refresh -h github.com -s project || exit 1
fi
if $CHECK_ONLY; then
  echo "Mode: --check (verify only)."
else
  echo "Mode: apply (set the target state, then verify)."
fi
if ! WORKFLOWS_BEFORE=$(read_workflows); then
  echo "Could not read the board workflows. Nothing was changed." >&2; exit 1
fi

# ----------------------------------------------------------------------
step "1. Repository settings"
if apply; then
  gh repo edit "$REPO" --enable-wiki=false --enable-squash-merge --enable-merge-commit=false \
    --enable-rebase-merge=false --delete-branch-on-merge >/dev/null
  gh api -X PATCH "repos/$REPO" -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=PR_BODY -F allow_update_branch=true >/dev/null
  echo '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}' \
    | gh api -X PATCH "repos/$REPO" --input - >/dev/null
  gh api -X PUT "repos/$REPO/vulnerability-alerts" --silent
  gh api -X PUT "repos/$REPO/private-vulnerability-reporting" --silent
  jq -n '$ARGS.positional | {names:.}' --args "${TOPICS[@]}" | gh api -X PUT "repos/$REPO/topics" --input - >/dev/null
fi
R=$(gh api "repos/$REPO")
chk() { check_eq "$(jq -r "$1" <<<"$R")" "$2" "$3"; }
chk '.has_wiki' false "Wiki is off"
chk '.allow_squash_merge' true "Merging: squash allowed"
chk '.allow_merge_commit' false "Merging: merge commits off"
chk '.allow_rebase_merge' false "Merging: rebase off"
chk '.squash_merge_commit_title' PR_TITLE "Squash commit title = pull request title"
chk '.delete_branch_on_merge' true "Branch deleted after merging"
chk '.allow_update_branch' true "Pull request branch updates suggested"
chk '.security_and_analysis.secret_scanning.status' enabled "Secret scanning"
chk '.security_and_analysis.secret_scanning_push_protection.status' enabled "Push protection (blocks pushes with secrets)"
if gh api "repos/$REPO/vulnerability-alerts" --silent 2>/dev/null; then ok "Dependabot alerts"; else bad "Dependabot alerts"; fi
if [[ "$(gh api "repos/$REPO/private-vulnerability-reporting" --jq .enabled 2>/dev/null)" == true ]]; then
  ok "Private vulnerability reporting (the link in SECURITY.md works)"
else
  bad "Private vulnerability reporting is off"
fi
WANT_T=$(printf '%s\n' "${TOPICS[@]}" | sort | paste -sd',')
GOT_T=$(gh api "repos/$REPO/topics" --jq '.names | sort | join(",")')
check_eq "$GOT_T" "$WANT_T" "Repository topics (${#TOPICS[@]})"

# ----------------------------------------------------------------------
step "1b. Protection of main (ruleset)"
RS_ID=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name==\"$RULESET_NAME\") | .id" 2>/dev/null | head -1)
if [[ -z "$RS_ID" ]] && apply; then
  CHECKS_JSON=$(printf '%s\n' "${REQUIRED_CHECKS[@]}" | jq -R 'select(length>0) | {context:.}' | jq -s .)
  jq -n --arg n "$RULESET_NAME" --argjson checks "$CHECKS_JSON" '{
    name:$n, target:"branch", enforcement:"active", bypass_actors:[],
    conditions:{ref_name:{include:["~DEFAULT_BRANCH"], exclude:[]}},
    rules:([
      {type:"deletion"}, {type:"non_fast_forward"},
      {type:"required_linear_history"}, {type:"required_signatures"},
      {type:"pull_request", parameters:{
        required_approving_review_count:0, dismiss_stale_reviews_on_push:false,
        require_code_owner_review:false, require_last_push_approval:false,
        required_review_thread_resolution:true, allowed_merge_methods:["squash"]}}
    ] + (if ($checks|length)>0 then [{type:"required_status_checks", parameters:{
        strict_required_status_checks_policy:false, required_status_checks:$checks}}] else [] end))
  }' | gh api -X POST "repos/$REPO/rulesets" --input - >/dev/null && echo "  (ruleset \"$RULESET_NAME\" created)"
  RS_ID=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name==\"$RULESET_NAME\") | .id" | head -1)
fi
if [[ -z "$RS_ID" ]]; then
  bad "Ruleset \"$RULESET_NAME\" does not exist"
else
  RS=$(gh api "repos/$REPO/rulesets/$RS_ID")
  rs() { check_eq "$(jq -r "$1" <<<"$RS")" "$2" "$3"; }
  has() {
    if jq -e --arg t "$1" '.rules[] | select(.type==$t)' >/dev/null <<<"$RS"; then ok "$2"; else bad "$2 (rule missing)"; fi
  }
  rs '.enforcement' active "Ruleset \"$RULESET_NAME\" is active"
  rs '.conditions.ref_name.include | join(",")' "~DEFAULT_BRANCH" "Covers the default branch"
  rs '.bypass_actors | length' 0 "No bypass (the rules also apply to the owner)"
  has deletion "Branch deletion blocked"
  has non_fast_forward "Force push blocked"
  has required_linear_history "Linear history"
  has required_signatures "Signed commits required"
  has pull_request "Changes only through pull requests"
  rs '[.rules[] | select(.type=="pull_request") | .parameters.required_review_thread_resolution][0]' true "Pull request conversations must be resolved"
  rs '[.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods | join(",")][0]' squash "Allowed merge method: squash only"
  WANT_CHECKS=$(printf '%s\n' "${REQUIRED_CHECKS[@]}" | sed '/^$/d' | sort | paste -sd',')
  GOT_CHECKS=$(jq -r '[.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | sort | join(",")' <<<"$RS")
  if [[ "$GOT_CHECKS" == "$WANT_CHECKS" ]]; then
    ok "Required CI checks: ${WANT_CHECKS:-none (there is no CI yet)}"
  else
    bad "Required CI checks: expected ${WANT_CHECKS:-none}, found ${GOT_CHECKS:-none} - fix in Settings > Rules"
  fi
fi

# ----------------------------------------------------------------------
step "2. Labels"
if apply; then
  for l in "bug" "documentation" "duplicate" "enhancement" "good first issue" "help wanted" "invalid" "question" "wontfix"; do
    gh label delete "$l" --repo "$REPO" --yes >/dev/null 2>&1 || true
  done
  for line in "${LABELS[@]}"; do
    IFS='|' read -r n c d <<<"$line"
    gh label create "$n" --repo "$REPO" --color "$c" --description "$d" --force >/dev/null
  done
fi
HAVE=$(gh label list --repo "$REPO" --limit 200 --json name,color,description)
for line in "${LABELS[@]}"; do
  IFS='|' read -r n c d <<<"$line"
  got=$(jq -r --arg n "$n" '.[] | select(.name==$n) | "\(.color|ascii_upcase)|\(.description)"' <<<"$HAVE")
  check_eq "$got" "${c^^}|$d" "$n"
done
WANTED=$(printf '%s\n' "${LABELS[@]}" | cut -d'|' -f1)
EXTRA=$(jq -r '.[].name' <<<"$HAVE" | grep -vxF "$WANTED" | paste -sd',' || true)
if [[ -z "$EXTRA" ]]; then ok "No extra labels"; else bad "Extra labels: $EXTRA"; fi

# ----------------------------------------------------------------------
step "3. Milestones"
MS=$(gh api "repos/$REPO/milestones?state=all&per_page=100")
for line in "${MILESTONES[@]}"; do
  IFS='|' read -r t d <<<"$line"
  if ! jq -r '.[].title' <<<"$MS" | norm | grep -qxF "$(norm <<<"$t")"; then
    apply && gh api "repos/$REPO/milestones" -f title="$t" -f description="$d" --silent
  fi
done
MS=$(gh api "repos/$REPO/milestones?state=all&per_page=100")
for line in "${MILESTONES[@]}"; do
  IFS='|' read -r t d <<<"$line"
  if jq -r '.[].title' <<<"$MS" | norm | grep -qxF "$(norm <<<"$t")"; then ok "$t"; else bad "$t (missing)"; fi
done

# ----------------------------------------------------------------------
step "4. GitHub Projects board"
PLIST=$(gh project list --owner "$OWNER" --limit 100 --format json 2>&1)
if ! jq -e . >/dev/null 2>&1 <<<"$PLIST"; then
  bad "gh project list returned an error: $PLIST"
  abort
fi
PNUM=$(jq -r --arg t "$PROJECT_TITLE" '.projects[] | select(.title==$t) | .number' <<<"$PLIST" | head -1)
if [[ -z "$PNUM" ]]; then
  echo "  Your boards: $(jq -r '[.projects[] | "\"\(.title)\" (no. \(.number))"] | join(", ") | if .=="" then "none" else . end' <<<"$PLIST")"
  SIMILAR=$(jq -r --arg t "$PROJECT_TITLE" '.projects[] | select((.title|ascii_downcase|gsub("\\s";"")) == ($t|ascii_downcase|gsub("\\s";""))) | .title' <<<"$PLIST" | head -1)
  if [[ -n "$SIMILAR" ]]; then
    bad "There is a board \"$SIMILAR\" with a similar name - set PROJECT_TITLE=\"$SIMILAR\" in the script (a second board is not created)"
    abort
  fi
fi
if [[ -z "$PNUM" ]] && apply; then
  PNUM=$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json --jq '.number')
fi
if [[ -z "$PNUM" ]]; then
  bad "Board \"$PROJECT_TITLE\" does not exist"
else
  ok "Board \"$PROJECT_TITLE\" (no. $PNUM)"

  VARS=$(jq -n --arg l "$OWNER" --argjson n "$PNUM" '{login:$l, n:$n}')
  # Every later decision depends on what was read, so a failed read ends the run:
  # an empty answer would look like missing fields, and the script would create them again.
  load() {
    if ! P=$(gql "$Q_PROJECT" "$VARS" | jq -e '.data.user.projectV2 | select(.id != null)' 2>/dev/null); then
      bad "Could not read the board through the API"
      abort
    fi
    PID=$(jq -r .id <<<"$P")
  }
  field() { jq -c --arg n "$1" '.fields.nodes[] | select(.name==$n)' <<<"$P"; }
  load

  # --- single-select fields (Status, Size): created when missing, never overwritten ---
  ensure_options() {  # ensure_options <field> <options...>
    local name="$1"; shift
    local want; want=$(options_json "$@")
    local f; f=$(field "$name")
    if [[ -z "$f" ]]; then
      apply && gql "$Q_NEW_SS" "$(jq -n --arg p "$PID" --arg n "$name" --argjson o "$want" '{p:$p,n:$n,o:$o}')" >/dev/null
    elif [[ "$(jq -c '[.options[].name]' <<<"$f")" != "$(jq -c '[.[].name]' <<<"$want")" ]]; then
      # The API replaces all options and gives them NEW IDs: items lose the value of the field
      # and board workflows that set it are switched off. Editing options in the UI keeps the IDs.
      manual "Field $name has different options than the script - fix them in the UI (the script does not overwrite them, because items would lose their values)"
    fi
  }
  ensure_options "Status" "${STATUS_OPTIONS[@]}"
  ensure_options "Size" "${SIZE_OPTIONS[@]}"

  # --- Sprint as an iteration field (replaces a single-select field left by an older version of the script) ---
  load
  SPRINT=$(field "Sprint")
  if apply && [[ "$(jq -r '.dataType // empty' <<<"$SPRINT")" != "ITERATION" ]]; then
    d1=$(date -d "$SPRINT_START + $SPRINT_DAYS days" +%F); d2=$(date -d "$SPRINT_START + $((2*SPRINT_DAYS)) days" +%F)
    CONF=$(jq -n --arg s "$SPRINT_START" --argjson d "$SPRINT_DAYS" --arg d1 "$d1" --arg d2 "$d2" \
      '{startDate:$s, duration:$d, iterations:[{title:"Sprint 0",startDate:$s,duration:$d},{title:"Sprint 1",startDate:$d1,duration:$d},{title:"Sprint 2",startDate:$d2,duration:$d}]}')
    if gql "$Q_NEW_IT" "$(jq -n --arg p "$PID" --argjson c "$CONF" '{p:$p,n:"Sprint (new)",c:$c}')" >/dev/null 2>&1; then
      load
      [[ -n "$SPRINT" ]] && gql "$Q_DEL_FIELD" "$(jq -n --arg f "$(jq -r .id <<<"$SPRINT")" '{f:$f}')" >/dev/null
      NEWID=$(field "Sprint (new)" | jq -r .id)
      gql "$Q_RENAME" "$(jq -n --arg f "$NEWID" '{f:$f,n:"Sprint"}')" >/dev/null
      echo "  (field Sprint created as an iteration)"
    elif [[ -z "$SPRINT" ]]; then
      echo "  (the API did not accept an iteration - Sprint created as a single-select field)"
      gql "$Q_NEW_SS" "$(jq -n --arg p "$PID" --argjson o "$(options_json "Sprint 0|BLUE|from $SPRINT_START" "Sprint 1|BLUE|from $d1" "Sprint 2|BLUE|from $d2")" '{p:$p,n:"Sprint",o:$o}')" >/dev/null
    fi
  fi

  # --- description, README, visibility, link to the repository, existing issues ---
  if apply; then
    gql "$Q_UPD_PROJ" "$(jq -n --arg p "$PID" --arg d "$PROJECT_DESC" --arg r "$PROJECT_README" --argjson pub "$PROJECT_PUBLIC" '{p:$p,d:$d,r:$r,pub:$pub}')" >/dev/null
    gh project link "$PNUM" --owner "$OWNER" --repo "$REPO" >/dev/null 2>&1 || true
    for u in $(gh issue list --repo "$REPO" --state open --limit 200 --json url --jq '.[].url'); do
      for try in 1 2 3; do
        if out=$(gh project item-add "$PNUM" --owner "$OWNER" --url "$u" 2>&1); then break; fi
        [[ $try -eq 3 ]] && echo "  (could not add $u: $out)"
        sleep 3
      done
    done
    sleep 3   # the API needs a moment before new items appear on the list
  fi

  # --- views: create missing ones, set the filter and visible fields ---
  view_gql() {  # view_gql <description> <query> <variables>; shows the API error instead of hiding it
    local out; out=$(gql "$2" "$3" 2>&1) || { echo "  (API: $1 - $(jq -r '.errors[0].message // empty' <<<"$out" 2>/dev/null || echo "$out"))"; return 1; }
  }
  if apply; then
    for v in "${REQUIRED_VIEWS[@]}"; do
      IFS='|' read -r vn vl vf vc <<<"$v"
      load
      VID=$(jq -r --arg n "$vn" '[.views.nodes[] | select(.name==$n)][0].id // empty' <<<"$P")
      if [[ -z "$VID" ]]; then
        view_gql "new view $vn" "$Q_NEW_VIEW" "$(jq -n --arg p "$PID" --arg n "$vn" --arg l "$vl" '{p:$p,n:$n,l:$l}')" || continue
        load; VID=$(jq -r --arg n "$vn" '[.views.nodes[] | select(.name==$n)][0].id // empty' <<<"$P")
        [[ -z "$VID" ]] && continue
      fi
      [[ "$(jq -r --arg i "$VID" '.views.nodes[] | select(.id==$i) | .filter // ""' <<<"$P")" == "$vf" ]] \
        || view_gql "filter of $vn" "$Q_UPD_VIEW" "$(jq -n --arg v "$VID" --arg f "$vf" '{v:$v,f:$f}')"
      if [[ "$vl" != ROADMAP_LAYOUT && "$(jq -r --arg i "$VID" '[.views.nodes[] | select(.id==$i) | .configuration.visibleFields.nodes[].name] | join(",")' <<<"$P")" != "$vc" ]]; then
        IDS=$(jq -c --arg c "$vc" '.fields.nodes as $f | [$c | split(",")[] as $n | $f[] | select(.name==$n) | .id]' <<<"$P")
        view_gql "fields of $vn" "$Q_UPD_COLS" "$(jq -n --arg v "$VID" --argjson c "$IDS" '{v:$v,c:$c}')"
      fi
    done
  fi

  # --- verify the board ---
  load
  chk_opts() {
    local name="$1"; shift
    local f; f=$(field "$name"); [[ -z "$f" ]] && f='{}'
    local want; want=$(printf '%s\n' "$@" | cut -d'|' -f1 | paste -sd',')
    local got; got=$(jq -r '[.options[]?.name] | join(",")' <<<"$f")
    if [[ "$got" == "$want" ]]; then ok "Field $name: $got"; else bad "Field $name: expected $want, found ${got:-no such field}"; fi
  }
  chk_opts "Status" "${STATUS_OPTIONS[@]}"
  chk_opts "Size" "${SIZE_OPTIONS[@]}"
  ST=$(field "Sprint" | jq -r '.dataType // empty')
  case "$ST" in
    ITERATION)     ok "Field Sprint: iteration ($(field "Sprint" | jq -r '.configuration.duration') days)";;
    SINGLE_SELECT) manual "Field Sprint is a single-select field - the API did not accept an iteration (works, but without @current)";;
    *)             bad "Field Sprint: missing";;
  esac
  check_eq "$(jq -r .public <<<"$P")" "$PROJECT_PUBLIC" "Board is public: $PROJECT_PUBLIC"
  if [[ "$(jq -r .shortDescription <<<"$P")" == "$PROJECT_DESC" ]]; then ok "Board description"; else bad "Board description"; fi
  if [[ "$(jq -r .readme <<<"$P")" == "$PROJECT_README" ]]; then ok "Board README"; else bad "Board README"; fi
  if jq -r '.repositories.nodes[].nameWithOwner' <<<"$P" | grep -qxF "$REPO"; then ok "Linked to $REPO"; else bad "Not linked to $REPO"; fi
  # only open issues count (closed ones stay on the board too, so they must not be added)
  OPEN_URLS=$(gh issue list --repo "$REPO" --state open --limit 200 --json url --jq '.[].url' | sort)
  OPEN=$(sed '/^$/d' <<<"$OPEN_URLS" | wc -l)
  if ITEM_URLS=$(gh project item-list "$PNUM" --owner "$OWNER" --limit 500 --format json --jq '.items[] | select(.content.type=="Issue") | .content.url' 2>/dev/null); then
    INPROJ=$(comm -12 <(sed '/^$/d' <<<"$OPEN_URLS") <(sort <<<"$ITEM_URLS" | sed '/^$/d') | wc -l)
    if [[ "$INPROJ" -eq "$OPEN" ]]; then ok "Open issues on the board ($INPROJ of $OPEN)"; else bad "Open issues on the board: $INPROJ of $OPEN"; fi
  else
    bad "Could not read the board items (gh project item-list)"
  fi

  # --- settings the API cannot change: verified only ---
  URL="https://github.com/users/$OWNER/projects/$PNUM"
  for w in "${REQUIRED_WORKFLOWS[@]}"; do
    st=$(jq -r --arg w "$w" '.workflows.nodes[] | select(.name==$w) | .enabled' <<<"$P")
    if [[ "$st" == "true" ]]; then ok "Workflow \"$w\" is on"
    elif [[ "$st" == "false" ]]; then bad "Workflow \"$w\" is off - turn it on: $URL > ... > Workflows"
    else manual "Workflow \"$w\" - the API shows no such name; visible: $(jq -r '[.workflows.nodes[] | "\(.name)=\(.enabled)"] | join(", ")' <<<"$P")"; fi
  done
  manual "Check by hand: workflow \"Item added to project\" sets Status = Backlog (the API does not show the value)"
  for v in "${REQUIRED_VIEWS[@]}"; do
    IFS='|' read -r vn vl vf vc <<<"$v"
    V=$(jq -c --arg n "$vn" '[.views.nodes[] | select(.name==$n)][0] // empty' <<<"$P")
    if [[ -z "$V" ]]; then bad "View \"$vn\" is missing"; continue; fi
    check_eq "$(jq -r .layout <<<"$V")" "$vl" "View \"$vn\": layout $vl"
    check_eq "$(jq -r '.filter // ""' <<<"$V")" "$vf" "View \"$vn\": filter ${vf:-none}"
    if [[ "$vl" != ROADMAP_LAYOUT ]]; then
      check_eq "$(jq -r '[.configuration.visibleFields.nodes[].name] | join(",")' <<<"$V")" "$vc" "View \"$vn\": fields $vc"
    fi
  done
  grouped_by() { jq -r --arg n "$1" '[.views.nodes[] | select(.name==$n)][0].groupByFields.nodes[0].name // empty' <<<"$P"; }
  if [[ "$(grouped_by Planning)" == "Sprint" ]]; then ok "View \"Planning\": grouped by Sprint"; else manual "View \"Planning\": set grouping by Sprint in the UI (View > Group by)"; fi
  if [[ "$(grouped_by Roadmap)" == "Milestone" ]]; then ok "View \"Roadmap\": grouped by Milestone"; else manual "View \"Roadmap\": set Group by = Milestone in the UI"; fi
  manual "Check by hand: view \"Roadmap\" has Date fields = Sprint (start and end; the API does not show it)"
fi

compare_workflows

# ----------------------------------------------------------------------
step "Summary"
printf '  \e[32m✔ %d passed\e[0m   \e[31m✘ %d to fix\e[0m   \e[33m● %d to check or do by hand\e[0m\n' "$PASS" "$FAIL" "$MANUAL"
[[ $FAIL -eq 0 ]]
