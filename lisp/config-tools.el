;;; config-tools.el --- Dirvish, perspective, utilities -*- lexical-binding: t; -*-

;; Force dired/dirvish to start in normal mode
(with-eval-after-load 'evil
  (evil-set-initial-state 'dired-mode 'normal))

;; Enhanced dired file manager with preview and side panel
(defun dirvish-enter ()
  (interactive)
  (if (file-directory-p (dired-get-file-for-visit))
      (dirvish-subtree-toggle)
    (dired-find-file)))

(use-package dirvish
  :init (dirvish-override-dired-mode)
  :config
  (evil-make-overriding-map dirvish-mode-map 'normal)
  (define-key dirvish-mode-map (kbd "RET") 'dirvish-enter)
  (define-key dirvish-mode-map (kbd "TAB") 'dirvish-subtree-toggle))

;; Per-project workspaces with isolated buffer lists and window layouts
(use-package perspective
  :demand t
  :init
  (setq persp-suppress-no-prefix-key-warning t)
  (persp-mode))

;; Git interface
(use-package magit
  :config
  (transient-append-suffix 'magit-rebase "-d"
    '("-D" "Regenerate author date" "--ignore-date")))

;; M-x restart-emacs
(use-package restart-emacs)

(provide 'config-tools)
;;; config-tools.el ends here
