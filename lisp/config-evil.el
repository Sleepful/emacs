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
  (setq evil-collection-mode-list '(magit eglot org-roam minibuffer))
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
  ;; Heading nav under ]]/[[.  Overrides evil's section-begin/end motion.
  ;; Sections duplicate paragraph motion and our outline enables finer
  ;; heading jumps via treesit predicate.  Lazy-enabled by outline-minor-mode
  ;; being turned on by the first `;s` invocation.
  ;; The custom `my/next-visible-heading' is safer than the built-in:
  ;; `outline-next-visible-heading' hangs in an infinite loop with
  ;; `treesit-outline-search' when current point sits on a heading
  ;; whose body is outline-hidden (the search re-finds the same
  ;; invisible heading without advancing point).
  (evil-global-set-key 'motion (kbd "]]") #'my/next-visible-heading)
  (evil-global-set-key 'motion (kbd "[[") #'my/previous-visible-heading)
  ;; M-]/M-[ alt-form for muscles tired of double-tapping ]]/[[.
  ;; Same motion tier as ]]/[[: no `:before' advice, no lazy outline
  ;; enablement — `SPC o' stays the only enablement path.  Shadows
  ;; `forward-page' / `backward-page'; Evil uses C-f/C-b for paging.
  (evil-global-set-key 'motion (kbd "M-]") #'my/next-visible-heading)
  (evil-global-set-key 'motion (kbd "M-[") #'my/previous-visible-heading)
  ;; evil-collection-unimpaired binds ]b/[b AND ]]/[[ in an auxiliary
  ;; normal-state keymap that outranks evil-normal-state-map.  Override
  ;; both the buffer-key case and the prefix-recurse case there.
  (when (boundp 'evil-collection-unimpaired-mode-map)
    (let* ((aux (assq 'normal-state evil-collection-unimpaired-mode-map))
           (bracket-close (assq 93 (cdr aux)))
           (bracket-open (assq 91 (cdr aux)))
           (km-close (cdr bracket-close))
           (km-open (cdr bracket-open)))
      (define-key km-close (kbd "b") 'my/persp-next-buffer)
      (define-key km-open (kbd "b") 'my/persp-prev-buffer)
      (define-key km-close (kbd "]") 'my/next-visible-heading)
      (define-key km-open (kbd "[") 'my/previous-visible-heading))))

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
