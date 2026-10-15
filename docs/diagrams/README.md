# Diagrams

Presentation copies of the key diagrams in [`architecture.md`](../architecture.md) and [`workflow.md`](../workflow.md), redrawn with the diagram-design skill in its default editorial style.

| Diagram | Content source | Image |
| --- | --- | --- |
| System context | [architecture.md § 1](../architecture.md#1-system-context) | [`system-context.svg`](system-context.svg) |
| Flutter feature layers | [architecture.md § 2](../architecture.md#layers-and-dependency-direction) | [`flutter-layers.svg`](flutter-layers.svg) |
| Backend modules | [architecture.md § 3](../architecture.md#modules-and-layers) | [`backend-modules.svg`](backend-modules.svg) |
| Request flow and errors | [architecture.md § 3](../architecture.md#request-flow-and-errors) | [`request-flow.svg`](request-flow.svg) |
| Run sync to medal | [architecture.md § 3](../architecture.md#run-sync-and-medal-award) | [`run-to-medal.svg`](run-to-medal.svg) |
| Phases and gates | [workflow.md § 1](../workflow.md#1-phases-and-gates) | [`phase-flow.svg`](phase-flow.svg) |

## How the files relate

- **The Mermaid blocks in the Markdown files are the source of truth for content.** Change those first.
- **Each `<name>.html` is the editorial redraw** of one Mermaid block, and the source of the matching `.svg`. It is a simplified view, not a copy:
  - the sequence diagrams merge a few participants to stay within five lifelines;
  - `phase-flow` folds the issue confirmation into the "Ready?" gate.
- **Each `<name>.svg`** is exported from its HTML with the skill's `scripts/export_svg.py`. Don't edit the SVG by hand.

When a Mermaid block changes in a way that affects one of these diagrams:
1. Update its HTML.
2. Re-export the SVG with `/diagram-design:export-diagram docs/diagrams/<name>.html`.
3. Commit both files together.

PNG copies are not committed yet. The export needs Playwright, which isn't installed in this environment.
