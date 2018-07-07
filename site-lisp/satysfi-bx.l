;;; -*- mode:lisp; package:satysfi-mode.bx -*-

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "satysfi-mode")
  (require "browserex"))

(defpackage "satysfi-mode.bx"
  (:use :lisp :ed :satysfi-mode))

(in-package "satysfi-mode.bx")

(export '(*bx-position*
	  *bx-size*
	  setup))

(defvar *bx-position* 2
  "browserex表示位置 0:左 1:上 2:右 3:下")
(defvar *bx-size* 1000
  "browserex表示サイズ")

(defvar *saved-window-config* nil)

(defun view-pdf-in-bx (pdf)
  (unless *saved-window-config*
    (setq *saved-window-config* (current-window-configuration)))
  (delete-other-windows)
  (bx:navigate pdf :position *bx-position* :size *bx-size*))

(defun close-pdf-pane ()
  (interactive)
  (when (bx:browser-open-p)
    (bx:close-browser))
  (when *saved-window-config*
    (set-window-configuration *saved-window-config*)
    (setq *saved-window-config* nil)))

(defun setup ()
  (add-hook 'satysfi:*before-compile-hook* 'close-pdf-pane)
  (define-key satysfi:*keymap* '(#\C-c #\C-k) 'close-pdf-pane)
  (setq satysfi:*pdf-viewer* 'view-pdf-in-bx)
  t)

(provide "satysfi-bx")
