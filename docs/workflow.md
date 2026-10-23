# Development workflow

These diagrams picture the workflow in [`CLAUDE.md`](../CLAUDE.md#workflow). If a diagram and `CLAUDE.md` disagree, `CLAUDE.md` wins; fix the diagram.

The Mermaid blocks are the source. Exported SVG copies of the key diagrams are in [`diagrams/`](diagrams/).

## 1. Phases and gates

Each change goes through phases 1 to 6 in order, starting from an approved plan file (`docs/plans/`). Only the user can approve a plan; approving it is not authorizing a merge. Diamonds are gates. A gate that needs the user stops the work until they answer. Presentation copy: [`diagrams/phase-flow.svg`](diagrams/phase-flow.svg).

Phase 0 (project foundation: architecture, stack, layout, Claude rules, tooling) is not a step of each change. It is done once and revisited only when the foundation itself changes, through its own issue.

```mermaid
flowchart TD
    START(["New change"]) --> TRIV{"Trivial?<br/>(typo, one-line fix)"}
    TRIV -- yes --> P3
    TRIV -- no --> P1["Phase 1: Classify the ticket"]
    P1 --> G1{"Required evidence<br/>present?"}
    G1 -- no --> ASK1["Ask the user for it"] --> G1
    G1 -- yes --> PLAN["Write docs/plans/NNN-name.md<br/>Status: draft<br/>(open questions, approach, risks,<br/>verification, issues to create)"]
    PLAN --> PMR["Push docs/plan-NNN-name,<br/>open the plan PR"]
    PMR --> APPR{"User sets<br/>Status: approved<br/>and merges the plan PR?"}
    APPR -- "no / edits needed" --> PLAN
    APPR -- yes --> ISSUE["Create the issues exactly as the plan lists them<br/>(Plan: link in each),<br/>branch type/id-name from develop"]
    ISSUE --> P2["Phase 2: Impact analysis,<br/>contract in docs/api"]
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

A mobile feature that calls an endpoint is split into a `(mobile, mock)` and a `(mobile, integration)` issue (see "Mobile tasks: mock and integration" in [`docs/workflow/plan.md`](workflow/plan.md#mobile-tasks-mock-and-integration)). The mock task starts as soon as the contract is on `develop`, in parallel with the backend. The integration gate opens only when the backend issues are closed and their endpoints are in `docs/api/openapi.json` on `develop`.

```mermaid
flowchart LR
    C["Contract on develop<br/>docs/api/module.md<br/>+ examples"] --> BE["Backend issue<br/>endpoints + openapi.json"]
    C --> MOCK["(mobile, mock)<br/>Fake…RemoteDataSource<br/>fixtures = examples<br/>API_MODE=mock"]
    BE --> GATE{"Integration gate:<br/>backend issues closed,<br/>endpoints in openapi.json<br/>on develop?"}
    MOCK --> GATE
    GATE -- no --> WAIT["Stop, tell the user<br/>which backend issue is open"]
    GATE -- yes --> INT["(mobile, integration)<br/>app against the local backend"]
```

## 5. Permissions

The permission rules (what Claude may write, commit, push, create or merge, and that only the user approves a plan) stay as the table in [`CLAUDE.md`](../CLAUDE.md#git-and-github-permissions). They are not drawn as a diagram, so there is only one place to change them.
