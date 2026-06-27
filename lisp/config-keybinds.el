;;; config-keybinds.el --- Leader keys and keybindings -*- lexical-binding: t; -*-

;; Leader key priority (by ergonomic value):
;;   ,   Premium.  Right index, home row adjacent.  -> search (unstructured)
;;   -   Premium.  Right hand, top row.             -> navigation (structured)
;;   ;   Good.     Right index, home row.           -> TBD
;;   `   Good.     Left pinky, top row.             -> TBD
;;   '   Decent.   Right pinky, top row.            -> reserved
;;   \   Okay.     Right pinky, bottom row.         -> reserved
;;   SPC Categorical 2+ layer menu. Can nest deeper as needed
;;       (e.g. SPC g d f -> git diff file).
;;
;; Design principle for speed dials:
;;   - (navigation) starts from structured containers: file trees, projects, perspectives
;;   , (search) starts from unstructured queries: text patterns, buffer names, error lists

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
    ("}" tab-next)))

;;;; SPC -- categorical menu
;; Layers can nest deeper than 2 when needed (e.g. SPC g d f -> git diff file).

(spc-leader
  "b"   '(:ignore t :wk "buffers")
  "b b" '(consult-buffer :wk "buffers")
  "b B" '(persp-switch-to-buffer :wk "all buffers")
  "b q" '(persp-quit-buffer :wk "quit")
  "b k" '(kill-buffer :wk "kill")

  "f"   '(:ignore t :wk "files")
  "f f" '(find-file :wk "files")
  "f s" '(save-buffer :wk "save")
  "f r" '(recentf-open-files :wk "recent")

  "s"   '(:ignore t :wk "search")
  "s s" '(consult-line :wk "lines")
  "s r" '(consult-ripgrep :wk "ripgrep")
  "s f" '(my-persp-project-find-file :wk "find file")
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
  "n g" '(org-roam-graph :wk "graph"))

;;;; , -- search (premium, right index, home row adjacent)
;; Starts from unstructured queries: text patterns, buffer names, error lists.
(comma-leader
  "," '(consult-buffer :wk "buffers")
  "B" '(persp-switch-to-buffer :wk "all buffers")
  "f" '(my-persp-project-find-file :wk "find file")
  "s" '(consult-line :wk "lines")
  "r" '(consult-ripgrep :wk "ripgrep")
  "d" '(dirvish-side-toggle :wk "sidebar dirvish")
  "l" '(my-persp-switch :wk "layouts")
  "e" '(flymake-show-project-diagnostics :wk "errors"))

;;;; - -- navigation (premium, right hand, top row)
;; Starts from structured containers: file trees, projects, perspectives.
(dash-leader
  "-" '(dirvish :wk "dirvish here")
  "p" '(project-switch-project :wk "projects")
  "f" '(my-persp-project-find-file :wk "project files")
  "l" '(my-persp-switch :wk "layouts"))

;;;; ; -- code intelligence (right index, home row, LSP navigation)
;; Symbol traversal, not unstructured search. Named "code" not "LSP"
;; to avoid binding to an implementation detail.
(semi-leader
  "d" '(xref-find-definitions :wk "definition")
  "D" '(eglot-find-declaration :wk "declaration")
  "r" '(xref-find-references :wk "references")
  "i" '(eglot-find-implementation :wk "implementation")
  "t" '(eglot-find-typeDefinition :wk "type def")
  "R" '(eglot-rename :wk "rename")
  "a" '(eglot-code-actions :wk "actions")
  "b" '(xref-go-back :wk "back")
  "f" '(xref-go-forward :wk "forward"))

;;;; ` -- (good, left pinky, top row, TBD)
;; (backtick-leader)

;;;; ' -- (decent, right pinky, top row, reserved)
;; (quote-leader)

;;;; \ -- (okay, right pinky, bottom row, reserved)
;; (backslash-leader)

(provide 'config-keybinds)
;;; config-keybinds.el ends here
