#!/bin/bash
# Usage: ./import_notes.sh "/path/to/notes" [AccountName] [--dry-run]
# AccountName is "iCloud" (default) or "On My Mac".
# Every .zip becomes a folder (named after the zip) holding its notes.
# The original folder is left untouched; the script works on a temp copy.
set -euo pipefail
SRC="${1%/}"
ACCOUNT="${2:-iCloud}"
DRY="${3:-}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$SRC"/. "$WORK"/

clean() { # strip "QuickShare_", "_YYMMDD_HHMMSS", " (1)", extra spaces
  sed -E -e 's/^QuickShare_//' \
         -e 's/[[:space:]]*\([0-9]+\)$//' \
         -e 's/_[0-9]{6}(_[0-9]{6})?$//' \
         -e 's/[[:space:]]{2,}/ /g' -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//' <<<"$1"
}

# Unpack each zip into a folder with the zip's cleaned name
find "$WORK" -type f -name '*.zip' -print0 | while IFS= read -r -d '' z; do
  dest="$(dirname "$z")/$(clean "$(basename "$z" .zip)")"
  mkdir -p "$dest"
  unzip -qq -o "$z" -d "$dest"
  rm "$z"
done

find "$WORK" -type f -name '*.txt' -print0 | sort -z | while IFS= read -r -d '' f; do
  rel="${f#$WORK/}"
  dir="$(dirname "$rel")"; [ "$dir" = "." ] && dir=""
  title="$(clean "$(basename "$f" .txt)")"

  if [ "$DRY" = "--dry-run" ]; then
    echo "${dir:-(top level)}  →  $title"
    continue
  fi

  # One <div> per line (Notes' own format). Escape HTML, keep runs of spaces,
  # and drop the first line when it just repeats the title.
  content="$(tr -d '\r' < "$f" | awk -v t="$title" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    NR == 1 && tolower(trim($0)) == tolower(t) { next }
    !started && trim($0) == "" { next }
    { started = 1
      gsub(/&/, "\\&amp;"); gsub(/</, "\\&lt;"); gsub(/>/, "\\&gt;")
      gsub(/\t/, "    "); gsub(/  /, " \\&nbsp;")
      printf "%s", ($0 == "" ? "<div><br></div>" : "<div>" $0 "</div>")
    }')"
  safe_title="$(sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<<"$title")"
  body="<div><h1>${safe_title}</h1></div>${content}"

  osascript - "$ACCOUNT" "$dir" "$body" <<'EOF'
on run argv
  set acctName to item 1 of argv
  set folderPath to item 2 of argv
  set noteBody to item 3 of argv
  tell application "Notes"
    if folderPath is "" then
      make new note at (default folder of account acctName) with properties {body:noteBody}
    else
      set parentFolder to account acctName
      set AppleScript's text item delimiters to "/"
      set parts to text items of folderPath
      set AppleScript's text item delimiters to ""
      repeat with p in parts
        set n to contents of p
        if (exists folder n of parentFolder) then
          set parentFolder to folder n of parentFolder
        else
          set parentFolder to make new folder at parentFolder with properties {name:n}
        end if
      end repeat
      make new note at parentFolder with properties {body:noteBody}
    end if
  end tell
end run
EOF
  echo "Imported: ${dir:+$dir/}$title"
done
