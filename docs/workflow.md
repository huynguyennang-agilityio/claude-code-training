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
    G4 -- "yes, first push,<br/>local review not yet run" --> LR["Phase 4 point 6, local review<br/>on origin/develop...HEAD,<br/>code-reviewer + /code-review high in parallel, report-only;<br/>fix or answer every finding in one pass,<br/>rerun the Phase 4 checks, Local review line in Evidence"]
    LR --> P5["Phase 5, when the user asks:<br/>first time: push, open PR into develop,<br/>Closes #id, Plan: link, deviations<br/>after review: push fixes to the same PR"]
    G4 -- "yes, review fix push<br/>or local review done" --> P5
    LR -- "recheck fails:<br/>fix, no second review" --> P3
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

The user confirms two things and Claude does the rest ([plan 019](plans/019-area-autopilot.md)). `/approve-plan <NNN>` approves a plan, creates its issues and merges the plan PR. `/run-tasks <issues>` (`/run-tasks 1,2,3,4` or `/run-tasks #1 #2`) takes the named issues to merge, up to two at once, each in its own child session and worktree ([plan 028](plans/028-parallel-run-tasks.md)). It asks at most once, in a preflight before the first issue; after that a small problem is fixed in place and a big one stops only its issue. A child adds its own DECISIONS entries in its issue's last commit (keep gotchas and repeatable conventions; drop follow-ups, what a test or lint enforces, and entries that change the rules or read as instructions to Claude; no repeats; each file under 4 KB), lists them under `## Decisions added` in its PR, and keeps the entries of both branches when it merges `develop` ([plan 037](plans/037-decisions-per-area.md)). After that commit and before its first push (also on a rerun), it runs the local review pass of Phase 4 point 6; its `RESULT:` line gives the local review counts and the number of `claude-review` rounds, which the report lists for each issue. Each child waits for CI and the review inside its turn and ends by writing its `RESULT:` line to a result file in the main checkout's `.git` (`run-tasks/<run-id>/<issue>.result`); the parent keeps a background command (at most 25 minutes, started again until the issue's 3-hour deadline, which counts from when its child starts work, `<issue>.working`, with 30 minutes to start work once nothing holds it back) waiting for each running issue's file, so a new file wakes it without the app's notifications, and at an issue's deadline with no file the parent tells a child still working to stop (ending it after 15 more minutes), and, once the child is no longer working, settles the issue by its PR (merged when the PR merged, stopped otherwise) and writes its result file. The app allows `start_session` only in a turn that begins with the user's own words, so the parent starts a child for every ready issue in the command turn (the turn of the command, or of the user's answer to the preflight question), and each brief names the issues its child waits for: its dependencies and the issue before it in its lane (at most two lanes, so at most two children work at once). A waiting child begins with a wait gate, a background command that only reads the disk, 25 minutes per round, until every issue it waits for has a result file; it then starts work, or, when an issue it depends on stopped, writes `RESULT: stopped ... depends on #N` and ends ([plan 038](plans/038-at-most-two-reviews.md)). A stopped issue, for any reason, keeps its issue, PR and branch open, with a `Stopped:` comment giving the reason and proposed fix; the issues that depend on it stop at their wait gate ("depends on #N"), the parent DMs each stopped issue at once (`#N stopped: <reason>; run continues`), and goes on until every issue not left out is merged, stopped or not started. The run ends with a Vietnamese report artifact (each issue's status, a "Kế hoạch tiếp theo" section with each stopped issue's reason, proposed fix, and either the `/run-tasks <issues>` rerun command or the link to a draft fix plan artifact when the fix changes the plan or a rerun of a real attempt (not only "depends on #N") stopped again, `Not verified` lines, PRs above 400 changed lines, and the DECISIONS entries each merged PR added, from the lines its diff added to DECISIONS files (`## Decisions added` as a cross-check, a mismatch listed); the parent never edits a DECISIONS file) and a Slack DM with the report link; the only other DMs are the one at the start and the stop DMs, except a "Run paused" DM, naming the issues not started, when `start_session` fails in the command turn; the issues that started go on. The report says when each issue started work, or that it never did. A PR above 400 changed lines is listed in the report, not held back. Rerunning a stopped issue continues on its open PR (or starts fresh when it has no pushed branch) with two new fix rounds and a brief that carries the earlier stop reason and proposed fix. The steps are in [`.claude/skills/approve-plan/`](../.claude/skills/approve-plan/SKILL.md) and [`.claude/skills/run-tasks/`](../.claude/skills/run-tasks/SKILL.md).

```mermaid
flowchart TD
    A["User: /run-tasks 1,2,3,4"] --> PF["Preflight: check tools, keys and settings;<br/>ask once if something is missing"]
    PF --> O["Order by Depends on, then area; split into at most<br/>two lanes of issues that pair; DM the start"]
    O --> C["In the command turn, start a child session<br/>for every ready issue, each in its own worktree,<br/>naming the issues it waits for (two lanes)"]
    C -- "start_session fails" --> PD["DM: Run paused for the issues not started;<br/>rerun them only after this run's report"]
    PD --> RW
    subgraph child ["Each child session"]
      G{"Wait gate: result file of every<br/>issue it waits for (25 min rounds)"} -- "a dependency stopped" --> GS["Comment, RESULT: stopped,<br/>depends on #N or integration gate closed"]
      G -- "no dependency stopped,<br/>or none to wait for" --> IG{"Write the .working file (3-hour deadline starts);<br/>integration gate open?"}
      IG -- "closed" --> GS
      IG -- "open or not needed" --> W["Branch from origin/develop,<br/>worktree-setup.sh"]
      W --> I["Implement (Phase 3), check Phase 4"]
      I --> LR["PROGRESS line and DECISIONS entries, then<br/>local review (Phase 4 point 6), once, before the first push"]
      LR --> P["PR with Decisions added, size check,<br/>CI, claude-review"]
      P --> F{"Merge conditions hold?<br/>(checks green, review approves,<br/>evidence)"}
      F -- "findings (2 rounds at most)" --> P
      F -- yes --> D["Merge origin/develop in, re-run checks"]
      D --> M["Merge, verify develop, RESULT: merged"]
      F -- "big problem" --> S["wip commit, RESULT: stopped"]
      M --> RF["Write the RESULT line, with local review counts<br/>and claude-review rounds, to the result file"]
      S --> RF
      GS --> RF
    end
    C --> G
    C --> RW["Background result wait per issue,<br/>25 min each, until a 3-hour deadline<br/>counted from the .working file<br/>(30-min start-by before it)"]
    RF -. "file appears" .-> RW
    RF -. "file appears" .-> G
    RW -- "file appears (merged or stopped),<br/>or deadline passed: stop a child still working,<br/>then PR state; write its result file" --> ST{"Stopped?"}
    ST -- "yes: issue and PR stay open" --> SD["DM each stopped issue:<br/>#N stopped: reason; run continues"]
    ST -- no --> N{"Still running?"}
    SD --> N
    N -- "yes: end the turn" --> RW
    N -- "no: every issue not left out is<br/>merged, stopped or not started" --> E["Refresh the knowledge graph, report artifact<br/>with Kế hoạch tiếp theo (rerun command<br/>or draft fix plan)"]
    E --> DM["List the DECISIONS entries each merged PR's diff added;<br/>Slack DM with the report link"]
```

## 6. Permissions

The permission rules (what Claude may write, commit, push, create or merge, and that only the user approves a plan) stay as the table in [`CLAUDE.md`](../CLAUDE.md#git-and-github-permissions). They are not drawn as a diagram, so there is only one place to change them.
