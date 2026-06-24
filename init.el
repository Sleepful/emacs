;;; init.el --- Entry point -*- lexical-binding: t; -*-

;; Package system
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(setq package-enable-at-startup nil)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)
(setq use-package-always-defer t)

;; Load config modules
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'core)
(require 'config-evil)
(require 'config-keybinds)
(require 'config-completion)
(require 'config-tools)
(require 'config-lang)

(provide 'init)
;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
  '(package-selected-packages
    '(catppuccin-theme consult dashboard dash dirvish doom-themes
		      ef-themes evil evil-collection exec-path-from-shell
		      general magit magit-delta marginalia odin-ts-mode
		      orderless perspective restart-emacs treesit-auto
		      use-package vertico which-key))
 '(package-vc-selected-packages
   '((odin-ts-mode :url "https://github.com/Sampie159/odin-ts-mode"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
