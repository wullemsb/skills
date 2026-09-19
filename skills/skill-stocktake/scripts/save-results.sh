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
results_dir=$(dirname "$RESULTS_JSON")
mkdir -p "$results_dir"
tmp_file=$(RESULTS_DIR="$results_dir" python - <<'PY'
import os
import tempfile

fd, path = tempfile.mkstemp(prefix=".results.json.", dir=os.environ["RESULTS_DIR"])
os.close(fd)
print(path)
PY
)
trap 'rm -f "$tmp_file"' EXIT

if [[ ! -f "$RESULTS_JSON" ]]; then
  jq --arg evaluated_at "$evaluated_at" \
    '
    .evaluated_at = $evaluated_at
    | .skills = (.skills // [])
    ' <<<"$input_json" > "$tmp_file"
  mv "$tmp_file" "$RESULTS_JSON"
  exit 0
fi

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
      reduce ($old_skills + $new_skills)[] as $skill
        ([];
          (map(.path) | index($skill.path)) as $index
          | if $index == null then
              . + [$skill]
            else
              .[$index] = $skill
            end
        )
    )
  | if ($new | has("mode")) then .mode = $new.mode else . end
  | if ($new | has("scan_summary")) then .scan_summary = $new.scan_summary else . end
  | if ($new | has("batch_progress")) then .batch_progress = $new.batch_progress else . end
  ' "$RESULTS_JSON" <(printf '%s' "$input_json") > "$tmp_file"

mv "$tmp_file" "$RESULTS_JSON"
