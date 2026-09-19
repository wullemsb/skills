#!/usr/bin/env bash
# scan.sh — enumerate Copilot skill files in the current working tree
# Usage: scan.sh [ROOT_DIR] [USER_PATH ...]
# Output: JSON to stdout

set -euo pipefail

ROOT_DIR="${1:-$PWD}"
if [[ $# -gt 0 ]]; then
  shift
fi
USER_PATHS=("$@")

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Error: ROOT_DIR not found: $ROOT_DIR" >&2
  exit 1
fi

sort_nul_file() {
  local input_file="$1"
  local sorted_file="${input_file}.sorted"
  node -e '
    const fs = require("fs");
    const input = fs.readFileSync(0);
    const records = [];
    let start = 0;
    for (let index = 0; index < input.length; index += 1) {
      if (input[index] === 0) {
        records.push(input.subarray(start, index + 1));
        start = index + 1;
      }
    }
    if (start < input.length) records.push(input.subarray(start));
    records.sort(Buffer.compare);
    process.stdout.write(Buffer.concat(records));
  ' <"$input_file" >"$sorted_file"
  mv "$sorted_file" "$input_file"
}

extract_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    BEGIN { fm=0 }
    /^---$/ { fm++; next }
    fm==1 {
      n = length(f) + 2
      if (substr($0, 1, n) == f ": ") {
        val = substr($0, n+1)
        gsub(/^"/, "", val)
        gsub(/"$/, "", val)
        print val
        exit
      }
    }
    fm>=2 { exit }
  ' "$file"
}

file_mtime_utc() {
  local file="$1"
  local epoch
  epoch=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
  date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ
}

add_skill_records() {
  local find_file="$1" source="$2"
  while IFS= read -r -d '' file; do
    if [[ -n "${SEEN_PATHS[$file]:-}" ]]; then
      continue
    fi
    SEEN_PATHS["$file"]=1

    local name desc mtime
    name=$(extract_field "$file" "name")
    desc=$(extract_field "$file" "description")
    mtime=$(file_mtime_utc "$file")

    jq -n \
      --arg path "$file" \
      --arg name "$name" \
      --arg description "$desc" \
      --arg mtime "$mtime" \
      --arg source "$source" \
      '{path:$path,name:$name,description:$description,mtime:$mtime,source:$source}' \
      > "$TMP_DIR/skill-$SKILL_INDEX.json"
    SKILL_INDEX=$((SKILL_INDEX + 1))
  done < "$find_file"
}

scan_pattern() {
  local base_dir="$1" min_depth="$2" max_depth="$3" find_file="$4" find_err="$5"
  : >"$find_file"
  : >"$find_err"

  if [[ ! -d "$base_dir" ]]; then
    return 0
  fi

  if ! find -L "$base_dir" -mindepth "$min_depth" -maxdepth "$max_depth" -type f -name "SKILL.md" -print0 >"$find_file" 2>"$find_err"; then
    echo "Warning: find encountered errors while scanning $base_dir:" >&2
    cat "$find_err" >&2
  fi

  sort_nul_file "$find_file"
}

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s\n' "$input"
  else
    printf '%s\n' "$ROOT_DIR/$input"
  fi
}

scan_user_path() {
  local resolved="$1" find_file="$2" find_err="$3"
  : >"$find_file"
  : >"$find_err"

  if [[ -f "$resolved" && "$(basename "$resolved")" == "SKILL.md" ]]; then
    printf '%s\0' "$resolved" >"$find_file"
    return 0
  fi

  if [[ -d "$resolved" ]]; then
    if ! find -L "$resolved" -type f -name "SKILL.md" -print0 >"$find_file" 2>"$find_err"; then
      echo "Warning: find encountered errors while scanning $resolved:" >&2
      cat "$find_err" >&2
    fi
    sort_nul_file "$find_file"
  fi
}

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

declare -A SEEN_PATHS=()
SKILL_INDEX=0

plugin_find="$TMP_DIR/plugin.find"
plugin_err="$TMP_DIR/plugin.err"
multi_find="$TMP_DIR/multi.find"
multi_err="$TMP_DIR/multi.err"
github_find="$TMP_DIR/github.find"
github_err="$TMP_DIR/github.err"

scan_pattern "$ROOT_DIR/skills" 2 2 "$plugin_find" "$plugin_err"
scan_pattern "$ROOT_DIR/plugins" 4 4 "$multi_find" "$multi_err"
scan_pattern "$ROOT_DIR/.github/copilot/skills" 2 2 "$github_find" "$github_err"

add_skill_records "$plugin_find" "plugin_root"
add_skill_records "$multi_find" "multi_plugin"
add_skill_records "$github_find" "github_copilot"

user_summary_files=()
for i in "${!USER_PATHS[@]}"; do
  declare resolved user_count
  user_find="$TMP_DIR/user-$i.find"
  user_err="$TMP_DIR/user-$i.err"
  resolved=$(resolve_path "${USER_PATHS[$i]}")
  scan_user_path "$resolved" "$user_find" "$user_err"
  user_count=$(node -e '
    const fs = require("fs");
    const data = fs.readFileSync(process.argv[1]);
    process.stdout.write(String(data.length === 0 ? 0 : data.reduce((count, byte) => count + (byte === 0 ? 1 : 0), 0)));
  ' "$user_find")

  jq -n \
    --arg input "${USER_PATHS[$i]}" \
    --arg resolved_path "$resolved" \
    --argjson found "$([[ $user_count -gt 0 ]] && echo true || echo false)" \
    --argjson count "$user_count" \
    '{input:$input,resolved_path:$resolved_path,found:$found,count:$count}' \
    > "$TMP_DIR/user-summary-$i.json"
  user_summary_files+=("$TMP_DIR/user-summary-$i.json")

  add_skill_records "$user_find" "user_provided"
done

if compgen -G "$TMP_DIR/skill-*.json" > /dev/null; then
  skills_json=$(jq -s '.' "$TMP_DIR"/skill-*.json)
else
  skills_json='[]'
fi

if ((${#user_summary_files[@]} > 0)); then
  user_summary_json=$(jq -s '.' "${user_summary_files[@]}")
else
  user_summary_json='[]'
fi

plugin_count=$(jq 'map(select(.source == "plugin_root")) | length' <<<"$skills_json")
multi_count=$(jq 'map(select(.source == "multi_plugin")) | length' <<<"$skills_json")
github_count=$(jq 'map(select(.source == "github_copilot")) | length' <<<"$skills_json")

jq -n \
  --arg root_dir "$ROOT_DIR" \
  --arg plugin_path "$ROOT_DIR/skills" \
  --arg multi_path "$ROOT_DIR/plugins" \
  --arg github_path "$ROOT_DIR/.github/copilot/skills" \
  --argjson plugin_found "$([[ -d "$ROOT_DIR/skills" ]] && echo true || echo false)" \
  --argjson plugin_count "$plugin_count" \
  --argjson multi_found "$([[ -d "$ROOT_DIR/plugins" ]] && echo true || echo false)" \
  --argjson multi_count "$multi_count" \
  --argjson github_found "$([[ -d "$ROOT_DIR/.github/copilot/skills" ]] && echo true || echo false)" \
  --argjson github_count "$github_count" \
  --argjson user_paths "$user_summary_json" \
  --argjson skills "$skills_json" \
  '{
    root_dir: $root_dir,
    scan_summary: {
      plugin_root: { path: $plugin_path, found: $plugin_found, count: $plugin_count },
      multi_plugin: { path: $multi_path, found: $multi_found, count: $multi_count },
      github_copilot: { path: $github_path, found: $github_found, count: $github_count },
      user_provided: $user_paths
    },
    skills: $skills
  }'
