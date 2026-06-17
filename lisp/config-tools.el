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
  (add-hook 'emacs-startup-hook
            (lambda ()
              (when (file-exists-p persp-state-default-file)
                (persp-state-load persp-state-default-file)
                (persp-switch "main")))))

;; Git interface
(use-package magit
  :config
  (transient-append-suffix 'magit-rebase "-d"
    '("-D" "Regenerate author date" "--ignore-date")))

;; M-x restart-emacs
(use-package restart-emacs)

(provide 'config-tools)
;;; config-tools.el ends here
