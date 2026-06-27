;;; config-roam.el --- Org-roam knowledge management -*- lexical-binding: t; -*-
;;
;; Architecture: perspective-aware capture + navigate.
;;
;; ── Problem ──────────────────────────────────────────────────────
;; Roam notes live at ~/Sync/roam/perspectives/<name>/.  default-directory
;; points there, so project-find-file can't find the code project.
;;
;; ── Solution ─────────────────────────────────────────────────────
;; Stamp the project root in a plain hash table keyed by perspective
;; name.  my-persp-project-find-file (bound to ,f and SPC p f) reads
;; the stamp and sets default-directory before delegating to
;; project-find-file.  No advice, no struct manipulation, no recursion.
;;
;; ── Capture routing ──────────────────────────────────────────────
;; my-roam-project-subdir resolves to "perspectives/<persp-name>/" by
;; reading the current perspective name directly.  No project root
;; extraction, no leaf-name collision.
;;
;; ── Project root stamping ────────────────────────────────────────
;; my-stamp-project-root (find-file-hook) stamps on any non-roam file
;; open.  persp-switch-set-project-root (config-tools.el) stamps on
;; perspective switch and creation.  Both gate on path prefix to
;; prevent the roam vault from being stamped.

;; ── Per-perspective project root storage ─────────────────────────
;; A plain hash table keyed by perspective name.  Avoids the setf /
;; nconc / native-comp minefield with the perspective struct's
;; local-variables alist.  Lost on daemon restart (same as the struct
;; approach — we don't persist this in state files).

(defvar my-persp-project-roots (make-hash-table :test 'equal))

(defun my-persp-last-project-root ()
  (gethash (persp-current-name) my-persp-project-roots))

(defun my-persp-set-last-project-root (root)
  (puthash (persp-current-name) root my-persp-project-roots))

(defun my-roam-project-subdir ()
  "Return roam subdirectory for current perspective, creating it if needed.
Uses perspective name as the slug — no collision risk because names are
user-controlled.  Returns \"perspectives/<name>/\" or empty string for
root directory (when no perspective is active, e.g. scratch buffer)."
  (if-let ((name (persp-current-name)))
      (let* ((slug (downcase name))
             (subdir (concat "perspectives/" slug "/"))
             (full (expand-file-name subdir org-roam-directory)))
        (unless (file-directory-p full)
          (make-directory full t))
        subdir)
    ""))

(defun my-stamp-project-root ()
  "Stamp last-project-root on the perspective when a non-roam file opens."
  (unless (bound-and-true-p my-persp-saving)
    (when-let* ((f (buffer-file-name))
                ((not (string-prefix-p org-roam-directory (expand-file-name f))))
                (pr (project-current nil (file-name-directory f)))
                (root (project-root pr)))
      (my-persp-set-last-project-root root))))

(defun my-persp-project-find-file ()
  "project-find-file with perspective-aware fallback.
Checks the current buffer's project first (unless it's a roam file),
then the stamped hash table, then scans buffers in MRU order."
  (interactive)
  (let* ((f (buffer-file-name))
         (current-root (when (and f (not (string-prefix-p org-roam-directory
                                                          (expand-file-name f))))
                         (when-let ((pr (project-current nil (file-name-directory f))))
                           (project-root pr))))
         (root (or current-root
                   (my-persp-last-project-root)
                   (cl-loop for b in (buffer-list)
                            when (and (memq b (persp-current-buffers))
                                      (buffer-file-name b)
                                      (not (string-prefix-p
                                            org-roam-directory
                                            (expand-file-name (buffer-file-name b)))))
                            for pr = (project-current nil
                                       (file-name-directory (buffer-file-name b)))
                            when pr
                            return (project-root pr))))
         (default-directory (or root default-directory)))
    (when root
      (my-persp-set-last-project-root root))
    (call-interactively #'project-find-file)))

(use-package org-roam
  :commands (org-roam-node-find
             org-roam-node-insert
             org-roam-capture
             org-roam-tag-add
             org-roam-buffer-toggle
             org-roam-graph)
  :init
  (setq org-roam-directory (expand-file-name "~/Sync/roam/"))
  (make-directory org-roam-directory t)
  (setq org-id-locations-file (expand-file-name ".org-id-locations" org-roam-directory))
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head
                    "%(my-roam-project-subdir)${slug}.org"
                    "#+title: ${title}\n")
           :unnarrowed t)))
  :config
  (org-roam-db-autosync-mode))

(use-package evil-org
  :after org
  :commands evil-org-mode
  :init
  (add-hook 'org-mode-hook 'evil-org-mode)
  :config
  (evil-org-set-key-theme '(textobjects insert navigation additional shift todo heading)))

(with-eval-after-load 'perspective
  (add-hook 'find-file-hook #'my-stamp-project-root))

(provide 'config-roam)
;;; config-roam.el ends here
