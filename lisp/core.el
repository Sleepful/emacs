;;; core.el --- UI, quality-of-life, macOS settings -*- lexical-binding: t; -*-

;; Fix PATH for GUI Emacs on macOS (launchd strips shell PATH)
(use-package exec-path-from-shell
  :demand t
  :init
  (setq exec-path-from-shell-check-startup-files nil)
  :config
  (exec-path-from-shell-initialize))

;; Server for emacsclient (--daemon starts its own server; this is for GUI mode)
(unless (daemonp)
  (server-start))

;; Font
(set-face-attribute 'default nil
                    :family "Iosevka Nerd Font Mono"
                    :height 144
                    :weight 'light)
(setq text-scale-mode-step 1.05)

;; Revert buffer without confirmation (like :e! in vim)
(setq revert-without-query '(".*"))

;; Suppress native-comp warnings for noisy third-party packages
(with-eval-after-load 'comp
  (add-to-list 'native-comp-jit-compilation-deny-list "org-roam-")
  (add-to-list 'native-comp-jit-compilation-deny-list "evil-org"))

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
;; Frame size — pixel-based when on GUI, column fallback for daemon/terminal
(if (display-graphic-p)
    (let ((w (/ (* (display-pixel-width) 3) 7)))
      (add-to-list 'default-frame-alist (cons 'width (cons 'text-pixels w)))
      (add-to-list 'initial-frame-alist (cons 'width (cons 'text-pixels w))))
  (add-to-list 'default-frame-alist '(width . 120))
  (add-to-list 'initial-frame-alist '(width . 120)))
(add-to-list 'default-frame-alist '(fullscreen . fullheight))
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
(setq pixel-scroll-precision-momentum-seconds 0.05)
(setq pixel-scroll-precision-interpolate-page nil)
(setq scroll-conservatively most-positive-fixnum)
(setq scroll-margin 0)
(setq auto-window-vscroll nil)

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

;; Tabs (vim-tab equiv within a perspective, independent window layouts)
(tab-bar-mode 1)
(setq tab-bar-show 1)
(setq tab-bar-close-button-show nil)

;; Folding — indentation-based (outline-indent on top of outline-minor-mode)
(use-package outline-indent
  :hook (prog-mode . outline-indent-minor-mode))

(defun my-fold-level (level)
  "Fold to LEVEL indentation depth. 1 = top-level only."
  (interactive "p")
  (outline-hide-sublevels level))

(with-eval-after-load 'evil
  (dolist (n (number-sequence 1 9))
    (define-key evil-normal-state-map (kbd (format "z %d" n))
                `(lambda () (interactive) (outline-hide-sublevels ,n))))
  (define-key evil-normal-state-map (kbd "z s")
              (lambda ()
                (interactive)
                (when-let ((level (outline-level)))
                  (outline-hide-sublevels level)))))

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

;; Startup dashboard — perspectives and projects only
(use-package dashboard
  :demand t
  :init
  (setq dashboard-banner-logo-title "Emacs"
        dashboard-startup-banner 'logo
        dashboard-center-content t
        dashboard-show-shortcuts nil
        dashboard-set-heading-icons nil
        dashboard-set-file-icons nil
        dashboard-set-navigator nil
        dashboard-page-separator "\n"
        dashboard-items '((perspectives . 10) (projects . 10))
        initial-buffer-choice (lambda () (get-buffer-create dashboard-buffer-name)))
  :config
  (add-hook 'dashboard-after-initialize-hook
            (lambda ()
              (goto-char (point-min))
              (when (search-forward "Perspectives:" nil t)
                (forward-line 1)
                (beginning-of-line))))
  (defun dashboard-insert-perspectives (list-size)
    "Insert perspective list from my-persp-names (live + on-disk).
Loaded perspectives use persp-switch directly; unloaded ones (dimmed)
use my-persp-switch which loads from disk before switching."
    (require 'perspective)
    (dashboard-insert-heading "Perspectives:" nil (dashboard-heading-icon 'perspectives))
    (if-let ((persps (ignore-errors (my-persp-names))))
        (progn
          (mapc (lambda (el)
                  (let ((loaded (gethash el (perspectives-hash))))
                    (insert "\n")
                    (insert (spaces-string (or standard-indent tab-width 4)))
                    (widget-create 'item
                                   :tag (if loaded el (propertize el 'face 'shadow))
                                   :action (if loaded
                                               `(lambda (&rest _) (persp-switch ,el))
                                             (if (fboundp 'my-persp-switch)
                                                 `(lambda (&rest _) (my-persp-switch ,el))
                                               `(lambda (&rest _) (persp-switch ,el))))
                                   :button-face 'dashboard-items-face
                                   :mouse-face 'highlight
                                   :button-prefix ""
                                   :button-suffix ""
                                   :format "%[%t%]")))
                (dashboard-subseq persps list-size))
          (when-let ((sc (dashboard-get-shortcut 'perspectives)))
            (dashboard-insert-shortcut 'perspectives sc "Perspectives:")))
      (insert (propertize "\n    --- No items ---" 'face 'dashboard-no-items-face))))
  (add-to-list 'dashboard-item-generators '(perspectives . dashboard-insert-perspectives))
  (add-to-list 'dashboard-item-shortcuts '(perspectives . "s"))
  (dashboard-setup-startup-hook))

(provide 'core)
;;; core.el ends here
