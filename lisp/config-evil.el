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
  (evil-global-set-key 'motion (kbd "]b") #'my/persp-next-buffer)
  (evil-global-set-key 'motion (kbd "[b") #'my/persp-prev-buffer)
  ;; evil-collection-unimpaired binds ]b/[b in an auxiliary normal-state
  ;; keymap that outranks evil-normal-state-map.  Remove them there.
  (when (boundp 'evil-collection-unimpaired-mode-map)
    (let* ((aux (assq 'normal-state evil-collection-unimpaired-mode-map))
           (bracket-close (assq 93 (cdr aux)))
           (bracket-open (assq 91 (cdr aux)))
           (km-close (cdr bracket-close))
           (km-open (cdr bracket-open)))
      (define-key km-close (kbd "b") 'my/persp-next-buffer)
      (define-key km-open (kbd "b") 'my/persp-prev-buffer))))

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
