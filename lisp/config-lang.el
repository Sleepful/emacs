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
;; Delay eglot startup to avoid launching LSP for dirvish preview buffers
(defun eglot-ensure-if-selected ()
  (let ((buf (current-buffer)))
    (run-with-idle-timer 1 nil
      (lambda ()
        (when (and (buffer-live-p buf)
                   (eq buf (window-buffer (selected-window))))
          (with-current-buffer buf
            (eglot-ensure)))))))

(use-package eglot
  :hook ((typescript-ts-mode . eglot-ensure-if-selected)
         (tsx-ts-mode . eglot-ensure-if-selected)
         (odin-ts-mode . eglot-ensure-if-selected))
  :config
  (add-to-list 'eglot-server-programs '(odin-ts-mode . ("ols"))))

(provide 'config-lang)
;;; config-lang.el ends here
