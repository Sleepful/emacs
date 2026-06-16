;;; core.el --- UI, quality-of-life, macOS settings -*- lexical-binding: t; -*-

;; UI basics
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(blink-cursor-mode -1)
(global-hl-line-mode t)
(global-display-line-numbers-mode t)
(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq ring-bell-function 'ignore)

;; Quality-of-life
(setq make-backup-files nil)
(setq auto-save-default nil)
(recentf-mode 1)
(setq recentf-max-menu-items 25)
(setq select-enable-clipboard t)
(pixel-scroll-precision-mode 1)
(setq pixel-scroll-precision-use-momentum t)

;; macOS: inherit shell PATH so Emacs finds Homebrew binaries (rg, fd, etc.)
(use-package exec-path-from-shell
  :demand t
  :config (exec-path-from-shell-initialize))

;; macOS: make Option send Meta so Alt keybinds work in GUI
(setq mac-option-modifier 'meta)
(setq mac-right-option-modifier 'none)

;; Popup showing available keybindings after a prefix
(use-package which-key
  :init (which-key-mode)
  :config
  (setq which-key-idle-delay 0.3)
  (setq which-key-idle-secondary-delay 0.1))

(provide 'core)
;;; core.el ends here
