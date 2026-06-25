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

(defun persp-quit-buffer ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (persp-buffer-in-other-p buf)
        (persp-remove-buffer buf)
      (kill-buffer buf))))

(defun persp-switch-set-project-root ()
  (when-let* ((buf (cl-find-if #'buffer-file-name (persp-current-buffers)))
              (file (buffer-file-name buf))
              (pr (project-current nil (file-name-directory file))))
    (setq default-directory (project-root pr))))

;; Per-project workspaces with isolated buffer lists and window layouts
(use-package perspective
  :demand t
  :init
  (setq persp-suppress-no-prefix-key-warning t)
  (setq persp-state-default-file
        (expand-file-name "var/perspective-state" user-emacs-directory))
  (persp-mode)
  :config
  (add-hook 'kill-emacs-hook #'persp-state-save)
  (add-hook 'persp-switch-hook #'persp-switch-set-project-root)
  (add-hook 'persp-created-hook
            (lambda ()
              (when (get-buffer "*Messages*")
                (persp-add-buffer "*Messages*"))))

  ;; Strip non-GUI frame hashes before anything touches them
  (add-hook 'after-init-hook
            (lambda ()
              (dolist (frame (frame-list))
                (unless (display-graphic-p frame)
                  (set-frame-parameter frame 'persp--hash nil)
                  (set-frame-parameter frame 'persp--curr nil)))))

  ;; Load state when GUI frame exists (selected-frame is the client frame)
  (defvar my-persp-state-loaded nil)
  (add-hook 'server-after-make-frame-hook
            (lambda ()
              (when (and (display-graphic-p) (not my-persp-state-loaded))
                (setq my-persp-state-loaded t)
                ;; Suppress eglot during state load — avoids LSP startup per file
                (let ((eglot-server-programs nil)
                      (my-eglot-suppressed t))
                  (when (file-exists-p persp-state-default-file)
                    (ignore-errors
                      (persp-state-load persp-state-default-file)
                      (persp-switch "main")))
                  (dolist (name (hash-table-keys (perspectives-hash)))
                    (when (string-match-p "\\`[0-9a-f]\\{8\\}\\'" name)
                      (ignore-errors (persp-kill name))))
                  (when (fboundp 'dashboard-insert-startupify-lists)
                    (dashboard-insert-startupify-lists t)
                    (when (get-buffer dashboard-buffer-name)
                      (with-current-buffer dashboard-buffer-name
                        (goto-char (point-min))
                        (when (search-forward "Perspectives:" nil t)
                          (forward-line 1)
                          (beginning-of-line)))))))))
)

;; Git interface

;; Git interface
(use-package magit
  :config
  (transient-append-suffix 'magit-rebase "-d"
    '("-D" "Regenerate author date" "--ignore-date")))

(use-package magit-delta
  :after magit
  :hook (magit-mode . magit-delta-mode))

;; One-shot restart: kills daemon, starts new one, opens Emacs Client.app
(defun my-restart-emacs ()
  "Restart the Emacs daemon and reconnect in one action."
  (interactive)
  (persp-state-save)     ;; save before server-force-delete destroys client frames
  (let ((name server-name)
        (bin (expand-file-name invocation-name invocation-directory)))
    (call-process "sh" nil 0 nil "-c"
                  (format "nohup sh -c 'sleep 1 && %s --daemon=%s && sleep 1 && emacsclient -c -n' >/dev/null 2>&1 &"
                          (shell-quote-argument bin)
                          (shell-quote-argument name))))
  (server-force-delete)
  (kill-emacs))

(provide 'config-tools)
;;; config-tools.el ends here
