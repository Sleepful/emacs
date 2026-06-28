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
  (evil-mode 1)
  (with-current-buffer "*Messages*"
    (evil-normal-state 1)))

;; Evil-collection for magit only (j/k line movement + curated keybinds)
;; Reference: https://github.com/emacs-evil/evil-collection/tree/master/modes/magit
(use-package evil-collection
  :after evil
  :demand t
  :init
  (setq evil-collection-mode-list '(magit eglot org-roam))
  :config
  (evil-collection-init))

(add-hook 'magit-mode-hook
          (defun my-magit-section-keys ()
            (evil-local-set-key 'normal (kbd "[") 'magit-section-backward)
            (evil-local-set-key 'normal (kbd "]") 'magit-section-forward)
            (evil-local-set-key 'normal (kbd "{") 'magit-section-backward-sibling)
            (evil-local-set-key 'normal (kbd "}") 'magit-section-forward-sibling)
            (evil-local-set-key 'motion (kbd "[") 'magit-section-backward)
            (evil-local-set-key 'motion (kbd "]") 'magit-section-forward)
            (evil-local-set-key 'motion (kbd "{") 'magit-section-backward-sibling)
            (evil-local-set-key 'motion (kbd "}") 'magit-section-forward-sibling)
            (evil-local-set-key 'visual (kbd "{") 'magit-section-backward-sibling)
            (evil-local-set-key 'visual (kbd "}") 'magit-section-forward-sibling)))

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
