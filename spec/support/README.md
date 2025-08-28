Test support helpers

This folder contains lightweight mocks used by the unit tests. Tests should avoid redefining these mocks directly and instead:

- Require `spec.support.init` to ensure common mocks are available (dbg, logger, gettext, socket, ui/uimanager, etc.)
- Use `spec.support.setup.require_net_utils_with_socket` to load `bookdrop.net_utils` with a custom `socket` mock when necessary

If you add new mocks, place them here and prefer module-like paths (for example `spec/support/ui/uimanager.lua`) so they can be required as `ui/uimanager` by tests when appropriate.
