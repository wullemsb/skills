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
shape_check='
  type == "object"
  and ((.skills // []) | type == "array")
  and all(
    (.skills // [])[]?;
    (.path? | type == "string") and (.path | length > 0)
    and (.mtime? | type == "string") and (.mtime | length > 0)
  )
'

if ! jq -e "$shape_check" >/dev/null 2>&1 <<<"$input_json"; then
  echo "Error: stdin must be a JSON object with an optional skills array whose entries include non-empty path and mtime fields" >&2
  exit 1
fi

evaluated_at=$(node -e 'process.stdout.write(new Date().toISOString().replace(/\.\d{3}Z$/, "Z"))')
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
base_file=$(RESULTS_DIR="$results_dir" python - <<'PY'
import os
import tempfile

fd, path = tempfile.mkstemp(prefix=".results-base.", dir=os.environ["RESULTS_DIR"])
os.close(fd)
print(path)
PY
)
trap 'rm -f "$tmp_file" "$base_file"' EXIT

if [[ -f "$RESULTS_JSON" ]]; then
  if ! jq -e "$shape_check" >/dev/null 2>&1 "$RESULTS_JSON"; then
    echo "Error: existing results file must be a JSON object with an optional skills array whose entries include non-empty path and mtime fields" >&2
    exit 1
  fi
  cp "$RESULTS_JSON" "$base_file"
else
  printf '%s\n' '{}' > "$base_file"
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
      reduce $old_skills[] as $skill
        ({};
          .[$skill.path] = $skill
        )
      | reduce $new_skills[] as $skill
          (.;
            .[$skill.path] = (
              reduce ($skill | keys_unsorted[]) as $key
                ((.[$skill.path] // {});
                  .[$key] = $skill[$key]
                )
            )
          )
      | [.[]] | sort_by(.path)
    )
  | if ($new | has("mode")) then .mode = $new.mode else . end
  | if ($new | has("scan_summary")) then .scan_summary = $new.scan_summary else . end
  | if ($new | has("batch_progress")) then .batch_progress = $new.batch_progress else . end
  ' "$base_file" <(printf '%s' "$input_json") > "$tmp_file"

mv "$tmp_file" "$RESULTS_JSON"
