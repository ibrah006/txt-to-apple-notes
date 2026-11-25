# txt-to-apple-notes

Import a folder of `.txt` notes into Apple Notes on macOS, keeping the folder layout.

- Every `.txt` file becomes a note. The file name becomes the note title.
- Subfolders become Notes folders.
- Every `.zip` file becomes a folder named after the zip, holding the notes inside it.
- Names exported by Quick Share are cleaned up: the `QuickShare_` prefix, `_YYMMDD_HHMMSS` timestamps and ` (1)` suffixes are removed.
- If a note's first line just repeats its title, that line is dropped.
- Line breaks, blank lines and runs of spaces are kept.
- Your source folder is never changed; the script works on a temporary copy.

## Usage

```bash
./import_notes.sh "/path/to/notes" [AccountName] [--dry-run]
```

`AccountName` is `iCloud` (default) or `On My Mac`.

Preview first, then import:

```bash
./import_notes.sh ~/Downloads/notes iCloud --dry-run
./import_notes.sh ~/Downloads/notes iCloud
```

## Notes

- The first run asks permission for your terminal to control Notes. Click Allow.
- Running it twice creates duplicate notes.
