;;; config-project.el --- Project detection tweaks -*- lexical-binding: t; -*-

;; project-find-rules (built-in) checks for .project only at the exact
;; directory.  project-vc walks up for VCS roots.  Neither detects a
;; .project marker above the directory you are in, so project-current
;; returns nil for subdirectory files of .project-marked non-VCS roots
;; and the perspective stamper in config-roam never fires.
;;
;; This walker closes the gap.  locate-dominating-file on .project walks
;; up like project-vc.  Registered as the first project-find-functions
;; entry so it takes precedence; rules and vc remain as fallbacks.

(require 'project)

(defun my/project-find-dot-project (dir)
  "Walk upward from DIR for a .project marker.
Return (ROOT . NAME) for the marker-bearing directory, or nil."
  (let ((root (locate-dominating-file dir ".project")))
    (when root
      (cons root (file-name-nondirectory
                  (directory-file-name root))))))

(cl-defmethod project-root ((project cons))
  (car project))

(add-to-list 'project-find-functions #'my/project-find-dot-project)

(provide 'config-project)
;;; config-project.el ends here
