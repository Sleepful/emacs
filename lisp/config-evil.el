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
  (evil-mode 1))

(define-key evil-insert-state-map (kbd "s-<backspace>")
  (lambda () (interactive) (kill-line 0)))

(with-eval-after-load 'evil
  (dolist (map '(minibuffer-local-map
                  minibuffer-local-ns-map
                  minibuffer-local-completion-map
                  minibuffer-local-must-match-map
                  minibuffer-local-isearch-map))
    (define-key (symbol-value map) (kbd "<escape>") 'evil-normal-state)))

(provide 'config-evil)
;;; config-evil.el ends here
