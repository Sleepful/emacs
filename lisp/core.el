;;; core.el --- UI, quality-of-life, macOS settings -*- lexical-binding: t; -*-

;; Font
(set-face-attribute 'default nil
                    :family "Iosevka Nerd Font Mono"
                    :height 144
                    :weight 'light)
(setq text-scale-mode-step 1.05)

;; Themes (installed but lazy-loaded; theme-state-load handles activation)
(use-package catppuccin-theme)
(use-package ef-themes)
(use-package doom-themes)

;; Remove built-in themes from selection
(setq custom-theme-load-path
      (cl-remove-if (lambda (p)
                      (or (eq p t)
                          (and (stringp p)
                               (file-in-directory-p p data-directory))))
                    custom-theme-load-path))

;; Theme persistence
(defvar theme-state-file
  (expand-file-name "var/theme-state" user-emacs-directory))

(defun theme-state-save (&rest _)
  (let ((name (if (eq (car custom-enabled-themes) 'catppuccin)
                  (concat "catppuccin-" (symbol-name catppuccin-flavor))
                (symbol-name (or (car custom-enabled-themes) 'catppuccin)))))
    (with-temp-file theme-state-file
      (insert name))))

(defun theme-state-load ()
  (let ((choice (if (file-exists-p theme-state-file)
                    (string-trim (with-temp-buffer
                                   (insert-file-contents theme-state-file)
                                   (buffer-string)))
                  "catppuccin-frappe")))
    (mapc #'disable-theme custom-enabled-themes)
    (if (string-prefix-p "catppuccin-" choice)
        (progn
          (setq catppuccin-flavor (intern (string-remove-prefix "catppuccin-" choice)))
          (load-theme 'catppuccin t))
      (load-theme (intern choice) t))))

(advice-add 'load-theme :after #'theme-state-save)
(theme-state-load)

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



;; UI basics
(add-to-list 'default-frame-alist '(fullscreen . fullheight))
(add-hook 'emacs-startup-hook
          (lambda ()
            (set-frame-width (selected-frame)
                             (/ (display-pixel-width) 3) nil t)))
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
(setq project-list-file (expand-file-name "var/projects" user-emacs-directory))
(setq transient-history-file (expand-file-name "var/transient-history.el" user-emacs-directory))
(setq transient-levels-file (expand-file-name "var/transient-levels.el" user-emacs-directory))
(setq transient-values-file (expand-file-name "var/transient-values.el" user-emacs-directory))
(setq recentf-save-file (expand-file-name "var/recentf" user-emacs-directory))
(recentf-mode 1)
(setq recentf-max-menu-items 25)
(setq select-enable-clipboard t)
(pixel-scroll-precision-mode 1)
(setq pixel-scroll-precision-use-momentum t)
(setq scroll-conservatively 101)
(setq scroll-margin 4)

;; macOS: add essential PATH directories directly (avoids 800ms shell spawn)
(dolist (dir '("/opt/homebrew/bin"
              "/opt/homebrew/sbin"
              "/Users/jose/.asdf/shims"
              "/Users/jose/.asdf/bin"))
  (add-to-list 'exec-path dir))
(setenv "PATH" (mapconcat #'identity exec-path path-separator))

;; macOS: make Option send Meta so Alt keybinds work in GUI
(setq mac-option-modifier 'meta)
(setq mac-right-option-modifier 'none)

;; Popup showing available keybindings after a prefix
(use-package which-key
  :init (which-key-mode)
  :config
  (setq which-key-idle-delay 0.3)
  (setq which-key-idle-secondary-delay 0.1)
  (setq which-key-max-display-columns nil)
  (setq which-key-side-window-max-height 0.4)
  (define-key which-key-C-h-map (kbd "<next>") 'which-key-show-next-page-cycle)
  (define-key which-key-C-h-map (kbd "<prior>") 'which-key-show-previous-page-cycle))

(provide 'core)
;;; core.el ends here
