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

;; LSP via eglot (built-in)
(use-package eglot
  :hook ((typescript-ts-mode . eglot-ensure)
         (tsx-ts-mode . eglot-ensure)))

(provide 'config-lang)
;;; config-lang.el ends here
