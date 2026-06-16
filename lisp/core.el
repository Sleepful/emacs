;;; core.el --- UI, quality-of-life, macOS settings -*- lexical-binding: t; -*-

;; Font
(set-face-attribute 'default nil
                    :family "Iosevka Nerd Font Mono"
                    :height 144
                    :weight 'light)
(setq text-scale-mode-step 1.05)

;; Themes
(use-package catppuccin-theme
  :demand t
  :init (setq catppuccin-flavor 'frappe)
  :config (load-theme 'catppuccin t))

(use-package ef-themes
  :demand t)

(use-package doom-themes
  :demand t)

;; Remove built-in themes from selection
(setq custom-theme-load-path
      (cl-remove-if (lambda (p)
                      (or (eq p t)
                          (and (stringp p)
                               (file-in-directory-p p data-directory))))
                    custom-theme-load-path))

(defvar favorite-themes
  '("catppuccin-latte"
    "catppuccin-frappe"
    "catppuccin-macchiato"
    "catppuccin-mocha"
    "ef-melissa-dark"
    "doom-one"
    "doom-nord"
    "doom-henna"
    "doom-horizon"
    "doom-lantern"
    "doom-peacock"
    "doom-zenburn"
    "doom-miramare"
    "doom-palenight"
    "doom-spacegrey"
    "doom-monokai-pro"
    "doom-oksolar-dark"
    "doom-solarized-dark"
    "doom-solarized-light"))

(defun load-favorite-theme--apply (choice)
  (mapc #'disable-theme custom-enabled-themes)
  (if (string-prefix-p "catppuccin-" choice)
      (progn
        (setq catppuccin-flavor (intern (string-remove-prefix "catppuccin-" choice)))
        (load-theme 'catppuccin t))
    (load-theme (intern choice) t)))

(defun load-favorite-theme ()
  (interactive)
  (let* ((saved (if (eq (car custom-enabled-themes) 'catppuccin)
                    (concat "catppuccin-" (symbol-name catppuccin-flavor))
                  (symbol-name (or (car custom-enabled-themes) 'default)))))
    (consult--read
     favorite-themes
     :prompt "Theme: "
     :require-match t
     :lookup (lambda (selected &rest _) (or selected saved))
     :state (lambda (action cand)
              (pcase action
                ('return (load-favorite-theme--apply (or cand saved)))
                ((and 'preview (guard cand))
                 (load-favorite-theme--apply cand)))))))

;; Start screen with recent files and projects
(use-package dashboard
  :demand t
  :config
  (setq dashboard-projects-backend 'project-el)
  (setq dashboard-items '((recents . 10)
                           (projects . 5)))
  (setq dashboard-center-content t)
  (setq dashboard-startup-banner 'logo)
  (setq initial-buffer-choice (lambda () (get-buffer-create "*dashboard*")))
  (dashboard-setup-startup-hook))

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
(setq scroll-conservatively 101)
(setq scroll-margin 4)

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
  (setq which-key-idle-secondary-delay 0.1)
  (define-key which-key-C-h-map (kbd "<next>") 'which-key-show-next-page-cycle)
  (define-key which-key-C-h-map (kbd "<prior>") 'which-key-show-previous-page-cycle))

(provide 'core)
;;; core.el ends here
