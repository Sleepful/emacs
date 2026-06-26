;;; config-evil.el --- Evil mode setup -*- lexical-binding: t; -*-

;; Vim emulation layer
(use-package evil
  :demand t
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-Y-yank-to-eol t)
  (setq evil-undo-system 'undo-redo)
  :config
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-mode 1))

;; Evil-collection for magit only (j/k line movement + curated keybinds)
;; Reference: https://github.com/emacs-evil/evil-collection/tree/master/modes/magit
(use-package evil-collection
  :after evil
  :demand t
  :init
  (setq evil-collection-mode-list '(magit eglot org-roam))
  :config
  (evil-collection-init)
  ;; Swap section vs sibling nav: [/] for section, C-j/C-k for sibling
  (add-hook 'evil-collection-setup-hook
            (lambda (mode _mode-keymaps)
              (when (eq mode 'magit)
                (define-key magit-mode-map "[" #'magit-section-backward)
                (define-key magit-mode-map "]" #'magit-section-forward)
                (define-key magit-mode-map (kbd "C-j") #'magit-section-backward-sibling)
                (define-key magit-mode-map (kbd "C-k") #'magit-section-forward-sibling)))))

(global-set-key (kbd "s-<backspace>") (lambda () (interactive) (kill-line 0)))
(global-set-key (kbd "C-<tab>") 'tab-next)
(global-set-key (kbd "C-<S-iso-lefttab>") 'tab-previous)

(with-eval-after-load 'evil
  ;; Escape to normal in minibuffers
  (dolist (map '(minibuffer-local-map
                  minibuffer-local-ns-map
                  minibuffer-local-completion-map
                  minibuffer-local-must-match-map
                  minibuffer-local-isearch-map))
    (define-key (symbol-value map) (kbd "<escape>") 'evil-normal-state)))

(provide 'config-evil)
;;; config-evil.el ends here
