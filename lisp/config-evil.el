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
  (setq evil-want-minibuffer t)
  (setq evil-collection-setup-minibuffer t)
  :config
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-mode 1)
  (when (get-buffer "*Messages*")
    (with-current-buffer "*Messages*"
      (evil-normal-state 1)))
  (add-hook 'messages-buffer-mode-hook #'evil-normal-state))

;; Evil-collection for magit only (j/k line movement + curated keybinds)
;; Reference: https://github.com/emacs-evil/evil-collection/tree/master/modes/magit
(use-package evil-collection
  :after evil
  :demand t
  :init
  (setq evil-collection-mode-list '(magit eglot org-roam minibuffer)
        evil-collection-want-unimpaired-p nil
        evil-collection-binding-overrides '((lookup-doc :enabled nil)))
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

(defun my--persp-buffers ()
  "Return file-backed buffers in the current perspective."
  (cl-remove-if-not
   (lambda (buf) (and (buffer-live-p buf) (buffer-file-name buf)))
   (persp-current-buffers)))

(defun my/persp-next-buffer ()
  "Switch to the next buffer in the current perspective, skipping scratch."
  (interactive)
  (let ((bufs (my--persp-buffers))
        (cur (current-buffer)))
    (when (> (length bufs) 1)
      (let* ((tail (memq cur bufs))
             (rest (cdr tail))
             (next (car (or rest bufs))))
        (when (and next (not (eq next cur)))
          (switch-to-buffer next))))))

(defun my/persp-prev-buffer ()
  "Switch to the previous buffer in the current perspective, skipping scratch."
  (interactive)
  (let* ((bufs (my--persp-buffers))
         (rev (reverse bufs))
         (cur (current-buffer)))
    (when (> (length rev) 1)
      (let* ((tail (memq cur rev))
             (rest (cdr tail))
             (prev (car (or rest rev))))
        (when (and prev (not (eq prev cur)))
          (switch-to-buffer prev))))))

(with-eval-after-load 'evil
  (dolist (state '(normal motion))
    (evil-global-set-key state (kbd "[") #'my/previous-visible-heading)
    (evil-global-set-key state (kbd "]") #'my/next-visible-heading)
    (evil-global-set-key state (kbd "M-]") #'my/persp-next-buffer)
    (evil-global-set-key state (kbd "M-[") #'my/persp-prev-buffer)
    (evil-global-set-key state (kbd "K") #'my/eldoc-pop)))

(with-eval-after-load 'evil
  ;; Minibuffer: enter insert state on activation, ESC then leaves to normal.
  ;; The minibuffer has no major mode, so `evil-set-initial-state' won't work
  ;; here (see `elpa/evil-collection-20260624.327/modes/minibuffer/evil-collection-minibuffer.el:47-48').
  ;; We hook directly into `minibuffer-setup-hook' so the state is locked the
  ;; moment the minibuffer is created, regardless of which command opened it
  ;; (M-x, consult, evil-ex).  Evil's built-in ESC binding on
  ;; `evil-insert-state-map' fires `evil-normal-state' on the first ESC, then
  ;; a second ESC aborts via `evil-esc's default tag (`abort-recursive-edit').
  (add-hook 'minibuffer-setup-hook
            (lambda ()
              (setq-local evil-default-state 'insert)
              (unless (and (boundp 'evil-local-mode) evil-local-mode)
                (evil-local-mode 1))
              (evil-insert-state 1))))

(provide 'config-evil)
;;; config-evil.el ends here
