#!/usr/bin/env bash
# quick-diff.sh — compare skill mtimes against results.json evaluated_at
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

evaluated_at=$(jq -r '.evaluated_at // empty' "$RESULTS_JSON")
if [[ ! "$evaluated_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  echo "Error: invalid or missing evaluated_at in $RESULTS_JSON: ${evaluated_at:-<empty>}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scan_json=$(bash "$SCRIPT_DIR/scan.sh" "$ROOT_DIR" "${USER_PATHS[@]}")

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
