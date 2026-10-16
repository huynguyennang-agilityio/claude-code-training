# Development workflow

These diagrams picture the workflow in [`CLAUDE.md`](../CLAUDE.md#workflow). If a diagram and `CLAUDE.md` disagree, `CLAUDE.md` wins; fix the diagram.

The Mermaid blocks are the source. Exported SVG copies of the key diagrams are in [`diagrams/`](diagrams/).

## 1. Phases and gates

Each change goes through phases 1 to 6 in order. Diamonds are gates. A gate that needs the user stops the work until they answer. Presentation copy: [`diagrams/phase-flow.svg`](diagrams/phase-flow.svg).

Phase 0 (project foundation: architecture, stack, layout, Claude rules, tooling) is not a step of each change. It is done once and revisited only when the foundation itself changes, through its own issue.

```mermaid
flowchart TD
    START(["New change"]) --> P1["Phase 1: Classify the ticket"]
    P1 --> G1{"Required evidence<br/>present?"}
    G1 -- no --> ASK1["Ask the user for it"] --> G1
    G1 -- yes --> P1B["List open questions,<br/>write acceptance criteria"]
    P1B --> ISSUE{"Existing issue picked,<br/>or new issue text<br/>confirmed by the user?"}
    ISSUE -- no --> P1B
    ISSUE -- yes --> BR["Create the issue if new,<br/>branch type/id-name from develop"]
    BR --> P2["Phase 2: Impact analysis,<br/>contract in docs/api, plan"]
    P2 --> G2{"Public API or breaking contract,<br/>schema or data-loss migration,<br/>security boundary, architecture or core tech,<br/>real data, production or cost?"}
    G2 -- yes --> APPR{"User approves?"}
    APPR -- no --> P2
    APPR -- yes --> P3
    G2 -- no --> P3
    P3["Phase 3: Small steps<br/>code → tests → lint → type check<br/>+ verify by ticket type"] --> G4
    G4{"Phase 4 gate:<br/>criteria met, full suite passes,<br/>security ok, diff in scope,<br/>evidence drafted?"}
    G4 -- no --> P3
    G4 -- yes --> P5["Phase 5, when the user asks:<br/>first time: push, open MR into develop, Closes #id<br/>after review: push fixes to the same MR"]
    P5 --> REV["code-reviewer runs automatically<br/>when the MR is opened"]
    REV --> UREV{"User review:<br/>changes needed?"}
    UREV -- yes --> P3
    UREV -- no --> MERGE{"User authorizes<br/>the merge?"}
    MERGE -- not yet --> UREV
    MERGE -- yes --> P6["Phase 6: Merge, verify develop,<br/>close the issue"]
```

## 2. Branching

`develop` collects finished work through merge requests. `main` only receives merges from `develop` for a release. Nobody pushes directly to either.

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
    merge feat/12-challenge-list id: "MR !12"
    branch fix/14-step-sync
    checkout fix/14-step-sync
    commit id: "fix: dedupe samples"
    checkout develop
    merge fix/14-step-sync id: "MR !14"
    checkout main
    merge develop id: "release"
```

## 3. Merge request and review

```mermaid
sequenceDiagram
    actor U as User
    participant C as Claude
    participant R as code-reviewer agent
    participant G as GitLab
    U->>C: Push and open the MR
    C->>G: git push, open MR into develop (template, Closes #id)
    C->>R: review the MR (runs automatically)
    R-->>C: findings by step: correctness, tests, readability, security, scope
    C-->>U: MR link + review findings
    U->>G: review the MR
    loop until the user is satisfied
        U->>C: address comments
        C->>C: repeat Phase 3 and Phase 4
        U->>C: commit and push
        C->>G: push fixes to the same MR
    end
    U->>C: Merge MR !id
    C->>G: merge into develop
    C->>G: check MR merged, diff on develop
    C->>C: rerun local checks on develop
    C-->>U: result ("no pipeline" while CI is off)
    C->>G: close the issue if Closes #id did not
```

## 4. Permissions

The permission rules (what Claude may commit, push, create or merge) stay as the table in [`CLAUDE.md`](../CLAUDE.md#git-and-gitlab-permissions). They are not drawn as a diagram, so there is only one place to change them.
