;;; config-keybinds.el --- Leader keys and keybindings -*- lexical-binding: t; -*-
;;
;; Leader key priority (by ergonomic value):
;;   ,   Premium.  Right index, home row adjacent.  -> query (large scope)
;;   ;   Good.     Right index, home row.           -> structural (symbols, refs)
;;   '   Decent.   Right pinky, top row.            -> files (I/O + dir browser)
;;   -   Vacant.   Right hand, top row.             -> (unused)
;;   `   Good.     Left pinky, top row.             -> TBD
;;   \   Okay.     Right pinky, bottom row.         -> reserved
;;   SPC Categorical 2+ layer menu. Can nest deeper as needed
;;       (e.g. SPC g d f -> git diff file).
;;
;; Design principle: leaders are namespaced by scope, not by verb.
;;   ,   Query (project / perspective / frame) — start from a pattern.
;;   ;   Structural (symbols, references, file outline) — start from a point.
;;   '   Files (buffer I/O, directory browser) — act on the current file.

(use-package general
  :demand t
  :config
  (general-evil-setup t)

  ;; SPC -- categorical menu (2+ layers, extend depth as needed)
  (general-create-definer spc-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix "SPC")

  ;; Single-layer speed dials (leader + one key)
  (general-create-definer comma-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix ",")

  (general-create-definer semi-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix ";")

  (general-create-definer dash-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix "-")

  (general-create-definer backtick-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix "`")

  (general-create-definer quote-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix "'")

  (general-create-definer backslash-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix "\\"))

(defun my-toggle-messages ()
  "Toggle the *Messages* buffer.
When not viewing *Messages*, switch to it and force normal state.
When viewing it, bury it to the bottom of the buffer list."
  (interactive)
  (if (string= (buffer-name) "*Messages*")
      (bury-buffer)
    (switch-to-buffer "*Messages*")
    (when (fboundp 'evil-normal-state)
      (evil-normal-state 1))))

(use-package hydra
  :demand t
  :config
  (defhydra hydra-window (:hint nil)
    "
    ^Move^        ^Swap^        ^Split^       ^Close^       ^Tabs^
_h_ ← left    _H_ ← left    _v_  →        _q_  close     _c_  new
_j_ ↓ down    _J_ ↓ down    _s_  ↓        _o_  only      _C_  kill
_k_ ↑ up      _K_ ↑ up      _=_  balance   _w_  other     _r_  rename
_l_ → right   _L_ → right                                _{_  prev
← ↑ ↓ →       S-← S-↑ S-↓ S-→                              _}_  next
"
    ("h" windmove-left)
    ("j" windmove-down)
    ("k" windmove-up)
    ("l" windmove-right)
    ("<left>" windmove-left)
    ("<down>" windmove-down)
    ("<up>" windmove-up)
    ("<right>" windmove-right)
    ("<S-left>" windmove-swap-states-left)
    ("<S-down>" windmove-swap-states-down)
    ("<S-up>" windmove-swap-states-up)
    ("<S-right>" windmove-swap-states-right)
    ("H" windmove-swap-states-left)
    ("J" windmove-swap-states-down)
    ("K" windmove-swap-states-up)
    ("L" windmove-swap-states-right)
    ("v" split-window-right)
    ("s" split-window-below)
    ("q" delete-window)
    ("o" delete-other-windows)
    ("=" balance-windows)
    ("w" other-window)
    ("c" tab-new)
    ("C" tab-close)
    ("r" tab-rename)
    ("{" tab-previous)
    ("}" tab-next))

  ;; Outline navigation.  Sticky menu so you can tap n/N repeatedly
  ;; without re-pressing SPC.  Requires outline-minor-mode for headings,
  ;; which `;s` lazy-enables on first invocation.  No-op gracefully
  ;; outside outline-minor-mode.
  (defhydra hydra-outline (:hint nil)
    "
^n_: next heading      ^a_: show all      _q_: exit
^N_: prev heading      _s_: peek entry    _ESC_: exit
                      _c_/_TAB_: cycle
                      _h_: hide sublevels
                      _H_: hide body
"
    ("n" outline-next-heading)
    ("N" outline-previous-heading)
    ("a" outline-show-all)
    ("s" outline-show-entry)
    ("h" outline-hide-sublevels)
    ("H" outline-hide-body)
    ("c" outline-cycle)
    ("TAB" outline-cycle)
    ("q" nil :exit t)
    ("ESC" nil :exit t))
  (defun hydra-outline--ensure-mode ()
    "Lazy-enable outline-minor-mode if not already active.  Run before hydra."
    (interactive)
    (unless (bound-and-true-p outline-minor-mode)
      (outline-minor-mode 1)))
  (advice-add 'hydra-outline/body :before #'hydra-outline--ensure-mode))

;;;; SPC -- categorical menu
;; Layers can nest deeper than 2 when needed (e.g. SPC g d f -> git diff file).

(spc-leader
  "b"   '(:ignore t :wk "buffers")
  "b b" '(consult-buffer :wk "buffers")
  "b a" '(persp-switch-to-buffer :wk "all buffers")
  "b q" '(persp-quit-buffer :wk "quit")
  "b k" '(kill-buffer :wk "kill")
  "b m" '(my-toggle-messages :wk "messages")

  "f"   '(:ignore t :wk "files")
  "f f" '(find-file :wk "files")
  "f s" '(save-buffer :wk "write")
  "f r" '(recentf-open-files :wk "recent")

  "s"   '(:ignore t :wk "search")
  "s s" '(consult-line :wk "lines")
  "s r" '(consult-ripgrep :wk "ripgrep")
  "s F" '(consult-fd-in-dir :wk "fd by dir")
  "s d" '(consult-ripgrep-in-dir :wk "ripgrep by dir")
  "s i" '(consult-imenu :wk "file symbols")

  "p"   '(:ignore t :wk "project")
  "p p" '(project-switch-project :wk "projects")
  "p f" '(my-persp-project-find-file :wk "find file")
  "p b" '(consult-project-buffer :wk "buffers")

  "g"   '(:ignore t :wk "git")
  "g g" '(magit-status :wk "status")
  "g l" '(magit-log-current :wk "log")
  "g b" '(magit-blame :wk "blame")
  "g d" '(magit-diff-dwim :wk "diff")
  "g f" '(magit-file-dispatch :wk "file actions")

  "w"   '(hydra-window/body :wk "windows")

  "l"   '(:ignore t :wk "layout")
  "l l" '(my-persp-switch :wk "layouts")
  "l b" '(consult-buffer :wk "buffers")
  "l k" '(persp-kill :wk "kill")
  "l r" '(persp-rename :wk "rename")

  "q"   '(:ignore t :wk "quit")
  "q q" '(save-buffers-kill-emacs :wk "quit")
  "q Q" '(kill-emacs :wk "force quit")
  "q r" '(my-restart-emacs :wk "restart")

  "t"   '(:ignore t :wk "toggles")
  "t t" '(consult-theme :wk "all themes")
  "t f" '(load-favorite-theme :wk "favorite themes")

  "c"   '(:ignore t :wk "code")
  "c R" '(eglot-rename :wk "rename")
  "c a" '(eglot-code-actions :wk "actions")

  "e"   '(:ignore t :wk "errors")
  "e e" '(flymake-show-project-diagnostics :wk "project diagnostics")
  "e b" '(flymake-show-buffer-diagnostics :wk "buffer diagnostics")
  "e n" '(flymake-goto-next-error :wk "next error")
  "e p" '(flymake-goto-prev-error :wk "prev error")

  "h"   '(:ignore t :wk "help")

  "n"   '(:ignore t :wk "notes")
  "n f" '(org-roam-node-find :wk "find node")
  "n i" '(org-roam-node-insert :wk "insert link")
  "n c" '(org-roam-capture :wk "capture")
  "n t" '(org-roam-tag-add :wk "tag")
  "n b" '(org-roam-buffer-toggle :wk "backlinks")
  "n g" '(org-roam-graph :wk "graph")

  "o"   '(hydra-outline/body :wk "outline"))

;;;; , -- query (premium, right index, home row adjacent)
;; Large scope: project, perspective, frame.
(comma-leader
  "," '(consult-buffer :wk "buffers")
  "f" '(my-persp-project-find-file :wk "find file")
  "g" '(consult-ripgrep :wk "grep")
  "l" '(my-persp-switch :wk "layouts")
  "e" '(flymake-show-project-diagnostics :wk "errors"))

;;;; - -- (vacant, right hand, top row)
;; (dash-leader)

;;;; ; -- structural (right index, home row)
;; Symbol and reference traversal, file outline.
(semi-leader
  "d" '(xref-find-definitions :wk "definition")
  "D" '(eglot-find-declaration :wk "declaration")
  "r" '(xref-find-references :wk "references")
  "i" '(eglot-find-implementation :wk "implementation")
  "t" '(eglot-find-typeDefinition :wk "type def")
  "s" '(my/structural-focus :wk "symbols")
  "g" '(consult-line :wk "grep file")
  "p" '(my/structural-parents :wk "parent blocks")
  "P" '(my/structural-parent :wk "parent jump")
  "b" '(xref-go-back :wk "back")
  "f" '(xref-go-forward :wk "forward"))

;;;; ` -- (good, left pinky, top row, TBD)
;; (backtick-leader)

;;;; ' -- files (file I/O + directory browser)
(quote-leader
  "w" '(save-buffer :wk "write")
  "r" '(revert-buffer :wk "revert")
  "f" '(write-file :wk "fork")
  "y" '(my-copy-file-name :wk "yank path")
  "-" '(dirvish :wk "dirvish")
  "d" '(dirvish-side-toggle :wk "dirvish side"))

;;;; \ -- (okay, right pinky, bottom row, reserved)
;; (backslash-leader)

(provide 'config-keybinds)
;;; config-keybinds.el ends here
