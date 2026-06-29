# Emacs config guidelines

## Keybinding antipatterns

| Trap                | Why it kills configs                                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **The junk drawer** | `SPC m` for "misc." Everything goes there. You forget what you bound.                                                          |
| **Category bleed**  | Putting `, s` for save-buffer under buffer leader. Save is a **file** action, not a buffer action. It breaks the mental model. |
| **Verb-first**      | `; o` for "open" (open what? file? buffer? org?). Namespaces must be nouns.                                                    |
| **Over-promotion**  | Giving a single-prefix leader to a category you use twice a day. It wastes mental space and which-key clutter.                 |

## Speed dial design principle

| Leader | Role | Mental model |
| ------ | ---- | ------------ |
| `-`    | navigation | Starts from **structured containers**: file trees, projects, perspectives. "Show me the structure, I'll pick." |
| `,`    | search     | Starts from **unstructured queries**: text patterns, buffer names, error lists. "I have a pattern, find matches." |

The distinction: `-` browses structure. `,` matches content. Both reach the same destinations. The difference is starting intent.

Verb-namespaces ("search") are acceptable when the verb is unambiguous and spans multiple nouns. "Search" means one thing. "Open" means nothing without a noun.

## Daemon, socket, and restart

Emacs runs as a **headless daemon** which the user connects to via `emacsclient`.
This avoids the ~4s macOS NSWindow creation tax on config reload — the daemon
restarts headlessly (~1.2s Lisp init), and frames are opened instantly by the
client.

### Architecture

| Component | Role |
|-----------|------|
| `emacs --daemon` | Starts Emacs headlessly. Runs init, opens no frame. Exits after `kill-emacs`. |
| `server-start` (in `core.el`) | Starts the server inside every Emacs instance so `emacsclient` can connect. The daemon calls this automatically. |
| `Emacs Client.app` | macOS `.app` bundle that runs `emacsclient -c -a ""`. The `-a ""` auto-starts a daemon if none is running, then opens a frame. The user launches this, not `Emacs.app`. |
| `my-restart-emacs` (in `config-tools.el`) | One-shot config reload: spawns a background shell that waits for the old daemon to die, starts a new daemon, then calls `emacsclient -c -n` to reconnect. The user runs `M-x my-restart-emacs` after changing config. |

### Socket

The server creates a Unix socket. By default this lives in `TMPDIR/emacs*/server`.
The socket directory is NOT customized — `emacsclient` must be able to find it.
When `Emacs Client.app` auto-starts a daemon via `-a ""`, both daemon and client
inherit the same `TMPDIR` from launchd, so they agree on the socket path.

**Do not set `server-socket-dir`.** The custom directory broke `Emacs Client.app`
because `emacsclient` doesn't know about it unless passed `--socket-name`.

### Stale socket recovery

If the daemon crashes, the socket file persists but no process is listening.
The next `emacs --daemon` fails with "Unable to start the Emacs server."

`my-restart-emacs` calls `server-force-delete` before `kill-emacs` to clean the
socket. On a normal restart this prevents stale sockets. After a crash, the
background script spawned by `my-restart-emacs` includes a `sleep 1` to ensure
the old daemon fully exits before the new one binds.

Manual recovery after a crash: `rm TMPDIR/emacs*/server` and restart the daemon.

### Frame size in daemon mode

`display-pixel-width` returns terminal column width (80) when headless — not 0
and not nil. Checking `(> pw 0)` is insufficient. Use `(display-graphic-p)` to
decide between pixel-based width (GUI) and column-based fallback (daemon).

The `fullscreen . fullheight` setting in `default-frame-alist` applies
regardless of daemon vs GUI and works correctly.

### exec-path-from-shell

GUI Emacs on macOS inherits launchd's minimal PATH (no asdf shims, no Homebrew).
`exec-path-from-shell` copies the full shell PATH into Emacs. The startup-file
freshness check (`exec-path-from-shell-check-startup-files`) is disabled because
it re-parses `.zshrc` every daemon restart (adds ~800ms). Set to nil in
`core.el`.

### Perspective state file

The saved state file at `var/perspective-state` can become corrupted if buffers
referenced in a saved perspective are deleted or relocated. The restore in
`config-tools.el` uses `ignore-errors` to prevent marker errors from blocking
daemon startup. If startup prompts "Marker does not point anywhere", delete
the state file and let it regenerate on the next clean exit.

## Tools

**`bin/check-parens`** — verify paren balance after editing Elisp. Run before restarting Emacs:

```
bin/check-parens lisp/core.el lisp/config-evil.el
```

Prints file:line for extra closes, or final balance if unclosed opens remain. Non-zero exit means the file won't load.

**`bin/parinfer`** — rebalance parens from indentation on a single Lisp file in place. Reads `<file>`, runs `parinfer.indentMode(text, {forceBalance: true})` (npm `parinfer@3.x`, ISC), writes back only if changed.

```
bin/parinfer path/to/file.el
```

Use when **parens are wrong but indentation is intentional** — agents — DiffSynth, Aider, Codex — frequently produce code where the paren count from the model is off but the leading whitespace reflects what the author meant. Indent-mode with `forceBalance: true` is the canonical move: close-parens snap to where the indentation says they belong, and orphan unbalanced parens are also fixed. After parinfer, the file is parse-correct by construction — **`bin/check-parens` is for hand-typed Lisp that bypassed parinfer, not for post-parinfer verification.**

**Caveats**

- Parinfer trusts indentation. Mis-indented code gets wrong parens. **Conversely, valid Lisp whose indentation does not match Parinfer's heuristic rules will be silently rewritten** — including line shifts of trailing close parens. **Treat parinfer as a fix-on-demand tool, not an always-applied formatter.** Run it once when parens need repair; do not loop it through edit pipelines, since agents reading line-based state (LSPs, code maps) will desync if every file shifts every cycle.
- The visual close-parens after each line get **dimmed** in editors that respect Parinfer styling — they are inferred, not literal. After a parinfer write, do not be surprised by the trailing-paren positions in your file.
- Force-balance mode (`forceBalance: true`) is the v1 aggressive-balance rule. With the default `false`, orphan unbalanced parens stay put and only recoverable ones get fixed. Use force-balance here.
- **Idempotent**: if `result.text === input.text`, no write happens; mtime is preserved.

**Bootstrap** — first run only:

```
bin/install-parinfer
```

Installs `parinfer` under `~/.config/emacs/node_modules/`. Idempotent. The CLI requires Node and npm.
