;;; config-lang.el --- Language support (tree-sitter, LSP) -*- lexical-binding: t; -*-

;; Auto-install tree-sitter grammars and remap to ts-modes
(use-package treesit-auto
  :demand t
  :config
  (setq treesit-auto-install t)
  (global-treesit-auto-mode))

;; TypeScript
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))

;; Markdown with tree-sitter highlighting (Emacs 32 ships markdown-ts-mode).
(use-package markdown-mode)
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-ts-mode))
(add-to-list 'treesit-language-source-alist
             '(markdown "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
                        "main" "src" nil))

(defun my/ts-imenu-name (node)
  "Return the imenu name for a TypeScript declaration NODE."
  (let ((name-node
         (pcase (treesit-node-type node)
           ("variable_declaration"
            (treesit-node-child-by-field-name
             (treesit-search-subtree node "variable_declarator" nil nil 1)
             "name"))
           ("lexical_declaration"
            (treesit-node-child-by-field-name
             (treesit-search-subtree node "variable_declarator" nil nil 1)
             "name"))
           (_ (treesit-node-child-by-field-name node "name")))))
    (if name-node
        (treesit-node-text name-node t)
      (my/treesit-node-anon-text node))))

(defun my/ts-valid-imenu-entry (node)
  "Return non-nil if NODE should appear in imenu.
Only top-level declarations (accepts export-wrapped)."
  (pcase (treesit-node-type node)
    ((or "lexical_declaration" "variable_declaration")
     (let ((p (treesit-node-parent node)))
       (or (treesit-node-eq p (treesit-buffer-root-node))
           (treesit-node-eq (treesit-node-parent p) (treesit-buffer-root-node)))))
    (_ t)))

(defface my/ts-imenu-type-face
  '((t :inherit font-lock-type-face))
  "Face for imenu type annotations in TypeScript.")

(defun my/ts-imenu-name-with-type (node)
  "Return an imenu name with colored type annotation for NODE."
  (let ((name (my/ts-imenu-name node))
        (type (my/treesit-type-short (treesit-node-type node))))
    (concat (propertize (format "%-6s " (concat "(" type ")"))
                        'face 'my/ts-imenu-type-face)
            name)))

(defun my/ts-node-depth (node)
  "Return the nesting depth of NODE (root = 0)."
  (let ((depth 0))
    (while (setq node (treesit-node-parent node))
      (cl-incf depth))
    depth))

(defun my/ts-imenu-extend ()
  "Replace imenu settings with a flat file-order index.
All declaration types in a single merged category with type prefixes.
Fixes export-wrapped top-level detection and file-order display.
Forces tree-sitter imenu even when eglot is active (LSP symbols are too granular).
Also enables outline-minor-mode via treesit outline predicate."
  (setq-local imenu-sort-function nil)
  (setq-local imenu-create-index-function #'treesit-simple-imenu)
  (setq-local treesit-simple-imenu-settings
              `((""
                 ,(rx bol (or "function_declaration" "lexical_declaration"
                              "class_declaration" "method_definition"
                              "interface_declaration" "type_alias_declaration"
                              "enum_declaration" "variable_declaration")
                     eol)
                 my/ts-valid-imenu-entry
                 my/ts-imenu-name-with-type)))
  ;; Enable outline navigation via tree-sitter.  treesit-major-mode-setup
  ;; sets `treesit-outline-predicate' from the imenu settings defined above.
  ;; We explicitly set the search/level so `outline-hide-body' works.
  (when (fboundp 'treesit-outline-search)
    (setq-local outline-search-function #'treesit-outline-search))
  (when (fboundp 'treesit-outline-level)
    (setq-local outline-level #'treesit-outline-level)))

(add-hook 'typescript-ts-base-mode-hook #'my/ts-imenu-extend)

;; ── Interactive symbol explorer ──────────────────────────────────
;; ; s: drill-down symbol explorer.  RET jumps, C-RET drills into a
;; node's children, ESC/empty pops scope up.  Scope stack stored in
;; my/structural-scope (buffer-local).

(defvar-local my/structural-scope nil
  "Node for the current drill-down scope.  nil = file level.")

(defvar-local my/structural-scope-stack nil
  "Stack of previous scopes for drill-down pop.  nil = at file level.")

(defvar-local my/structural--highlighted-node nil
  "Currently highlighted candidate in ;s, used for preview folding.")

(defvar-local my/structural--saved-point nil
  "Point position at ;s entry, restored on abort.")

(defvar my/structural-focus-action nil)

(defvar my/structural-passthrough-types
  '("export_statement" "statement_block" "class_body"
    "else_clause" "finally_clause" "switch_case" "case_clause")
  "Tree-sitter container node types whose children replace the container.
Avoids empty drill-down levels when entering functions, classes, etc.")

(defface my/structural-drillable-face
  '((t :foreground "#56B6C2" :weight bold))
  "Face for the drill-down indicator on candidates with children.")

(defun my/structural-jump (pos)
  "Jump to POS, push mark, and center the cursor."
  (push-mark)
  (goto-char pos)
  (when (fboundp 'evil-scroll-line-to-center)
    (evil-scroll-line-to-center nil)))

(defun my/structural--outline-ensure ()
  "Enable outline-minor-mode buffer-locally.  Idempotent."
  (unless outline-minor-mode
    (outline-minor-mode 1)))

(defun my/structural--breadcrumb ()
  "Update header-line-format with the current scope stack path."
  (condition-case nil
      (let* ((all-nodes (delq nil (append (reverse my/structural-scope-stack)
                                          (when my/structural-scope
                                            (list my/structural-scope)))))
             (paths (mapcar (lambda (n)
                             (concat (propertize "["
                                                 'face 'my/ts-imenu-type-face)
                                     (propertize (my/treesit-type-short
                                                  (treesit-node-type n))
                                                 'face 'my/ts-imenu-type-face)
                                     (propertize "] "
                                                 'face 'my/ts-imenu-type-face)
                                     (condition-case nil
                                         (my/ts-imenu-name n)
                                       (error "?"))))
                           all-nodes)))
        (setq header-line-format
              (when paths
                (concat (propertize " ;s > " 'face 'shadow)
                        (mapconcat #'identity paths
                                   (propertize " > " 'face 'shadow))))))
    (error (setq header-line-format nil))))

(defun my/structural--cleanup (&optional restore-point)
  "Reset ;s session state.
With RESTORE-POINT, restore the saved point (abort path).
Always runs outline-show-all and clears the breadcrumb.
outline-minor-mode is preserved (becomes persistent for travel)."
  (when (fboundp 'outline-show-all)
    (ignore-errors (outline-show-all)))
  (setq header-line-format nil)
  (setq my/structural--highlighted-node nil)
  (when (and restore-point my/structural--saved-point)
    (goto-char my/structural--saved-point))
  (setq my/structural--saved-point nil))

(defun my/structural--goto-node-start (node)
  "Move point to NODE's first line."
  (when node
    (goto-char (treesit-node-start node))
    (beginning-of-line)))

(defun my/next-visible-heading (arg)
  "Move to next visible heading line.
ARG positive walks forward; negative walks backward.

Safe replacement for `outline-next-visible-heading': the built-in loops
with `treesit-outline-search' when current point is on a heading whose
body is hidden by outline folding (the search re-finds the same
invisible heading without advancing).

Frame-of-reference: one outer call = one outline heading step.  When
the search lands on a heading with the body hidden, we forward-line
past it and try the next one.  Edge-of-buffer symmetric: pressing n
past the last visible heading drops to plain `(point-max)' (no
heading selected), and pressing p at first visible heading drops to
plain `(point-min)'.  From a plain edge, the opposite direction
walks back into the nearest visible heading.

Inner-step quirk: `treesit-outline-search' treats the *current* node
as `found' when stepping toward its own boundary.  When stepping
backward from a heading line, the search may return the heading's
own beginning -- same line, different column.  We treat this as no
movement and back up one line so the next iteration sees a position
strictly outside the heading's body.  No loops in the recovery path."
  (interactive "p")
  (let* ((arg (or arg 1))
         (step (if (< arg 0) -1 1))
         (count (abs arg))
         (max-iter 10000))
    (dotimes (_ count)
      (let ((start-pos (point))
            (start-line (line-number-at-pos))
            (start-on-heading (outline-on-heading-p))
            (last-good-pos (point)))
        (let ((done nil))
          (let ((iter 0))
            (while (and (not done) (< iter max-iter))
              (setq iter (1+ iter))
              (condition-case nil
                  (if (> step 0)
                      (outline-next-heading)
                    (outline-previous-heading))
                (error (setq done t)))
              (cond
               ;; Point unchanged -- search exhausted.
               ((= (point) start-pos) (setq done t))
               ;; Search landed back on the heading line we started on.
               ;; Step one line in the direction of travel to escape
               ;; the current heading's body region.
               ((and (outline-on-heading-p)
                     (= (line-number-at-pos) start-line))
                (forward-line step))
               ;; Heading text is currently invisible -- skip to next line.
               ((outline-invisible-p (line-beginning-position))
                (forward-line step))
               ;; Visible heading on a different line -- accept.
               ((outline-on-heading-p)
                (setq last-good-pos (point))
                (setq done t))
               ;; Off-heading -- handle in the recovery below.
               (t (setq done t))))))
        (cond
         ;; Walked from a heading off the visible edge -- drop to plain
         ;; BOB / EOB so the user can bounce back.
         ((and start-on-heading (not (outline-on-heading-p)))
          (goto-char (if (> step 0) (point-max) (point-min))))
         ;; Started off-heading and ended off-heading -- restore to the
         ;; last visible heading we successfully landed on.
         ((and (not start-on-heading) (not (outline-on-heading-p)))
          (goto-char last-good-pos))))
      (when (outline-on-heading-p) (back-to-indentation)))))
(defun my/previous-visible-heading (arg)
  "Move to previous visible heading line.  ARG controls repeat."
  (interactive "p")
  (my/next-visible-heading (- (or arg 1))))

(defun my/structural-focus ()
  "Symbol explorer with drill-down and outline preview.
RET jumps.  C-RET drills into children.  Highlighted candidate reveals
its body via outline-minor-mode fold peek.  Breadcrumb in header line.
outline-minor-mode lazy-enabled and persisted for travel.
Falls back to consult-imenu for non-tree-sitter buffers."
  (interactive)
  (if (treesit-language-at (point))
      (let* ((scope my/structural-scope)
             (stack my/structural-scope-stack)
             (entry-depth (length my/structural-scope-stack))
             (entry-scope my/structural-scope))
        (unwind-protect
            (catch 'my/structural-focus-done
              (my/structural--outline-ensure)
              (my/structural--breadcrumb)
              (when (fboundp 'outline-hide-body)
                (ignore-errors (outline-hide-body)))
              (while t
                (let* ((candidates (my/structural-focus--candidates scope))
                       (items (mapcar
                               (lambda (c)
                                 (let ((m (make-marker))
                                       (type (my/treesit-type-short (caddr c)))
                                       (drillable (my/structural-focus--has-children (cadddr c))))
                                   (set-marker m (cadr c))
                                   (cons (concat (propertize (format "%-6s " (concat "(" type ")"))
                                                             'face 'my/ts-imenu-type-face)
                                                 (car c)
                                                 (when drillable
                                                   (propertize " ▸"
                                                               'face 'my/structural-drillable-face)))
                                         m)))
                               candidates))
                       (items (if scope
                                  (cons (cons ".. (up)" 'up) items)
                                items))
                       (result
                        (condition-case nil
                            (minibuffer-with-setup-hook
                                (lambda ()
                                  (define-key vertico-map (kbd "C-<return>")
                                    (lambda ()
                                      (interactive)
                                      (setq my/structural-focus-action 'drill)
                                      (if (fboundp 'vertico-exit)
                                          (vertico-exit)
                                        (exit-minibuffer)))))
                              (consult--read
                               items
                               :prompt "Symbols: "
                               :require-match t
                               :category 'imenu
                               :lookup #'consult--lookup-cons
                               :sort nil
                               :state (let ((preview (consult--jump-preview)))
                                        (lambda (action cand)
                                          (when (eq action 'cursor)
                                            (when-let* ((m (cdr cand))
                                                       ((markerp m))
                                                       (node (my/structural-focus--node-at
                                                              (marker-position m) scope)))
                                              (setq my/structural--highlighted-node node)
                                              (when (fboundp 'outline-show-entry)
                                                (ignore-errors
                                                  (save-excursion
                                                    (my/structural--goto-node-start node)
                                                    (outline-show-entry))))))
                                          (funcall preview action
                                                   (when-let* ((m (cdr cand)))
                                                     (and (markerp m) m)))))))
                          (quit nil)))
                       (pos (cond
                          ((markerp result) (marker-position result))
                          ((and (consp result) (markerp (cdr result)))
                           (marker-position (cdr result)))
                          ((number-or-marker-p result) result)
                          (t nil)))
                       (action my/structural-focus-action))
                  (mapc (lambda (item) (when (markerp (cdr item))
                                         (set-marker (cdr item) nil)))
                        items)
                  (setq my/structural-focus-action nil)
                  (cond
                   ((eq action 'drill)
                    (if (number-or-marker-p pos)
                        (when-let* ((node (my/structural-focus--node-at pos scope)))
                          (if (my/structural-focus--has-children node)
                              (progn
                                (push scope stack)
                                (setq scope node)
                                (setq my/structural-scope node)
                                (setq my/structural-scope-stack stack)
                                (my/structural--breadcrumb)
                                (when (fboundp 'outline-hide-other)
                                  (ignore-errors
                                    (save-excursion
                                      (my/structural--goto-node-start node)
                                      (outline-hide-other)))))
                            (my/structural-jump pos)
                            (setq my/structural-scope nil)
                            (setq my/structural-scope-stack nil)
                            (throw 'my/structural-focus-done nil)))
                      (if stack
                          (progn
                            (setq scope (pop stack))
                            (setq my/structural-scope scope)
                            (setq my/structural-scope-stack stack))
                        (setq my/structural-scope nil)
                        (setq my/structural-scope-stack nil)
                        (throw 'my/structural-focus-done nil))))
                   ((eq result 'up)
                    (setq scope (pop stack))
                    (setq my/structural-scope scope)
                    (setq my/structural-scope-stack stack)
                    (my/structural--breadcrumb))
                   ((number-or-marker-p pos)
                    (my/structural-jump pos)
                    (setq my/structural-scope nil)
                    (setq my/structural-scope-stack nil)
                    (throw 'my/structural-focus-done nil))
                   (t
                    (if stack
                        (progn
                          (setq scope (pop stack))
                          (setq my/structural-scope scope)
                          (setq my/structural-scope-stack stack)
                          (my/structural--breadcrumb))
                      (setq my/structural-scope nil)
                      (setq my/structural-scope-stack nil)
                      (throw 'my/structural-focus-done nil)))))))
          (progn
            (when (and (null my/structural-scope)
                       (null my/structural-scope-stack)
                       (= (length stack) entry-depth)
                       (eq scope entry-scope))
              (my/structural--cleanup t))
            (my/structural--cleanup nil))))
    (call-interactively #'consult-imenu)))
(defun my/structural-focus--children (scope)
  "Return the effective children of SCOPE (nil = file root).
Unwraps passthrough containers (statement_block, export_statement, etc.)
so drilling yields the declarations inside, not empty container levels."
  (let* ((raw (if scope
                  (treesit-node-children scope)
                (treesit-node-children (treesit-buffer-root-node))))
         (result nil))
    (dolist (n raw)
      (if (member (treesit-node-type n) my/structural-passthrough-types)
          (dolist (c (treesit-node-children n))
            (push c result))
        (push n result)))
    (nreverse result)))

(defun my/structural-focus--has-children (node)
  "Return non-nil if NODE has at least one allowlisted drill-down candidate."
  (let ((children (my/structural-focus--children node))
        (allowlist (cdr (assoc major-mode my/structural-parent-types))))
    (cl-some (lambda (c) (member (treesit-node-type c) allowlist)) children)))

(defun my/structural-focus--candidates (scope)
  "Return candidates for SCOPE (nil = file root) as (DISPLAY POS TYPE NODE)."
  (let ((nodes (my/structural-focus--children scope))
        (allowlist (cdr (assoc major-mode my/structural-parent-types)))
        (result nil))
    (dolist (n nodes)
      (when (member (treesit-node-type n) allowlist)
        (push (list (my/ts-imenu-name n)
                    (treesit-node-start n)
                    (treesit-node-type n)
                    n)
              result)))
    (sort result (lambda (a b) (< (cadr a) (cadr b))))))

(defun my/structural-focus--node-at (pos scope)
  "Return the tree-sitter node at POS within SCOPE."
  (let ((nodes (my/structural-focus--children scope)))
    (cl-find pos nodes
             :test (lambda (pos node)
                     (and (treesit-node-start node)
                          (= pos (treesit-node-start node)))))))

;; ── Structural parent navigation ─────────────────────────────────
;; ; p: completing-read of enclosing blocks from point (innermost first)
;; ; P: jump to immediate parent (no prompt)
;; Tree-sitter modes use filtered ancestor chain. org-mode uses
;; org-element.  No fallback for other modes.

(require 'consult)

(defvar my/structural-parent-types
  '((typescript-ts-mode "function_declaration" "method_definition"
                        "class_declaration" "interface_declaration"
                        "type_alias_declaration" "enum_declaration"
                        "lexical_declaration" "variable_declaration"
                        "if_statement" "for_statement" "for_in_statement"
                        "while_statement" "switch_statement" "try_statement"
                        "catch_clause" "arrow_function" "object")
    (tsx-ts-mode "function_declaration" "method_definition"
                 "class_declaration" "interface_declaration"
                 "type_alias_declaration" "enum_declaration"
                 "lexical_declaration" "variable_declaration"
                 "if_statement" "for_statement" "for_in_statement"
                 "while_statement" "switch_statement" "try_statement"
                 "catch_clause" "arrow_function" "object")
    (lua-ts-mode "function_declaration" "if_statement" "for_statement"
                 "while_statement" "repeat_statement" "do_statement"))
  "Alist mapping major modes to structural parent type allowlists.")

(defun my/treesit-type-short (type)
  "Return a short display label for TYPE."
  (pcase type
    ("function_declaration" "fn")
    ("method_definition" "method")
    ("class_declaration" "class")
    ("interface_declaration" "iface")
    ("type_alias_declaration" "type")
    ("enum_declaration" "enum")
    ("lexical_declaration" "let")
    ("variable_declaration" "var")
    ("if_statement" "if")
    ("for_statement" "for")
    ("for_in_statement" "for-in")
    ("while_statement" "while")
    ("switch_statement" "switch")
    ("try_statement" "try")
    ("catch_clause" "catch")
    ("arrow_function" "arrow")
    ("object" "obj")
    ("do_statement" "do")
    ("repeat_statement" "repeat")
    (_ type)))

(defun my/treesit-node-anon-text (node)
  "Return a short description for an anonymous structural NODE."
  (let* ((text (string-trim
                (buffer-substring-no-properties
                 (treesit-node-start node)
                 (min (treesit-node-end node)
                      (+ (treesit-node-start node) 120)))))
         (first-line (car (split-string text "\n" t))))
    (if (> (length first-line) 60)
        (concat (substring first-line 0 57) "...")
      first-line)))

(defun my/treesit-node-display-name (node)
  "Return a display name for NODE from its name field, or its text."
  (or (when-let* ((name-node (treesit-node-child-by-field-name node "name")))
        (treesit-node-text name-node t))
      (my/treesit-node-anon-text node)))

(defun my/treesit-parent-breadcrumb ()
  "Return enclosing structural parent candidates for a tree-sitter buffer.
Each entry is (DISPLAY POS TYPE).  Sorted by position ascending
(file order)."
  (let ((allowlist (alist-get major-mode my/structural-parent-types))
        (node (treesit-node-at (point)))
        (result nil))
    (while node
      (when (member (treesit-node-type node) allowlist)
        (push (list (my/treesit-node-display-name node)
                    (treesit-node-start node)
                    (treesit-node-type node))
              result))
      (setq node (treesit-node-parent node)))
    (sort result (lambda (a b) (> (cadr a) (cadr b))))))

(defun my/org-element-display-name (element)
  "Return a display name for org ELEMENT."
  (let ((type (org-element-type element)))
    (pcase type
      ('headline (or (org-element-property :raw-value element) ""))
      ('item (let ((text (string-trim
                          (buffer-substring-no-properties
                           (org-element-begin element)
                           (org-element-end element)))))
               (if (> (length text) 80)
                   (concat (substring text 0 77) "...")
                 text)))
      (_ (symbol-name type)))))

(defun my/org-parent-breadcrumb ()
  "Return enclosing structural parent candidates for an org buffer.
Each entry is (DISPLAY POS TYPE).  Sorted by position ascending
(file order).
Skips intermediate `plain-list' containers."
  (let ((element (org-element-at-point))
        (result nil))
    (while element
      (let ((type (org-element-type element)))
        (when (memq type '(headline item))
          (push (list (my/org-element-display-name element)
                      (org-element-begin element)
                      (if (eq type 'headline) "headline" "item"))
                result)))
      (setq element (org-element-parent element)))
    (sort result (lambda (a b) (> (cadr a) (cadr b))))))

(defun my/structural-parents ()
  "Completing-read of enclosing structural blocks from point."
  (interactive)
  (let* ((cur-text (save-excursion
                     (beginning-of-line)
                     (string-trim
                      (buffer-substring-no-properties
                       (point) (line-end-position)))))
         (cur-label (if (> (length cur-text) 60)
                        (concat (substring cur-text 0 57) "...")
                      cur-text))
         (candidates
          (cons (list cur-label (point) "cursor")
                (cond
                 ((derived-mode-p 'org-mode)
                  (my/org-parent-breadcrumb))
                 ((treesit-language-at (point))
                  (my/treesit-parent-breadcrumb))
                 (t
                  (user-error "No structural context"))))))
    (if candidates
        (let* ((items (mapcar (lambda (c)
                                (let* ((m (make-marker))
                                       (pos (cadr c))
                                       (type (my/treesit-type-short (caddr c)))
                                       (line (save-excursion
                                               (goto-char pos)
                                               (line-number-at-pos))))
                                  (set-marker m pos)
                                  (cons (concat (format "%4d " line)
                                                (propertize (format "%-6s " (concat "(" type ")"))
                                                            'face 'my/ts-imenu-type-face)
                                                (car c))
                                        m)))
                              candidates))
               (selection
                 (consult--read
                  items
                  :prompt "Parent: "
                  :state (let ((preview (consult--jump-preview)))
                          (lambda (action cand)
                            (funcall preview action
                                     (when-let* ((m (cdr cand)))
                                        (and (markerp m) m)))))
                  :require-match t
                  :category 'imenu
                  :lookup #'consult--lookup-cons
                  :sort nil)))
          (when selection
            (my/structural-jump selection))
          (mapc (lambda (m) (set-marker m nil)) (mapcar #'cdr items)))
      (user-error "No enclosing blocks"))))

(defun my/structural-parent ()
  "Jump to the immediate enclosing structural parent."
  (interactive)
  (let ((candidates
         (cond
          ((derived-mode-p 'org-mode)
           (my/org-parent-breadcrumb))
          ((treesit-language-at (point))
           (my/treesit-parent-breadcrumb))
          (t
           (user-error "No structural context")))))
    (if candidates
        (let ((target (car (last candidates))))
          (my/structural-jump (cadr target)))
      (user-error "No enclosing block"))))

;; Lua
(add-to-list 'auto-mode-alist '("\\.lua\\'" . lua-ts-mode))
(add-to-list 'treesit-language-source-alist
             '(lua "https://github.com/tree-sitter-grammars/tree-sitter-lua"
                  "main" "src" nil))

;; Odin
(add-to-list 'treesit-language-source-alist
             '(odin "https://github.com/tree-sitter-grammars/tree-sitter-odin"))

(use-package odin-ts-mode
  :ensure nil
  :vc (:url "https://github.com/Sampie159/odin-ts-mode")
  :mode "\\.odin\\'")

;; Go
(add-to-list 'auto-mode-alist '("\\.go\\'" . go-ts-mode))

;; Rust
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))

;; Python
(add-to-list 'auto-mode-alist '("\\.py\\'" . python-ts-mode))
(add-to-list 'auto-mode-alist '("\\.pyi\\'" . python-ts-mode))

;; LSP via eglot (built-in)
;; Only start for file-backed buffers (skips dirvish preview, *scratch*, etc.)

(defvar my-eglot-suppressed nil
  "When non-nil, eglot skips auto-start. Bound during perspective state load.")

(defun eglot-ensure-if-selected ()
  (when (and (buffer-file-name)
             (not my-eglot-suppressed))
    (eglot-ensure)))

(use-package eglot
  :hook ((typescript-ts-mode . eglot-ensure-if-selected)
         (tsx-ts-mode . eglot-ensure-if-selected)
         (odin-ts-mode . eglot-ensure-if-selected)
         (go-ts-mode . eglot-ensure-if-selected)
         (rust-ts-mode . eglot-ensure-if-selected)
         (python-ts-mode . eglot-ensure-if-selected))
  :config
  (add-to-list 'eglot-server-programs '(odin-ts-mode . ("ols")))
  (add-to-list 'eglot-server-programs
               '((typescript-ts-mode tsx-ts-mode)
                 . ("vtsls" "--stdio")))
  (add-to-list 'eglot-server-programs '(go-ts-mode . ("gopls")))
  (add-to-list 'eglot-server-programs '(rust-ts-mode . ("rust-analyzer")))
  (add-to-list 'eglot-server-programs '(python-ts-mode . ("basedpyright-langserver" "--stdio"))))

(provide 'config-lang)
;;; config-lang.el ends here
