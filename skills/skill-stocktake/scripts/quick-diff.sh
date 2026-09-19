#!/usr/bin/env bash
# quick-diff.sh — compare discovered skills against prior recorded mtimes
# Usage: quick-diff.sh RESULTS_JSON [ROOT_DIR] [USER_PATH ...]
# Output: JSON array of changed/new skill entries to stdout

set -euo pipefail

RESULTS_JSON="${1:-}"
ROOT_DIR="${2:-$PWD}"
shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))
USER_PATHS=("$@")

if [[ -z "$RESULTS_JSON" || ! -f "$RESULTS_JSON" ]]; then
  echo "Error: RESULTS_JSON not found: ${RESULTS_JSON:-<empty>}" >&2
  exit 1
fi

results_shape_check='
  type == "object"
  and ((.skills // []) | type == "array")
  and all(
    (.skills // [])[]?;
    (.path? | type == "string") and (.path | length > 0)
    and (.mtime? | type == "string") and (.mtime | length > 0)
  )
'
if ! jq -e "$results_shape_check" >/dev/null 2>&1 "$RESULTS_JSON"; then
  echo "Error: results file must be a JSON object with an optional skills array whose entries include non-empty path and mtime fields" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scan_json=$("$SCRIPT_DIR/scan.sh" "$ROOT_DIR" "${USER_PATHS[@]}")

jq \
  --slurpfile results "$RESULTS_JSON" \
  '
  ($results[0].skills // []) as $previous
  | [.skills[]
      | . as $skill
      | ($previous | map(select(.path == $skill.path)) | first) as $existing
      | if $existing == null then
          $skill + { is_new: true }
        elif (($existing.mtime // "") != $skill.mtime) then
          $skill + { is_new: false }
        else
          empty
        end
    ]
  ' <<<"$scan_json"
