# skills

This repository is a GitHub Copilot Agent Plugins 1.0 plugin.

## Installation

1. Clone this repository locally.
2. From the repository root, install the plugin:

   ```bash
   copilot plugin install .
   ```

3. Verify that the plugin was loaded:

   ```bash
   copilot plugin list
   ```

4. Start a new Copilot session and confirm the included skill is available:

   ```text
   /skills list
   ```

If you update the plugin locally, run `copilot plugin install .` again from the repository root to refresh the cached installation.

## Included skill

- `skill-stocktake`: scans available skills in the current repository, common plugin layouts, or user-provided paths, and reviews them against a quality checklist. It is adapted for Copilot from the original [`skill-stocktake` skill](https://github.com/affaan-m/ECC/blob/main/skills/skill-stocktake/SKILL.md).
