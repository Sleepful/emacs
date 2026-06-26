;;; config-roam.el --- Org-roam knowledge management -*- lexical-binding: t; -*-
;;
;; Architecture: project-aware capture via perspective stamps.
;;
;; ── Problem ──────────────────────────────────────────────────────
;; Roam notes live at ~/Sync/roam/projects/<name>/.  Opening a note
;; there sets default-directory to the roam path, which breaks
;; project-find-file and project-aware commands.  We need roam notes
;; to "belong" to the project they describe, not to the roam vault.
;;
;; ── Mechanism: per-perspective last-project-root ─────────────────
;; Every perspective carries a 'last-project-root in its local-variables
;; alist (the perspective struct's built-in key-value store):
;;
;;   my-stamp-project-root (find-file-hook)
;;     Stamps the value when any non-roam code file is opened
;;     in the perspective.  Roam files are gated by path prefix so
;;     the roam vault itself is never stamped (no recursive slug).
;;
;;   persp-switch-set-project-root (persp-switch-hook, persp-created-hook)
;;     Defined in config-tools.el.  Scans perspective buffers for a
;;     project root, stamps the value, and sets default-directory.
;;     Extended with the same roam-path guard.
;;
;; These two hooks together mean a perspective always has a project
;; by the time you'd want to capture or navigate.
;;
;; ── Capture ──────────────────────────────────────────────────────
;; my-roam-project-subdir is called via %(…) in the capture template
;; :target path.  It reads the perspective's last-project-root,
;; extracts the leaf directory name as a "slug", and returns
;; "projects/<slug>/".  The directory is created if it doesn't exist.
;;
;; Fallback: when no project is stamped (fresh empty perspective,
;; dashboard, scratch), returns "" which means org-roam-directory root.
;;
;; ── Navigation from roam notes ───────────────────────────────────
;; my-roam-set-project-dir (find-file-hook) detects when a visited
;; file lives under org-roam-directory.  If the perspective has a
;; stamped project root, it redirects default-directory there.
;; This makes ,f / project-find-file show the project's code files
;; even when the current buffer is a roam note.
;;
;; ── Edge cases ───────────────────────────────────────────────────
;;
;; Roam note opened before any code file:
;;   No stamp yet.  default-directory stays at the roam path.
;;   Fixes itself when a code file is opened in the same perspective.
;;
;; Roam note from a different project's slug:
;;   Opens normally.  Perspective's project does not switch.
;;   Next capture goes to the stamped project, not the note's slug.
;;
;; Project directory renamed:
;;   New slug produces a new "projects/<new-name>/" subdirectory.
;;   Old notes stay in the old slug's directory.  Move them manually.
;;   No stale-mapping file to corrupt.
;;
;; Roam vault becomes a git repo:
;;   Path-prefix guard in my-stamp-project-root prevents it from
;;   being stamped as a project.  No recursive "projects/roam/"
;;   subdirectory is created.
;;
;; ── Load order ───────────────────────────────────────────────────
;; config-roam.el loads before config-keybinds.el so that org-roam's
;; :commands autoloads exist when general.el binds SPC n.  The
;; find-file-hook additions are wrapped in with-eval-after-load so
;; they only register after perspective has loaded (config-tools.el).

;; ── Per-perspective value storage ────────────────────────────────
;; The perspective struct carries a `local-variables' slot (an alist).
;; These helpers read/write our key into it.

(defun my-persp-last-project-root ()
  (alist-get 'last-project-root
             (persp-local-variables
              (gethash (persp-current-name) (perspectives-hash)))))

(defun my-persp-set-last-project-root (root)
  (let* ((n (persp-current-name))
         (persp (gethash n (perspectives-hash)))
         (vars (persp-local-variables persp)))
    (setf (persp-local-variables persp)
          (cons (cons 'last-project-root root)
                (cl-remove 'last-project-root vars :key #'car)))))

(defun my-roam-project-subdir ()
  "Return roam subdirectory for current project, creating it if needed.
Uses perspective's last-project-root parameter if available.
Returns \"projects/<name>/\" or empty string for root directory."
  (let ((root (or (my-persp-last-project-root)
                  (when-let ((pr (project-current)))
                    (project-root pr)))))
    (if root
        (let* ((name (downcase (file-name-nondirectory
                                (directory-file-name (expand-file-name root)))))
               (subdir (concat "projects/" name "/"))
               (full (expand-file-name subdir org-roam-directory)))
          (unless (file-directory-p full)
            (make-directory full t))
          subdir)
      "")))

(defun my-roam-set-project-dir ()
  "Set default-directory from perspective parameter when visiting a roam file."
  (unless (bound-and-true-p my-persp-saving)
    (when (and (buffer-file-name)
               (string-prefix-p (expand-file-name org-roam-directory)
                                (expand-file-name (buffer-file-name)))
               (my-persp-last-project-root))
      (setq default-directory (my-persp-last-project-root)))))

(defun my-stamp-project-root ()
  "Stamp last-project-root on the perspective from any non-roam code file."
  (unless (bound-and-true-p my-persp-saving)
    (when-let* ((f (buffer-file-name))
                ((not (string-prefix-p org-roam-directory (expand-file-name f))))
                (pr (project-current nil (file-name-directory f)))
                (root (project-root pr)))
      (my-persp-set-last-project-root root))))

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
                    "%(my-roam-project-subdir)%<%Y%m%d%H%M%S>-${slug}.org"
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
  (add-hook 'find-file-hook #'my-stamp-project-root)
  (add-hook 'find-file-hook #'my-roam-set-project-dir))

(provide 'config-roam)
;;; config-roam.el ends here
