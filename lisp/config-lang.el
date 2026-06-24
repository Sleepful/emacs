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

;; Odin
(add-to-list 'treesit-language-source-alist
             '(odin "https://github.com/tree-sitter-grammars/tree-sitter-odin"))

(use-package odin-ts-mode
  :ensure nil
  :vc (:url "https://github.com/Sampie159/odin-ts-mode")
  :mode "\\.odin\\'")

;; LSP via eglot (built-in)
;; Guard with selected-window check to avoid launching LSP for dirvish preview buffers
(defun eglot-ensure-if-selected ()
  (when (eq (current-buffer) (window-buffer (selected-window)))
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
