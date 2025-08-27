Snapshots for `bookdrop/html_templates.lua`

This directory contains HTML snapshots used by tests. They are stored as `.html` so they can be opened in a browser for human inspection.

To regenerate the snapshots run:

```bash
./scripts/update-snapshots.sh
```

If you update `bookdrop/html_templates.lua`, run the script and commit the changed snapshots.

To view snapshots in your browser:

```bash
xdg-open spec/snapshots/header_Test.html
```

To run snapshot tests:

```bash
busted spec/snapshots_spec.lua
```
