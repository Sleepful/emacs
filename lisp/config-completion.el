;;; config-completion.el --- Completion stack -*- lexical-binding: t; -*-

;; Forward-compatibility shims for older Emacs versions
(use-package compat
  :demand t)

;; Vertical completion UI for the minibuffer
(use-package vertico
  :demand t
  :init (vertico-mode)
  :bind (:map vertico-map
         ("<next>" . vertico-scroll-up)
         ("<prior>" . vertico-scroll-down)))

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

(defun consult-ripgrep-in-dir ()
  (interactive)
  (let ((dir (read-directory-name "Ripgrep in: ")))
    (consult-ripgrep dir)))

(defun consult-recent-file-in-project ()
  (interactive)
  (let* ((pr (project-current t))
         (root (expand-file-name (project-root pr)))
         (files (seq-filter (lambda (f) (string-prefix-p root (expand-file-name f)))
                            recentf-list)))
    (find-file (consult--read files
                              :prompt "Recent project file: "
                              :sort nil
                              :require-match t
                              :category 'file))))

(provide 'config-completion)
;;; config-completion.el ends here
