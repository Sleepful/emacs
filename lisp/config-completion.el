;;; config-completion.el --- Completion stack -*- lexical-binding: t; -*-

;; Forward-compatibility shims for older Emacs versions
(use-package compat
  :demand t)

;; Vertical completion UI for the minibuffer
(use-package vertico
  :demand t
  :init
  (setq vertico-sort-function nil)
  (vertico-mode)
  :bind (:map vertico-map
         ("<next>" . vertico-scroll-up)
         ("<prior>" . vertico-scroll-down)))

;; Space-separated completion matching (fuzzy, regexp, literal)
(use-package orderless
  :demand t
  :init
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles . (partial-completion))))))

;; Rich annotations in the minibuffer (docstrings, file sizes, etc.)
(use-package marginalia
  :demand t
  :init (marginalia-mode))

(require 'ansi-color)

;; Enhanced search and navigation commands (buffer switch, grep, line search)
(use-package consult
  :demand t)

(with-eval-after-load 'consult
  (setq consult-ripgrep-args
        "rg --null --line-buffered --color=never --max-columns=1000 --path-separator / --smart-case --no-heading --no-require-git --with-filename --line-number --search-zip")

  (advice-add 'consult-fd-in-dir :around
              (lambda (orig &rest args)
                (let ((consult-async-min-input 0))
                  (apply orig args))))

  ;; Perspective-aware buffer listing
  (with-eval-after-load 'perspective
    (plist-put consult-source-buffer :items
               (lambda ()
                 (consult--buffer-query
                  :sort 'visibility
                  :as #'consult--buffer-pair
                  :predicate (lambda (buf)
                               (memq buf (persp-current-buffers)))))))

  ;; Bat-based file preview (fast, like dirvish)
  (defun consult--bat-file-preview ()
    "Create preview function that uses bat for fast file preview."
    (let ((preview (consult--buffer-preview))
          (dir default-directory)
          (temp-bufs nil))
      (lambda (action cand)
        (unless (eq action 'preview)
          (mapc #'kill-buffer temp-bufs)
          (setq temp-bufs nil))
        (funcall preview action
                 (when (and cand (eq action 'preview))
                   (let* ((file (if (consp cand) (cdr cand) cand))
                          (file (expand-file-name file dir)))
                     (when (and (file-exists-p file)
                                (not (file-directory-p file)))
                       (let ((buf (generate-new-buffer " *consult-bat*")))
                         (with-current-buffer buf
                           (let ((inhibit-read-only t))
                             (condition-case nil
                                 (call-process "bat" nil t nil
                                               "--color=always" "--style=plain"
                                               "--paging=never" "--line-range=:200"
                                               file)
                               (error (insert "No preview available")))
                             (ansi-color-apply-on-region (point-min) (point-max))
                             (goto-char (point-min))
                             (setq buffer-read-only t)
                             (fundamental-mode)
                             (setq-local header-line-format
                                         (propertize file 'face 'header-line)))
                           (push buf temp-bufs)
                           buf)))))))))

  (defun consult--bat-file-state ()
    "State function for files with bat-based preview."
    (consult--state-with-return (consult--bat-file-preview) #'consult--file-action))

  (setq consult-buffer-sources
        `(consult-source-buffer
          consult-source-hidden-buffer
          consult-source-modified-buffer
          consult-source-other-buffer
          ,(plist-put (copy-tree consult-source-recent-file)
                      :state #'consult--bat-file-state)
          consult-source-buffer-register
          consult-source-file-register
          consult-source-bookmark
          consult-source-project-buffer-hidden
          ,(plist-put (copy-tree consult-source-project-recent-file-hidden)
                      :state #'consult--bat-file-state)
          consult-source-project-root-hidden))

  (setq consult-project-buffer-sources
        `(consult-source-project-buffer
          ,(plist-put (copy-tree consult-source-project-recent-file)
                      :state #'consult--bat-file-state)
          consult-source-project-root))

  (add-to-list 'consult-buffer-filter "\\`\\*scratch\\*\\( (.*)\\)?\\'")
  (add-to-list 'consult-buffer-filter "\\`\\*Messages\\*\\'"))

(defun consult-ripgrep-in-dir ()
  (interactive)
  (let* ((root (expand-file-name
                (or (when-let* ((pr (project-current))) (project-root pr))
                    default-directory)))
         (dirs (cons "." (split-string
                         (shell-command-to-string
                          (format "fd --type d --max-depth 3 --base-directory %s"
                                  (shell-quote-argument root)))
                         "\n" t)))
         (dir (completing-read "Ripgrep in: " dirs nil t)))
    (consult-ripgrep (expand-file-name dir root))))

(defun consult-fd-in-dir ()
  (interactive)
  (let* ((root (expand-file-name
                (or (when-let* ((pr (project-current))) (project-root pr))
                    default-directory)))
         (dirs (cons "." (split-string
                         (shell-command-to-string
                          (format "fd --type d --max-depth 3 --base-directory %s"
                                  (shell-quote-argument root)))
                         "\n" t)))
         (dir (completing-read "fd in: " dirs nil t))
         (d (expand-file-name dir root))
         (default-directory d)
         (fd-builder (consult--fd-make-builder (list d))))
    (find-file
     (consult--find
      (format "Fd in %s: " (abbreviate-file-name d))
      (lambda (input)
        (or (funcall fd-builder input)
            (when (string-empty-p input)
              (let ((cmd (consult--build-args consult-fd-args)))
                (cons (append cmd (list "--search-path" d))
                      #'identity)))))
      nil))))

(defun consult-recent-file-in-project ()
  (interactive)
  (let* ((pr (project-current t))
         (root (expand-file-name (project-root pr)))
         (files (seq-filter (lambda (f) (string-prefix-p root (expand-file-name f)))
                            recentf-list)))
    (find-file (consult--read files
                              :prompt "Recent project file: "
                              :sort nil
                              :require-match t
                              :category 'file))))

(provide 'config-completion)
;;; config-completion.el ends here
