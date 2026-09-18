---
name: skill-stocktake
description: Use when auditing GitHub Copilot skills for quality. Scans available skills in the current repository or plugin layout and evaluates them against a quality checklist.
---

# skill-stocktake

Audit the available GitHub Copilot skills and produce a decision-ready stocktake.

## Scope

Scan skill definitions from the current working tree and explicitly report which of these locations were found:

| Path | Description |
|------|-------------|
| `skills/*/SKILL.md` | Skills in the current plugin root |
| `plugins/*/skills/*/SKILL.md` | Skills in multi-plugin repositories |
| `.github/copilot/skills/*/SKILL.md` | Repository-local Copilot skills |
| User-provided paths | Additional skill locations supplied by the user |

If none of the default locations exist, say so clearly and stop.

## Workflow

### Phase 1 — Inventory

1. Discover all `SKILL.md` files in the supported locations.
2. Report the scan summary first, including which paths were found and how many skill files were discovered in each location.
3. Build an inventory table:

| Skill | Path | Usage signals | Description |
|-------|------|---------------|-------------|

For **usage signals**, use repository evidence such as references in documentation, examples, tests, settings, or user-provided context. If no reliable signal exists, say `Unknown` rather than guessing.

### Phase 2 — Quality Evaluation

Read each discovered skill and evaluate it holistically against this checklist:

- [ ] Content overlap with other skills checked
- [ ] Overlap with repository guidance checked (`README.md`, `.github/copilot/`, `AGENTS.md`, `CLAUDE.md`, `MEMORY.md`, or equivalent files if present)
- [ ] Freshness of technical references verified (use WebSearch if tool names, CLI flags, APIs, or versions are present)
- [ ] Usage frequency or other usage signals considered

Use these verdicts:

| Verdict | Meaning |
|---------|---------|
| Keep | Useful and current |
| Improve | Worth keeping, but specific improvements needed |
| Update | Referenced technology is outdated |
| Retire | Low quality, stale, misleading, or cost-asymmetric |
| Merge into [X] | Substantial overlap with another skill; name the merge target |

Evaluation is holistic, not a numeric rubric. Use these guiding dimensions:

- **Actionability**: the skill gives concrete steps, commands, or outputs
- **Scope fit**: the name, trigger, and content align and are not misleading
- **Uniqueness**: the value is not already covered by another skill or repository guidance
- **Currency**: technical references still work in the current environment

### Reason quality requirements

The `reason` for every verdict must be self-contained and decision-enabling:

- Do not write `unchanged` alone — restate the evidence
- For **Retire**, state the defect and what already covers the need
- For **Merge**, name the target and what content should move
- For **Improve**, name the specific section or change needed
- For **Keep**, explain why the skill remains useful, current, and distinct

### Phase 3 — Summary Table

Return a summary table:

| Skill | Usage signals | Verdict | Reason |
|-------|---------------|---------|--------|

### Phase 4 — Consolidation

1. For **Retire** and **Merge**, explain:
   - the specific issue found
   - what existing skill or guidance covers the same need
   - any likely impact of removal or consolidation
2. For **Improve**, propose concrete edits.
3. For **Update**, identify what should be refreshed and cite the verified source when WebSearch was used.

## Important rules

- Do not delete, merge, or rewrite skill files automatically unless the user explicitly asks for implementation changes.
- If a skill references external tools or documentation that may have changed, verify them instead of assuming they are current.
- If there is only one skill, still evaluate it against overlap with repository guidance and against whether its scope is appropriately narrow and actionable.
