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
  (if-let* ((name (persp-current-name)))
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
                         (when-let* ((pr (project-current nil (file-name-directory f))))
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
  (evil-org-set-key-theme '(textobjects insert navigation additional shift todo heading))
  (evil-define-key '(normal visual motion) org-mode-map
    "]]" 'org-next-visible-heading
    "[[" 'org-previous-visible-heading)

  ;;; org-paste-subtree prefix semantics.  Calling
  ;;; (org-paste-subtree N) from Lisp passes N as the level arg,
  ;;; which `prefix-numeric-value' reads as a forced depth — not
  ;;; the same as the C-u interactive prefix.  To produce the
  ;;; documented "paste after at same level" we set
  ;;; current-prefix-arg before call-interactively.  Source: org.el.
  (defun my/org-paste-subtree-after ()
    "Paste most-recent subtree after the current heading at the same level.
Forces the C-u prefix that org-paste-subtree reads for the after direction."
    (interactive)
    (let ((current-prefix-arg '(4)))
      (call-interactively #'org-paste-subtree)))

  (defun my/org-paste-subtree-before ()
    "Paste most-recent subtree before the current heading.
Cursor must sit at the heading start; org-paste-subtree only pastes
before when point is at the heading start."
    (interactive)
    (org-paste-subtree))

  ;; Local leader.  Only active in org-mode buffers; outside org,
  ;; which-key shows nothing for "-" and the dash prefix is inert.
  ;;
  ;; Surface the most common org operations under one prefix so the
  ;; user can discover them via which-key instead of memorizing
  ;; C-c C-... mnemonics.  The leading - prefix means Evil motion
  ;; letters that double as bindings here (a, c, p, s, etc.) are
  ;; only shadowed by these keys; pressing them directly without
  ;; the prefix still behaves as Evil expects.
  ;;
  ;; Default is lowercase.  Two uppercase exceptions:
  ;;   P  paste-before, kept uppercase to mirror vim's p/P pairing.
  ;;   A  archive subtree — `a` is taken by agenda and no clean
  ;;      lowercase slot remains (x: cut, s: schedule, d: deadline).
  ;;
  ;; Mnemonic notes:
  ;;   < / > mirror vim's << / >> indent: < shallower (promote),
  ;;   > deeper (demote).  [ ] are bracket-marker jumps.  { } are
  ;;   fold open / close.  * is the literal star org-toggle-heading
  ;;   adds/removes.  x/y/p follow vim: x cut, y yank (copy),
  ;;   p / P paste after / before.
  (major-mode-leader
    :keymaps 'org-mode-map

    ;; Structure & outline ---------------------
    "*" '(org-toggle-heading              :wk "toggle heading/list")
    "<" '(org-promote-subtree             :wk "promote")
    ">" '(org-demote-subtree              :wk "demote")
    "[" '(org-previous-visible-heading    :wk "prev heading")
    "]" '(org-next-visible-heading        :wk "next heading")
    "{" '(outline-hide-subtree            :wk "hide subtree")
    "}" '(outline-show-subtree            :wk "show subtree")

    ;; TODO & state ----------------------------
    "t" '(org-todo                        :wk "todo state")          ;; C-c C-t

    ;; Refile & move ---------------------------
    "w" '(org-refile                      :wk "refile")              ;; C-c C-w

    ;; Dates & timestamps ----------------------
    "." '(org-time-stamp                  :wk "timestamp")          ;; C-c .
    "!" '(org-time-stamp-inactive         :wk "timestamp inactive")  ;; C-c !
    "s" '(org-schedule                    :wk "schedule")            ;; C-c C-s
    "d" '(org-deadline                    :wk "deadline")            ;; C-c C-d

    ;; Links -----------------------------------
    "o" '(org-open-at-point               :wk "follow link/open")    ;; C-c C-o
    "l" '(org-store-link                  :wk "store link")          ;; C-c C-l

    ;; Tags & filter ---------------------------
    "q" '(org-set-tags-command            :wk "set tags")            ;; C-c C-q
    "/" '(org-sparse-tree                 :wk "sparse tree")         ;; C-c /
    "r" '(org-reveal                      :wk "reveal")              ;; C-c C-r

    ;; Capture & agenda ------------------------
    "c" '(org-capture                     :wk "capture")             ;; C-c c
    "a" '(org-agenda                      :wk "agenda")              ;; C-c a

    ;; Export ----------------------------------
    "e" '(org-export-dispatch             :wk "export")              ;; C-c C-e

    ;; Subtree clipboard -----------------------
    ;; x cut, y yank (copy), p / P paste after / before — vim trio.
    "x" '(org-cut-subtree                 :wk "cut subtree")         ;; C-c C-x C-w
    "y" '(org-copy-subtree                :wk "copy subtree")        ;; C-c C-x M-w
    "p" '(my/org-paste-subtree-after      :wk "paste subtree after") ;; C-u + C-c C-x C-y
    "P" '(my/org-paste-subtree-before     :wk "paste subtree before");; C-c C-x C-y at heading start

    ;; Archive ---------------------------------
    "A" '(org-archive-subtree             :wk "archive subtree")     ;; C-c C-x C-a

    ;; Visibility ------------------------------
    "TAB" '(org-cycle                     :wk "cycle visibility")))

(with-eval-after-load 'perspective
  (add-hook 'find-file-hook #'my-stamp-project-root))

;; Strip every `ol-*' link module from `org-modules'.  Default value
;; ships with `ol-doi ol-w3m ol-bbdb ol-bibtex ol-docview ol-gnus
;; ol-info ol-irc ol-mhe ol-rmail ol-eww' and `org-load-modules-maybe'
;; (called from `org-mode') does a hard `(require EXT)' per entry on
;; every .org buffer activation.  Each EXT pulls in a parent module
;; (gnus, w3m, eww, …) that is not installed on this config, surfacing
;; `Problems while trying to load feature `ol-XXX'' messages.
;; `org-link-frame-setup' (cons cell with `gnus' etc.) is left intact —
;; this only affects the autoloaded link modules.  The relevant
;; defcustom lives inside `org.el', so we cannot `setq' before org
;; loads.
(with-eval-after-load 'org
  (setq org-modules
        (cl-remove-if (lambda (s) (string-prefix-p "ol-" (symbol-name s)))
                      org-modules)))

(provide 'config-roam)
;;; config-roam.el ends here
