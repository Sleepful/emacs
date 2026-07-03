;;; config-tools.el --- Dirvish, perspective, utilities -*- lexical-binding: t; -*-

;; Use GNU ls for dired (macOS ships BSD ls which lacks --dired)
(setq insert-directory-program "gls")
(setq dired-use-ls-dired t)

;; Force dired/dirvish to start in normal mode
(with-eval-after-load 'evil
  (evil-set-initial-state 'dired-mode 'normal))

;; Enhanced dired file manager with preview and side panel
(defun dirvish-enter ()
  (interactive)
  (let ((file (dired-get-file-for-visit)))
    (cond
     ((string-suffix-p "/.." file) (dired-up-directory))
     ((file-directory-p file) (dirvish-subtree-toggle))
     (t (dired-find-file)))))

(defun dirvish-side-toggle ()
  (interactive)
  (let ((side-win (cl-find-if
                   (lambda (w)
                     (window-parameter w 'window-side))
                   (window-list))))
    (cond
     ((and side-win (eq (selected-window) side-win))
      (select-window (get-mru-window nil nil t)))
     (side-win
      (select-window side-win))
     (t
      (dirvish-side)))))

(use-package dirvish
  :demand t
  :init
  (setq dirvish-default-layout '(0 0 0.6))
  :config
  (dirvish-override-dired-mode)
  (dirvish-define-preview bat-preview (file ext)
    "Preview text files using bat for instant syntax-highlighted preview."
    (when (and (not (file-directory-p file))
               (not (member ext '("pdf" "png" "jpg" "jpeg" "gif" "bmp" "svg"
                                   "mp4" "mkv" "avi" "mov" "webm"
                                   "zip" "tar" "gz" "7z" "rar"
                                   "bin" "exe" "elc" "eln" "gpg"))))
      `(shell . ("bat" "--color=always" "--style=plain"
                 "--paging=never" "--line-range=:200" ,file))))
  (push 'bat-preview dirvish-preview-dispatchers)
  (evil-make-overriding-map dirvish-mode-map 'normal)
  (define-key dirvish-mode-map (kbd "RET") 'dired-find-file)
  (define-key dirvish-mode-map (kbd "TAB") 'dirvish-subtree-toggle)
  (define-key dirvish-mode-map (kbd "h") 'dired-up-directory)
  (define-key dirvish-mode-map (kbd "<left>") 'dired-up-directory)
  (define-key dirvish-mode-map (kbd "l") 'dirvish-enter)
  (define-key dirvish-mode-map (kbd "<right>") 'dirvish-enter)
  (define-key dirvish-mode-map (kbd "i") 'dired-toggle-read-only)
  (define-key dirvish-mode-map (kbd "g r") 'revert-buffer)
  (define-key dirvish-mode-map (kbd "j") 'dired-next-line)
  (define-key dirvish-mode-map (kbd "k") 'dired-previous-line)
  (define-key dirvish-mode-map (kbd "g g") 'evil-goto-first-line)
  (define-key dirvish-mode-map (kbd "G") 'evil-goto-line))

(defun my-reap-buffers ()
  "Kill buffers in the current perspective not visible in any window.
Skips buffers whose names start with `*' (special buffers).  Prompts
once with the count before killing."
  (interactive)
  (let* ((visible (delete-dups (mapcar #'window-buffer (window-list))))
         (buried  (cl-remove-if
                   (lambda (b)
                     (or (member b visible)
                         (string-prefix-p "*" (buffer-name b))))
                   (persp-current-buffers))))
    (if (null buried)
        (message "No buried buffers to reap.")
      (when (y-or-n-p (format "Reap %d buried buffer(s)? " (length buried)))
        (let ((n 0))
          (dolist (b buried)
            (when (kill-buffer b) (cl-incf n)))
          (message "Reaped %d buffer(s)." n))))))

(defun persp-quit-buffer ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (persp-buffer-in-other-p buf)
        (persp-remove-buffer buf)
      (kill-buffer buf))))

(defun persp-switch-set-project-root ()
  (when-let* ((buf (cl-find-if
                    (lambda (b)
                      (when-let* ((f (buffer-file-name b)))
                        (not (string-prefix-p org-roam-directory
                                              (expand-file-name f)))))
                    (cl-remove-if-not
                     (lambda (b) (memq b (persp-current-buffers)))
                     (buffer-list))))
              (file (buffer-file-name buf))
              (pr (project-current nil (file-name-directory file)))
              (root (project-root pr)))
    (setq default-directory root)
    (my-persp-set-last-project-root root)))

;; Per-project workspaces with isolated buffer lists and window layouts
(use-package perspective
  :demand t
  :init
  (setq persp-suppress-no-prefix-key-warning t)
  (setq persp-switch-to-buffer-behavior nil)
  (setq persp-state-default-file
        (expand-file-name "var/perspective-state" user-emacs-directory))
  (persp-mode)
  :config
  (add-hook 'kill-emacs-hook #'my-persp-save-all)
  (add-hook 'persp-switch-hook #'persp-switch-set-project-root)
  (add-hook 'persp-created-hook #'persp-switch-set-project-root)
  (add-hook 'persp-created-hook
            (lambda ()
              (when (get-buffer "*Messages*")
                (persp-add-buffer "*Messages*"))))

  ;; ── Per-perspective state files ────────────────────────────────
  ;;
  ;; Each perspective is saved as var/perspectives/<name>.el.
  ;; Only the active perspective is saved on switch-away (:before advice
  ;; on persp-switch).  my-persp-save-all saves all perspectives at
  ;; kill-emacs, reading struct data directly for non-current ones to
  ;; avoid context switches (which would import buffers across perspectives).
  ;; my-persp-load switches first, then opens files (suppressed eglot),
  ;; wrapped in my-persp-saving guard so the :before advice doesn't fire
  ;; during load.

  (defvar my-persp-dir
    (expand-file-name "var/perspectives" user-emacs-directory))

  (defun my-persp-file (name)
    "State file path for perspective NAME."
    (expand-file-name (concat name ".el") my-persp-dir))

  (defun my-persp-save (&optional name)
    "Save perspective NAME to var/perspectives/<name>.el.
Assumes caller is already in the target perspective (the :before
advice fires before persp-switch changes context)."
    (let* ((name (or name (persp-current-name)))
           (file (my-persp-file name))
           (persp (gethash name (perspectives-hash))))
        (when (and persp (not (persp-killed-p persp)))
          (persp-save)
          (make-directory my-persp-dir t)
          (let ((data `(persp-state
                            (buffers
                             ,(cl-loop for b in (persp-current-buffers)
                                       when (buffer-file-name b)
                                       collect (buffer-file-name b)))
                            (windows
                             ,(window-state-get (frame-root-window) t))
                            (point ,(point)))))
               (with-temp-file file
                 (prin1 data (current-buffer)))))))

  (defun my-persp-load (name)
    "Load perspective NAME from its state file into the current frame."
    (require 'eglot)
    (let ((file (my-persp-file name)))
      (when (file-exists-p file)
        (let* ((data (with-temp-buffer
                       (insert-file-contents file)
                       (read (current-buffer))))
               (buffers (cadr (assq 'buffers data)))
               (windows (cadr (assq 'windows data)))
               (point-pos (cadr (assq 'point data)))
               (eglot-server-programs nil)    ;; suppress LSP during file open
               (my-eglot-suppressed t))
          ;; Switch to perspective FIRST so files open into it
          (unless (gethash name (perspectives-hash))
            (persp-switch name))
          ;; Open files — they go into the target perspective
          (dolist (f buffers)
            (when (file-exists-p f)
              (find-file f)))
          ;; Ensure all opened buffers are in the perspective
          (dolist (b buffers)
            (when-let* ((buf (get-file-buffer b)))
              (unless (persp-is-current-buffer buf)
                (persp-add-buffer buf))))
          ;; Restore window layout
          (when windows
            (ignore-errors
              (window-state-put windows (frame-root-window) 'safe)))
          ;; Restore point
          (ignore-errors
            (goto-char point-pos))
          ;; Start eglot now that suppression has lifted
          (let ((eglot-server-programs (default-value 'eglot-server-programs)))
            (dolist (b buffers)
              (when-let* ((buf (get-file-buffer b)))
                (with-current-buffer buf
                  (eglot-ensure)))))))
    t)))

  (defun my-persp-save-all ()
    "Save all live perspectives to their per-perspective files."
    (dolist (name (hash-table-keys (perspectives-hash)))
      (if (equal name (persp-current-name))
          (ignore-errors (my-persp-save name))
        (let* ((persp (gethash name (perspectives-hash)))
               (file (my-persp-file name)))
          (when (and persp (not (persp-killed-p persp)))
            (make-directory my-persp-dir t)
            (let* ((buffers (cl-loop for b in (persp-buffers persp)
                                     when (and (buffer-live-p b)
                                               (buffer-file-name b))
                                     collect (buffer-file-name b)))
                   (point (when-let* ((m (persp-point-marker persp)))
                            (and (marker-position m)
                                 (marker-position m))))
                   (data `(persp-state (buffers ,buffers)
                           (windows nil)    ;; non-current: can't serialize
                           (point ,point))))
              (with-temp-file file
                (prin1 data (current-buffer)))))))))

  (defun my-persp-names ()
    "Return all known perspective names (live + on-disk)."
    (delete-dups
     (append (hash-table-keys (perspectives-hash))
             (when (file-directory-p my-persp-dir)
               (mapcar (lambda (f) (file-name-base f))
                       (directory-files my-persp-dir nil "\\.el\\'"))))))

  (defun my-persp-loaded-p (name)
    "Return t if perspective NAME is currently loaded."
    (and (gethash name (perspectives-hash)) t))

  (defun my-persp-switch (name)
    "Switch to perspective NAME, loading from disk if not yet loaded."
    (interactive
     (list (completing-read "Perspective: " (my-persp-names) nil nil)))
    (unless (my-persp-loaded-p name)
      (message "Loading perspective %s..." name)
      (let ((my-persp-saving t))
        (my-persp-load name)))
    (persp-switch name))

  ;; Save outgoing perspective BEFORE switch (hook fires after, too late)
  (defvar my-persp-saving nil)
  (advice-add 'persp-switch :before
              (lambda (name &rest _)
                (unless my-persp-saving
                  (when-let* ((old-name (persp-current-name)))
                    (unless (equal old-name name)
                      (let ((my-persp-saving t))
                        (ignore-errors (my-persp-save old-name))))))))

  ;; Delete state file when perspective is killed
  (add-hook 'persp-killed-hook
            (lambda ()
              (ignore-errors
                (delete-file (my-persp-file (persp-current-name))))))

  ;; ── Daemon: strip terminal frame hash ──────────────────────────

  (add-hook 'after-init-hook
            (lambda ()
              (dolist (frame (frame-list))
                (unless (display-graphic-p frame)
                  (set-frame-parameter frame 'persp--hash nil)
                  (set-frame-parameter frame 'persp--curr nil)))))

;; Git interface

;; Git interface
(use-package magit
  :config
  (transient-append-suffix 'magit-rebase "-d"
    '("-D" "Regenerate author date" "--ignore-date")))

(use-package magit-delta
  :after magit
  :hook (magit-mode . magit-delta-mode)
  :config
  (setq magit-delta-delta-args
        `("--max-line-distance" "0.6"
          "--true-color" ,(if xterm-color--support-truecolor "always" "never")
          "--color-only"
          "--no-gitconfig"
          "--navigate")))

;; One-shot restart: kills daemon, starts new one, opens Emacs Client.app
(defun my-restart-emacs ()
  "Restart the Emacs daemon and reconnect in one action."
  (interactive)
  (my-persp-save-all)     ;; save before server-force-delete destroys client frames
  (let ((name server-name)
        (bin (expand-file-name invocation-name invocation-directory)))
    (call-process "sh" nil 0 nil "-c"
                  (format "nohup sh -c 'sleep 1 && %s --daemon=%s && sleep 1 && emacsclient -c -n' >/dev/null 2>&1 &"
                          (shell-quote-argument bin)
                          (shell-quote-argument name))))
  (server-force-delete)
  (kill-emacs))

(defun my-copy-file-name ()
  "Copy the current buffer's file path to the kill ring."
  (interactive)
  (if-let* ((f (buffer-file-name)))
      (progn (kill-new f)
             (message "Copied: %s" f))
    (message "No file for this buffer")))

(provide 'config-tools)
;;; config-tools.el ends here
