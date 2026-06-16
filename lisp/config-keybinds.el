;;; config-keybinds.el --- Leader keys and keybindings -*- lexical-binding: t; -*-

;; Leader key priority (by ergonomic value):
;;   ,   Premium.  Right index, home row adjacent.  -> buffers
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

  "p"   '(:ignore t :wk "perspectives")
  "p p" '(persp-switch :wk "switch")
  "p k" '(persp-kill :wk "kill")

  "g"   '(:ignore t :wk "git")
  ;; "g g" '(magit-status :wk "status")

  "w"   '(:ignore t :wk "windows")

  "t"   '(:ignore t :wk "toggles")

  "h"   '(:ignore t :wk "help"))

;;;; , -- buffers (premium, right index, home row adjacent)
(comma-leader
  "b" '(consult-buffer :wk "switch buffer")
  "k" '(kill-buffer :wk "kill buffer"))

;;;; ; -- search (premium, right index, home row)
(semi-leader
  "s" '(consult-line :wk "search lines")
  "r" '(consult-ripgrep :wk "ripgrep")
  "f" '(consult-fd :wk "find file"))

;;;; - -- files (premium, right hand, top row)
(dash-leader
  "f" '(find-file :wk "find file")
  "s" '(save-buffer :wk "save")
  "r" '(recentf-open-files :wk "recent files")
  "d" '(dirvish-side :wk "dirvish"))

;;;; ` -- git/project (good, left pinky, top row)
(backtick-leader
  "p" '(persp-switch :wk "switch perspective")
  "P" '(persp-kill :wk "kill perspective"))
;; "g" '(magit-status :wk "git status")

;;;; ' -- toggles (decent, right pinky, top row, reserved)
;; (quote-leader)

;;;; \ -- windows/help (okay, right pinky, bottom row, reserved)
;; (backslash-leader)

(provide 'config-keybinds)
;;; config-keybinds.el ends here
