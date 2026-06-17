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
  "s f" '(consult-fd :wk "find file")

  "p"   '(:ignore t :wk "project")
  "p p" '(project-switch-project :wk "projects")
  "p f" '(project-find-file :wk "find file")
  "p b" '(consult-project-buffer :wk "buffers")

  "P"   '(:ignore t :wk "Perspective")
  "P P" '(persp-switch :wk "perspectives")
  "P b" '(consult-buffer :wk "buffers")
  "P k" '(persp-kill :wk "kill")
  "P r" '(persp-rename :wk "rename")

  "g"   '(:ignore t :wk "git")
  "g g" '(magit-status :wk "status")
  "g l" '(magit-log-current :wk "log")
  "g b" '(magit-blame :wk "blame")
  "g d" '(magit-diff-dwim :wk "diff")
  "g f" '(magit-file-dispatch :wk "file actions")

  "w"   '(:ignore t :wk "windows")

  "l"   '(:ignore t :wk "layout")

  "t"   '(:ignore t :wk "toggles")
  "t t" '(consult-theme :wk "all themes")
  "t f" '(load-favorite-theme :wk "favorite themes")

  "e"   '(:ignore t :wk "errors")
  "e e" '(flymake-show-project-diagnostics :wk "project diagnostics")
  "e b" '(flymake-show-buffer-diagnostics :wk "buffer diagnostics")
  "e n" '(flymake-goto-next-error :wk "next error")
  "e p" '(flymake-goto-prev-error :wk "prev error")

  "h"   '(:ignore t :wk "help"))

;;;; , -- search (premium, right index, home row adjacent)
;; Starts from unstructured queries: text patterns, buffer names, error lists.
(comma-leader
  "," '(consult-buffer :wk "persp buffers")
  "s" '(consult-line :wk "lines")
  "r" '(consult-ripgrep :wk "ripgrep")
  "f" '(consult-fd :wk "filenames")
  "b" '(consult-project-buffer :wk "project buffers")
  "d" '(consult-ripgrep-in-dir :wk "ripgrep dir")
  "e" '(flymake-show-project-diagnostics :wk "errors"))

;;;; - -- navigation (premium, right hand, top row)
;; Starts from structured containers: file trees, projects, perspectives.
(dash-leader
  "-" '(project-dired :wk "project root")
  "p" '(project-switch-project :wk "projects")
  "f" '(project-find-file :wk "project files")
  "P" '(persp-switch :wk "perspectives")
  "." '(dirvish :wk "dirvish here")
  "d" '(dirvish-side :wk "sidebar"))

;;;; ; -- (good, right index, home row, TBD)
;; (semi-leader)

;;;; ` -- (good, left pinky, top row, TBD)
;; (backtick-leader)

;;;; ' -- (decent, right pinky, top row, reserved)
;; (quote-leader)

;;;; \ -- (okay, right pinky, bottom row, reserved)
;; (backslash-leader)

(provide 'config-keybinds)
;;; config-keybinds.el ends here
