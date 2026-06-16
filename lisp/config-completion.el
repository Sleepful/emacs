;;; config-completion.el --- Completion stack -*- lexical-binding: t; -*-

;; Forward-compatibility shims for older Emacs versions
(use-package compat
  :demand t)

;; Vertical completion UI for the minibuffer
(use-package vertico
  :demand t
  :init (vertico-mode))

;; Space-separated completion matching (fuzzy, regexp, literal)
(use-package orderless
  :demand t
  :init
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles . (partial-completion))))))

;; Rich annotations in the minibuffer (docstrings, file sizes, etc.)
(use-package marginalia
  :demand t
  :init (marginalia-mode))

;; Enhanced search and navigation commands (buffer switch, grep, line search)
(use-package consult)

(provide 'config-completion)
;;; config-completion.el ends here
