;;; config-tools.el --- Dirvish, perspective, utilities -*- lexical-binding: t; -*-

;; Force dired/dirvish to start in normal mode
(with-eval-after-load 'evil
  (evil-set-initial-state 'dired-mode 'normal))

;; Enhanced dired file manager with preview and side panel
(use-package dirvish
  :init (dirvish-override-dired-mode)
  :config
  (evil-make-overriding-map dirvish-mode-map 'normal))

;; Per-project workspaces with isolated buffer lists and window layouts
(use-package perspective
  :demand t
  :init
  (setq persp-suppress-no-prefix-key-warning t)
  (persp-mode))

;; M-x restart-emacs
(use-package restart-emacs)

(provide 'config-tools)
;;; config-tools.el ends here
