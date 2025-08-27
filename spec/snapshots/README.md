# Snapshots for `bookdrop/html_templates.lua`

This directory contains HTML snapshots used by tests. They are stored as `.html` so they can be opened in a browser for human inspection.

To regenerate the snapshots run:

```bash
./scripts/update-snapshots.sh
# Snapshots for `bookdrop/html_templates.lua`

This directory contains human-readable HTML snapshots used by the test suite. Snapshots are stored as `.html` so you can open them in a browser for easy inspection.

Regenerate snapshots

```bash
./scripts/update-snapshots.sh
```

The script renders the templates and overwrites the `.html` snapshot files in this directory. After regenerating, review the diffs and commit only the expected changes.

Run snapshot tests

```bash
busted spec/snapshots_spec.lua
```

Open a snapshot in your browser

```bash
xdg-open spec/snapshots/header_Test.html
```

Notes

- If `bookdrop/html_templates.lua` changes, regenerate snapshots and verify the diff before committing.
