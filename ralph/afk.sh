#!/bin/bash
set -e

# Usage: $0 [context-files] <iterations>
#   context-files: optional space-separated list of files to include as context
#   iterations:    number of AFK iterations to run
if [ "$#" -eq 2 ]; then
  context_files="$1"
  iterations="$2"
elif [ "$#" -eq 1 ]; then
  context_files=""
  iterations="$1"
else
  echo "Usage: $0 [\"file1 file2 ...\"] <iterations>"
  exit 1
fi

# jq filter to extract streaming text from assistant messages
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

# jq filter to extract final result
final_result='select(.type == "result").result // empty'

for ((i=1; i<=iterations; i++)); do
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
  issues=$(gh issue list --state open --json number,title,body,comments)
  prompt=$(cat ralph/prompt.md)

  # Build extra context from any files passed as first argument
  extra_context=""
  if [ -n "$context_files" ]; then
    for f in $context_files; do
      if [ -f "$f" ]; then
        extra_context+=$'\n\n'"=== $f ===\n"
        extra_context+=$(cat "$f")
      fi
    done
  fi

  docker sandbox run claude . -- \
    --verbose \
    --print \
    --output-format stream-json \
    "Previous commits: $commits $issues $prompt$extra_context" \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done
