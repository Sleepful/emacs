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
    (if name-node (treesit-node-text name-node t) "Anonymous")))

(defun my/ts-valid-imenu-entry (node)
  "Return non-nil if NODE should appear in imenu."
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

(defun my/ts-imenu-extend ()
  "Replace imenu settings with a flat file-order index.
All declaration types in a single merged category with type prefixes.
Fixes export-wrapped top-level detection and file-order display.
Forces tree-sitter imenu even when eglot is active (LSP symbols are too granular)."
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
                 my/ts-imenu-name-with-type))))

(add-hook 'typescript-ts-base-mode-hook #'my/ts-imenu-extend)

;; ── Structural parent navigation ─────────────────────────────────
;; ; p: completing-read of enclosing blocks from point (innermost first)
;; ; P: jump to immediate parent (no prompt)
;; Tree-sitter modes use filtered ancestor chain. org-mode uses
;; org-element.  No fallback for other modes.

(require 'consult)

(defvar my/structural-parent-types
  '((typescript-ts-mode "function_declaration" "method_definition"
                        "class_declaration" "interface_declaration"
                        "if_statement" "for_statement" "for_in_statement"
                        "while_statement" "switch_statement" "try_statement"
                        "catch_clause" "arrow_function" "object")
    (tsx-ts-mode "function_declaration" "method_definition"
                 "class_declaration" "interface_declaration"
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
  (or (when-let ((name-node (treesit-node-child-by-field-name node "name")))
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
                                     (when-let ((m (cdr cand)))
                                       (and (markerp m) m)))))
                 :require-match t
                 :category 'imenu
                 :lookup #'consult--lookup-cons
                 :sort nil)))
          (when selection
            (push-mark)
            (goto-char selection))
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
          (push-mark)
          (goto-char (cadr target)))
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
         (odin-ts-mode . eglot-ensure-if-selected))
  :config
  (add-to-list 'eglot-server-programs '(odin-ts-mode . ("ols")))
  (add-to-list 'eglot-server-programs
               '((typescript-ts-mode tsx-ts-mode)
                 . ("vtsls" "--stdio"))))

(provide 'config-lang)
;;; config-lang.el ends here
