#!/usr/bin/env bash
# save-results.sh — merge evaluated skills into results.json with current UTC timestamp
# Usage: save-results.sh RESULTS_JSON <<< "$EVAL_JSON"

set -euo pipefail

RESULTS_JSON="${1:-}"

if [[ -z "$RESULTS_JSON" ]]; then
  echo "Error: RESULTS_JSON argument required" >&2
  echo "Usage: save-results.sh RESULTS_JSON <<< \"\$EVAL_JSON\"" >&2
  exit 1
fi

input_json=$(cat)
if ! jq empty >/dev/null 2>&1 <<<"$input_json"; then
  echo "Error: stdin is not valid JSON" >&2
  exit 1
fi

evaluated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ ! -f "$RESULTS_JSON" ]]; then
  jq --arg evaluated_at "$evaluated_at" \
    '
    .evaluated_at = $evaluated_at
    | .skills = (.skills // [])
    ' <<<"$input_json" > "$RESULTS_JSON"
  exit 0
fi

tmp_file=$(mktemp "${RESULTS_JSON}.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

jq -s \
  --arg evaluated_at "$evaluated_at" \
  '
  .[0] as $existing
  | .[1] as $new
  | ($existing.skills // []) as $old_skills
  | ($new.skills // []) as $new_skills
  | $existing
  | .evaluated_at = $evaluated_at
  | .skills = (
      ($old_skills + $new_skills)
      | reverse
      | unique_by(.path)
      | reverse
    )
  | if ($new | has("mode")) then .mode = $new.mode else . end
  | if ($new | has("scan_summary")) then .scan_summary = $new.scan_summary else . end
  | if ($new | has("batch_progress")) then .batch_progress = $new.batch_progress else . end
  ' "$RESULTS_JSON" <(printf '%s' "$input_json") > "$tmp_file"

mv "$tmp_file" "$RESULTS_JSON"
