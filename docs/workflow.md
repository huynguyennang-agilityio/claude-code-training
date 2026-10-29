# Development workflow

These diagrams picture the workflow in [`CLAUDE.md`](../CLAUDE.md#workflow). If a diagram and `CLAUDE.md` disagree, `CLAUDE.md` wins; fix the diagram.

The Mermaid blocks are the source. Exported SVG copies of the key diagrams are in [`diagrams/`](diagrams/).

## 1. Phases and gates

Each change goes through phases 1 to 6 in order, starting from an approved plan file (`docs/plans/`). A draft plan is a Vietnamese artifact; the plan file, its branch and its PR are made by `/approve-plan` after approval ([plan 023](plans/023-task-breakdown-skill.md)). Where the Artifact tool is missing, the draft is a file on its own plan PR, as before. Only the user can approve a plan, in chat (`/approve-plan`) or, for such a plan PR, on GitHub. Approving a plan lets `/approve-plan` merge that plan PR, never a PR for an issue. Diamonds are gates. A gate that needs the user stops the work until they answer. Presentation copy: [`diagrams/phase-flow.svg`](diagrams/phase-flow.svg) (out of date since `/approve-plan`, issue #90: it shows only approval on GitHub; the Mermaid block below is current).

Phase 0 (project foundation: architecture, stack, layout, Claude rules, tooling) is not a step of each change. It is done once and revisited only when the foundation itself changes, through its own issue.

```mermaid
flowchart TD
    START(["New change"]) --> TRIV{"Trivial?<br/>(typo, one-line fix)"}
    TRIV -- yes --> P3
    TRIV -- no --> P1["Phase 1: Classify the ticket"]
    P1 --> G1{"Required evidence<br/>present?"}
    G1 -- no --> ASK1["Ask the user for it"] --> G1
    G1 -- yes --> PLAN["Draft the plan as a Vietnamese artifact<br/>(plan-artifact skill), Status: draft<br/>(open questions, approach, risks, verification,<br/>task breakdown, issues to create)<br/>no file, branch, PR or issue yet"]
    PLAN --> APPR{"User approves the plan?<br/>in chat: /approve-plan NNN<br/>(old-flow plan PR: also on GitHub)"}
    G1 -. "old flow: no Artifact tool,<br/>or a plan already open as a PR" .-> OLD["Write docs/plans/NNN-name.md<br/>Status: draft, push docs/plan-NNN-name,<br/>open the plan PR"]
    OLD -.-> APPR
    APPR -- "no / edits needed" --> PLAN
    APPR -- "in chat" --> AP["/approve-plan: write docs/plans/NNN-name.md in English<br/>(Status: approved, the user's words, Draft: link),<br/>push docs/plan-NNN-name, open the plan PR,<br/>create the issues as listed, merge the plan PR"]
    APPR -- "on GitHub<br/>(old-flow plan PR only)" --> ISSUE["Create the issues exactly as the plan lists them<br/>(Plan: link in each), numbers in a docs PR"]
    AP --> BR["Branch type/id-name from develop"]
    ISSUE --> BR
    BR --> P2["Phase 2: Impact analysis,<br/>contract in docs/api"]
    P2 --> G2{"Needs something the<br/>approved plan does not cover<br/>(endpoint, schema, dependency, scope)?"}
    G2 -- yes --> PLAN
    G2 -- no --> P3
    P3["Phase 3: Small steps<br/>code → tests → lint → type check<br/>+ verify by ticket type<br/>Stop hook reruns the checks"] --> G4
    G4{"Phase 4 gate:<br/>criteria met, full suite passes,<br/>security ok, diff in scope,<br/>evidence drafted<br/>(contract, a11y, auth rows)?"}
    G4 -- no --> P3
    G4 -- yes --> P5["Phase 5, when the user asks:<br/>first time: push, open PR into develop,<br/>Closes #id, Plan: link, deviations<br/>after review: push fixes to the same PR"]
    P5 --> REV["On GitHub: CI (backend, mobile) on every push;<br/>claude-review when the PR opens<br/>and again on @claude review"]
    REV --> UREV{"User review:<br/>changes needed?"}
    UREV -- yes --> P3
    UREV -- no --> MERGE{"User authorizes<br/>the merge of this PR?"}
    MERGE -- not yet --> UREV
    MERGE -- yes --> P6["Phase 6: Merge, verify develop,<br/>close the issue"]
```

## 2. Branching

`develop` collects finished work through pull requests. `main` only receives merges from `develop` for a release. Nobody pushes directly to either. GitLab is a read-only copy that the user updates by hand after a merge (see [GitLab mirror](../README.md#gitlab-mirror)).

```mermaid
gitGraph
    commit id: "init"
    branch develop
    checkout develop
    commit id: "setup"
    branch feat/12-challenge-list
    checkout feat/12-challenge-list
    commit id: "feat: list endpoint"
    commit id: "test: list endpoint"
    checkout develop
    merge feat/12-challenge-list id: "PR #12"
    branch fix/14-step-sync
    checkout fix/14-step-sync
    commit id: "fix: dedupe samples"
    checkout develop
    merge fix/14-step-sync id: "PR #14"
    checkout main
    merge develop id: "release"
```

## 3. Pull request and review

```mermaid
sequenceDiagram
    actor U as User
    participant C as Claude
    participant G as GitHub
    participant A as GitHub Actions
    U->>C: Push and open the PR
    C->>G: git push, open PR into develop (template, Closes #id)
    G->>A: PR opened
    A->>G: CI: backend, mobile
    A->>G: claude-review: code-reviewer findings by step (correctness, tests, readability, security, scope) in one PR comment
    C-->>U: PR link
    U->>G: review the PR
    loop until the user is satisfied
        U->>C: address comments
        C->>C: repeat Phase 3 and Phase 4
        U->>C: commit and push
        C->>G: push fixes to the same PR
        G->>A: CI runs again (a new review only on "@claude review")
    end
    U->>C: Merge PR #id
    C->>G: merge into develop
    C->>G: check PR merged, diff on develop
    C->>C: rerun local checks on develop
    A->>G: CI on the merge commit
    C-->>U: CI result on develop
    C->>G: close the issue if Closes #id did not
    C-->>U: reminder to mirror develop to GitLab
    U->>U: on the VPN: push develop and main to the gitlab remote
```

## 4. Mobile tasks: mock and integration

A mobile feature that calls an endpoint is split into a `(mobile, mock)` and a `(mobile, integration)` issue (see "Mobile tasks: mock and integration" in [`.claude/workflow/plan.md`](../.claude/workflow/plan.md#mobile-tasks-mock-and-integration)). The mock task starts as soon as the contract is on `develop`, in parallel with the backend. The integration gate opens only when the backend issues are closed and their endpoints are in `docs/api/openapi.json` on `develop`.

```mermaid
flowchart LR
    C["Contract on develop<br/>docs/api/module.md<br/>+ examples"] --> BE["Backend issue<br/>endpoints + openapi.json"]
    C --> MOCK["(mobile, mock)<br/>Fake…RemoteDataSource<br/>fixtures = examples<br/>API_MODE=mock"]
    BE --> GATE{"Integration gate:<br/>backend issues closed,<br/>endpoints in openapi.json<br/>on develop?"}
    MOCK --> GATE
    GATE -- no --> WAIT["Stop, tell the user<br/>which backend issue is open"]
    GATE -- yes --> INT["(mobile, integration)<br/>app against the local backend"]
```

## 5. Two confirmations: `/approve-plan` and `/run-tasks`

The user confirms two things and Claude does the rest ([plan 019](plans/019-area-autopilot.md)). `/approve-plan <NNN>` approves a plan, creates its issues and merges the plan PR. `/run-tasks <issues>` (`/run-tasks 1,2,3,4` or `/run-tasks #1 #2`) takes the named issues to merge, up to two at once, each in its own child session and worktree ([plan 028](plans/028-parallel-run-tasks.md)). It asks at most once, in a preflight before the first issue; after that a small problem is fixed in place and a big one stops only its issue. Each child waits for CI and the review inside its turn and ends by writing its `RESULT:` line to a result file in the main checkout's `.git` (`run-tasks/<run-id>/<issue>.result`); the parent keeps a background command (at most 25 minutes, started again until the issue's 3-hour deadline) waiting for each running issue's file, so a new file wakes it without the app's notifications, and an issue with no file by its deadline (extended once by an hour while its child still works) counts as stopped, or as merged when its PR merged. The run ends with a Vietnamese report artifact (each issue's status, the big problems with a proposed fix, `Not verified` lines, PRs above 400 changed lines, proposed decisions) and a Slack DM with its link; the only other DM is the one at the start, except a "Run paused" DM when the parent cannot start or read child sessions while issues are still ready. A PR above 400 changed lines is listed in the report, not held back. The steps are in [`.claude/skills/approve-plan/`](../.claude/skills/approve-plan/SKILL.md) and [`.claude/skills/run-tasks/`](../.claude/skills/run-tasks/SKILL.md).

```mermaid
flowchart TD
    A["User: /run-tasks 1,2,3,4"] --> PF["Preflight: check tools, keys and settings;<br/>ask once if something is missing"]
    PF --> O["Order by Depends on, then area; pair issues<br/>with no dependency and no shared files; DM the start"]
    O --> C["Start up to two child sessions,<br/>each in its own worktree"]
    subgraph child ["Each child session"]
      W["Branch from origin/develop,<br/>then worktree-setup.sh"] --> I["Implement (Phase 3), check Phase 4,<br/>PROGRESS line"]
      I --> P["PR, size check, CI, claude-review"]
      P --> F{"Merge conditions hold?<br/>(checks green, review approves,<br/>evidence)"}
      F -- "findings (2 rounds at most)" --> P
      F -- yes --> D["Merge origin/develop in, re-run checks"]
      D --> M["Merge, verify develop, RESULT: merged"]
      F -- "big problem" --> S["wip commit, RESULT: stopped"]
      M --> RF["Write the RESULT line<br/>to the result file"]
      S --> RF
    end
    C --> W
    C --> RW["Background result wait per issue,<br/>25 min each, until a 3-hour deadline"]
    RF -. "file appears" .-> RW
    RW -- "file appears (merged or stopped),<br/>or deadline passed (stopped)" --> N{"More ready issues?"}
    N -- yes --> C
    N -- no --> E["Refresh the knowledge graph, report artifact,<br/>Slack DM with its link"]
```

## 6. Permissions

The permission rules (what Claude may write, commit, push, create or merge, and that only the user approves a plan) stay as the table in [`CLAUDE.md`](../CLAUDE.md#git-and-github-permissions). They are not drawn as a diagram, so there is only one place to change them.
