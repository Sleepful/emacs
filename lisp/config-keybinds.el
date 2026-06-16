;;; config-keybinds.el --- Leader keys and keybindings -*- lexical-binding: t; -*-

;; Leader key priority (by ergonomic value):
;;   ,   Premium.  Right index, home row adjacent.  -> project navigation
;;   ;   Premium.  Right index, home row.           -> search
;;   -   Premium.  Right hand, top row.             -> files
;;   `   Good.     Left pinky, top row.             -> git/project
;;   '   Decent.   Right pinky, top row.            -> toggles (reserved)
;;   \   Okay.     Right pinky, bottom row.         -> windows/help (reserved)
;;   SPC Categorical 2+ layer menu. Can nest deeper as needed
;;       (e.g. SPC g d f -> git diff file).

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

;;;; SPC -- categorical menu
;; Layers can nest deeper than 2 when needed (e.g. SPC g d f -> git diff file).

(spc-leader
  "b"   '(:ignore t :wk "buffers")
  "b b" '(consult-buffer :wk "switch")
  "b k" '(kill-buffer :wk "kill")

  "f"   '(:ignore t :wk "files")
  "f f" '(find-file :wk "find")
  "f s" '(save-buffer :wk "save")
  "f r" '(recentf-open-files :wk "recent")
  "f d" '(dirvish-side :wk "dirvish")

  "s"   '(:ignore t :wk "search")
  "s s" '(consult-line :wk "lines")
  "s r" '(consult-ripgrep :wk "ripgrep")
  "s f" '(consult-fd :wk "find file")

  "p"   '(:ignore t :wk "project")
  "p p" '(project-switch-project :wk "switch project")
  "p f" '(project-find-file :wk "find file")
  "p b" '(consult-project-buffer :wk "project buffer")
  "p s" '(persp-switch :wk "perspective switch")
  "p k" '(persp-kill :wk "perspective kill")

  "g"   '(:ignore t :wk "git")
  "g g" '(magit-status :wk "status")
  "g l" '(magit-log-current :wk "log")
  "g b" '(magit-blame :wk "blame")
  "g d" '(magit-diff-dwim :wk "diff")
  "g f" '(magit-file-dispatch :wk "file actions")

  "w"   '(:ignore t :wk "windows")

  "t"   '(:ignore t :wk "toggles")
  "t t" '(consult-theme :wk "all themes")
  "t f" '(load-favorite-theme :wk "favorite themes")

  "e"   '(:ignore t :wk "errors")
  "e e" '(flymake-show-project-diagnostics :wk "project diagnostics")
  "e b" '(flymake-show-buffer-diagnostics :wk "buffer diagnostics")
  "e n" '(flymake-goto-next-error :wk "next error")
  "e p" '(flymake-goto-prev-error :wk "prev error")

  "h"   '(:ignore t :wk "help"))

;;;; , -- project navigation (premium, right index, home row adjacent)
(comma-leader
  "b" '(consult-project-buffer :wk "project buffer")
  "B" '(consult-buffer :wk "all buffers")
  "f" '(project-find-file :wk "find file in project")
  "r" '(consult-ripgrep :wk "ripgrep project")
  "d" '(consult-ripgrep-in-dir :wk "ripgrep directory")
  "h" '(consult-recent-file-in-project :wk "recent project files")
  "." '(dirvish :wk "dirvish here"))

;;;; ; -- search (premium, right index, home row)
(semi-leader
  "s" '(consult-line :wk "search lines")
  "r" '(consult-ripgrep :wk "ripgrep")
  "f" '(consult-fd :wk "find file"))

;;;; - -- (premium, right hand, top row, reserved)
;; (dash-leader)

;;;; ` -- git/project (good, left pinky, top row)
(backtick-leader
  "p" '(project-switch-project :wk "switch project")
  "f" '(project-find-file :wk "find file in project")
  "s" '(persp-switch :wk "switch perspective")
  "P" '(persp-kill :wk "kill perspective")
  "g" '(magit-status :wk "git status"))

;;;; ' -- toggles (decent, right pinky, top row, reserved)
;; (quote-leader)

;;;; \ -- windows/help (okay, right pinky, bottom row, reserved)
;; (backslash-leader)

(provide 'config-keybinds)
;;; config-keybinds.el ends here
