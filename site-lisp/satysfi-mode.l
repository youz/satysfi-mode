;;; -*- mode:lisp; package:satysfi-mode -*-

(defpackage "satysfi-mode"
  (:nicknames "satysfi")
  (:use :lisp :editor))

(in-package "satysfi")
(export '(*satysfi-cmd*
	  *keymap*
	  *hook*
	  ))

(defvar *satysfi-cmd* nil)
(defvar *keyword-file* "satysfi")
(defvar *keyword-table* nil)

(defparameter *keyword-regexps*
  (compile-regexp-keyword-list
   '(("^@require:" nil 0 nil)
     ("^@import:" nil 0 nil)
     )))

(defvar *hook* nil)
(defvar *complete-command* nil)

(defparameter *keymap* (make-sparse-keymap))
(define-key *keymap* #\C-h 'backward-delete-char-untabify-or-selection)
(define-key *keymap* #\RET 'newline-and-indent)
(define-key *keymap* #\TAB 'complete-or-indent)
(define-key *keymap* '(#\C-c #\l) 'list-function)
(define-key *keymap* '(#\C-c #\C-c) 'compile-to-pdf)

(defparameter *syntax-table* (make-syntax-table))
(set-syntax-string *syntax-table* #\`)
(set-syntax-symbol *syntax-table* #\_)
(set-syntax-symbol *syntax-table* #\-)
(set-syntax-match *syntax-table* #\( #\))
(set-syntax-match *syntax-table* #\{ #\})
(set-syntax-match *syntax-table* #\[ #\])
(set-syntax-start-comment *syntax-table* #\% t)
(set-syntax-end-comment *syntax-table* #\LFD nil t)

;;; edit
(defun summary-of-functions ()
  (let ((fns nil))
    (save-excursion
      (beginning-of-buffer)
      (while (scan-buffer "^let\\(-rec\\)? +\\([^ ]+ +[^ ]+.*\\)"
			  :regexp t :no-dup t)
	(let ((def (match-string 2))
	      (lno (current-line-number)))
	  (push (list lno def) fns))))
    (nreverse fns)))

(defun point-at-bol ()
  (save-excursion
    (goto-bol)
    (point)))

(defun complete-or-indent ()
  (interactive)
  (if (= (point-at-bol)
	 (save-excursion
	   (skip-chars-backward " \t")
	   (point)))
      (indent-relative)
    (if *complete-command*
	(call-interactively *complete-command*)
      (do-completion (point)
		     (and (skip-syntax-spec-backward "^ ")
			  (point))
		     :symbol-name))))

;;; compile
(defun compile-to-pdf (&optional debug)
  (interactive "p")
  (let* ((src (get-buffer-file-name))
	 (pdf (substitute-string src (concat (pathname-type src) "$") "pdf"))
	 (cmd (format nil "\"~A\" -o \"~A\" ~:[~;--debug-show-bbox~] \"~A\""
		      *satysfi-cmd* pdf debug src)))
    (when (file-exist-p pdf)
      (delete-file pdf))
    (let ((outbuf (get-buffer-create "*satysfi-output*")))
      (erase-buffer outbuf)
      (setup-temp-buffer outbuf)
      (let ((proc (make-process cmd :output outbuf)))
	(pop-to-buffer outbuf t t)))))



;;; mode definition
(in-package "editor")
(defun satysfi-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "SATySFi"
	buffer-mode 'satysfi-mode
	comment-start "%"
	comment-end "")
  (use-syntax-table satysfi::*syntax-table*)
  (use-keymap satysfi::*keymap*)
  (make-local-variable 'keyword-hash-table)
  (setq keyword-hash-table
	(or satysfi::*keyword-table*
	    (setq satysfi::*keyword-table*
		  (load-keyword-file "satysfi"))))
  (make-local-variable 'regexp-keyword-list)
  (when satysfi::*keyword-regexps*
    (setq regexp-keyword-list satysfi::*keyword-regexps*))
  (make-local-variable 'build-summary-function)
  (ed::set-buffer-local 'indent-tabs-mode nil)
  (setq build-summary-function 'satysfi::summary-of-functions)
  (make-local-variable '*post-command-hook*)
  (run-hooks 'satysfi::*hook*))

(export '(satysfi-mode))

(provide "satysfi-mode")
