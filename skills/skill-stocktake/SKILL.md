---
name: skill-stocktake
description: Use when auditing GitHub Copilot skills for quality. Scans available skills in the current repository or plugin layout and evaluates them against a quality checklist.
---

# skill-stocktake

Audit the available GitHub Copilot skills and produce a decision-ready stocktake. Use the bundled helper scripts in `skills/skill-stocktake/scripts/` to inventory skills, detect changes, and save refreshed results.

## Scope

Scan skill definitions from the current working tree and explicitly report which of these locations were found:

| Path | Description |
|------|-------------|
| `skills/*/SKILL.md` | Skills in the current plugin root |
| `plugins/*/skills/*/SKILL.md` | Skills in multi-plugin repositories |
| `.github/copilot/skills/*/SKILL.md` | Repository-local Copilot skills |
| User-provided paths | Additional skill locations supplied by the user |

If none of the default locations exist, continue with any user-provided paths. Stop only when no skill files are found in either the default locations or the user-provided paths.

## Workflow

### Helper scripts

When this skill is available from the plugin source tree, the helper scripts live at:

- `skills/skill-stocktake/scripts/scan.sh`
- `skills/skill-stocktake/scripts/quick-diff.sh`
- `skills/skill-stocktake/scripts/save-results.sh`

Use `/tmp/skill-stocktake-results.json` as the default cache file unless the user gives you a different results path. Treat that chosen path as `RESULTS_JSON` in the commands below.

### Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| Quick Scan | A prior results file exists | Re-evaluate only new or changed skills |
| Full Stocktake | No results file exists, or the user asks for a full pass | Rebuild the complete inventory and review all discovered skills |

### Phase 1 — Inventory

#### Quick Scan

1. If `RESULTS_JSON` exists, run:

   ```bash
   bash skills/skill-stocktake/scripts/quick-diff.sh "$RESULTS_JSON" "$PWD"
   ```

2. If the output is `[]`, report that no discovered skills changed since the previous run and stop unless the user asked for a full stocktake.
3. If the output is not empty, re-evaluate only the returned skills and carry forward unchanged results from the existing results file.

#### Full Stocktake

1. Discover all `SKILL.md` files in the supported locations by running:

   ```bash
   bash skills/skill-stocktake/scripts/scan.sh "$PWD"
   ```

   Pass any user-provided paths as additional arguments to the script.
2. Report the scan summary first, including which paths were found and how many skill files were discovered in each location.
3. Build an inventory table:

| Skill | Path | Usage signals | Description |
|-------|------|---------------|-------------|

For **usage signals**, use repository evidence such as references in documentation, examples, tests, settings, or user-provided context. If no reliable signal exists, say `Unknown` rather than guessing.

After completing either mode, save the refreshed results with:

```bash
bash skills/skill-stocktake/scripts/save-results.sh "$RESULTS_JSON" <<< "$EVAL_RESULTS"
```

`EVAL_RESULTS` must be a JSON object whose `.skills` array contains the newly evaluated or updated skill entries for this run. Every `.skills[]` entry must include a unique, non-empty `path`. `save-results.sh` merges those entries into the existing results file by `path`, preserving previously saved fields for the same skill when the new entry omits them, so unchanged skills do not need to be repeated during a quick scan. Include refreshed top-level metadata such as `mode`, `scan_summary`, or `batch_progress` whenever those values changed, because the script only updates those fields when they are present in the new payload.

### Phase 2 — Quality Evaluation

Read each discovered skill and evaluate it holistically against this checklist:

- [ ] Content overlap with other skills checked
- [ ] Overlap with repository guidance checked (`README.md`, `.github/copilot/`, `AGENTS.md`, `CLAUDE.md`, `MEMORY.md`, or equivalent files if present)
- [ ] Freshness of technical references verified using available repository context and any web lookup capability available in the current client
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
3. For **Update**, identify what should be refreshed and cite the verified source when external documentation was consulted.

## Important rules

- Do not delete, merge, or rewrite skill files automatically unless the user explicitly asks for implementation changes.
- If a skill references external tools or documentation that may have changed, verify them with the tools available in the current client instead of assuming they are current.
- If there is only one skill, still evaluate it against overlap with repository guidance and against whether its scope is appropriately narrow and actionable.

## Results file shape

The saved results file should follow this structure:

```json
{
  "evaluated_at": "2026-09-19T15:00:00Z",
  "mode": "full",
  "scan_summary": {},
  "skills": [
    {
      "path": "/absolute/path/to/skills/example/SKILL.md",
      "name": "example",
      "description": "Example skill",
      "mtime": "2026-09-19T14:55:00Z",
      "verdict": "Keep",
      "reason": "Distinct, current, and actionable."
    }
  ]
}
```
