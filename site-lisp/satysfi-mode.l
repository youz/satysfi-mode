;;; -*- mode:lisp; package:satysfi-mode -*-

(defpackage "satysfi-mode"
  (:nicknames "satysfi")
  (:use :lisp :editor))

(in-package "satysfi")
(export '(*satysfi-cmd*
	  *pdf-viewer*
	  *satysfi-lib*
	  *keymap*
	  *complete-command*
	  *satysfi-mode-hook*
	  *before-compile-hook*
	  ))

(defvar *satysfi-cmd* "satysfi.exe")
(defvar *satysfi-lib* :env
  "satysfiのライブラリパス文字列 (キーワードシンボル:envを指定した場合は環境変数%SATYSFI_RUNTIME%より取得)")

(defvar *pdf-viewer* nil
  "PDF表示方法  nil -> システム標準アプリで表示|関数 or 関数シンボル -> その関数にpdfのパスを渡して実行")

(defvar *keyword-file* "satysfi")
(defvar *keyword-table* nil)

(defparameter *keyword-regexps*
  (compile-regexp-keyword-list
   '(("^@require:" nil 0 nil)
     ("^@import:" nil 0 nil)
     )))

(defvar *satysfi-mode-hook* nil)
(defvar *before-compile-hook* nil)
(defvar *complete-command* nil)

(defvar *keymap* (make-sparse-keymap))
(define-key *keymap* #\C-h 'backward-delete-char-untabify-or-selection)
(define-key *keymap* #\RET 'newline-and-indent)
(define-key *keymap* #\TAB 'complete-or-indent)
(define-key *keymap* #\F10 'find-satyh)
(define-key *keymap* '(#\C-c #\l) 'list-function)
(define-key *keymap* '(#\C-c #\c) 'compile-to-pdf)
(define-key *keymap* '(#\C-c #\C-c) 'compile-and-view-pdf)
(define-key *keymap* '(#\C-c #\C-v) 'view-compiled-pdf)

(defconstant +logbuffer-name+ "*satysfi-output*")
(defparameter *logbuffer-keymap* (make-sparse-keymap))
(define-key *logbuffer-keymap* #\F10 'jump-to-error)

(defparameter *syntax-table*
  (let ((tbl (make-syntax-table)))
    (map () #'(lambda (c) (set-syntax-symbol tbl c)) "&'*+-./<=>\\^_|")
    (set-syntax-string tbl #\`)
    (set-syntax-match tbl #\( #\))
    (set-syntax-match tbl #\{ #\})
    (set-syntax-match tbl #\[ #\])
    (set-syntax-start-comment tbl #\% t)
    (set-syntax-end-comment tbl #\LFD nil t)
    tbl))

;;; utility
(defmacro whenlet (var expr &body body)
  `(let ((,var ,expr))
     (when ,var ,@body)))

(defun goto-buf (buf)
  (let ((win (get-buffer-window buf)))
    (if win (set-window win)
      (set-buffer buf))))


;;; edit
(defun summary-of-functions ()
  (let ((fns nil))
    (save-excursion
      (beginning-of-buffer)
      (while (scan-buffer "^let\\(-rec\\|-inline\\|-block\\)? .+="
			  :regexp t :no-dup t)
	(let ((def (match-string 0))
	      (lno (current-line-number)))
	  (push (list lno (subseq def 0 (1- (length def)))) fns))))
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

(defun satysfi-package-dir ()
  (let ((lib (if (eq *satysfi-lib* :env)
		 (si:getenv "SATYSFI_RUNTIME")
	       (or *satysfi-lib*
		   (merge-pathnames ".satysfi" (si:getenv "USERPROFILE"))))))
    (merge-pathnames "dist/packages" lib)))

(defun looking-satyh ()
  (save-excursion
    (goto-bol)
    (when (looking-at "^@\\(require\\|import\\): *\\(.+\\) *$")
      (let* ((name (concat (match-string 2) ".satyh"))
	     (dir (if (string= (match-string 1) "require")
		      (satysfi-package-dir)
		    (directory-namestring (get-buffer-file-name)))))
	(merge-pathnames name dir)))))

(defun find-satyh ()
  (interactive)
   (let ((satyh (looking-satyh)))
     (cond ((null satyh)
	    (whenlet selected (filer (satysfi-package-dir))
	      (find-file selected)))
	   ((file-exist-p satyh)
	    (find-file satyh))
	   (t (error "file not found: ~A" satyh)))))


;;; compile
(defun pdf-name (srcpath)
  (let ((path (directory-namestring srcpath))
	(file (pathname-name srcpath)))
    (merge-pathnames (concat file ".pdf") path)))

(defun make-command-line (src pdf debug)
  (format nil "\"~A\" --full-path -o \"~A\" ~:[~;--debug-show-bbox~] \"~A\""
	  *satysfi-cmd* pdf debug src))

(defun highlight-error-message ()
  (save-excursion
    (goto-char (point-min))
    (while (scan-buffer "^!.+ at line \\([0-9]+\\), characters? \\([0-9]+\\)"
			:regexp t :no-dup t)
      (save-excursion
	(let ((from (point))
	      (to (progn (goto-eol) (point)))
	      (line (parse-integer (match-string 1)))
	      (col (parse-integer (match-string 2)))
	      (file nil))
	  (when (scan-buffer "^  \\(parsing\\|reading\\) '\\(.+\\)' " :regexp t :reverse t)
	    (setq file (match-string 2)))
	  (set-text-attribute from to (list 'errmsg file line col)
			      :foreground 1))))))

(defun jump-to-error ()
  (interactive)
  (multiple-value-bind (start end tag)
      (find-text-attribute 'errmsg :start (point-min) :key 'safe-car)
    (if tag
	(progn
	  (find-file-other-window (cadr tag))
	  (goto-line (caddr tag))
	  (goto-column (cadddr tag)))
      (message "error not found"))))

(defun is-satysfi-running ()
  (whenlet logbuf (find-buffer +logbuffer-name+)
    (whenlet proc (buffer-process logbuf)
      (eq (process-status proc) :run))))

(defun run-satysfi (srcbuf &key onsuccess debug)
  (when (is-satysfi-running)
    (message "SATySFi is running")
    (return-from run-satysfi))
  (let* ((src (get-buffer-file-name srcbuf))
	 (pdf (pdf-name src))
	 (cmd (make-command-line src pdf debug)))
    (when (file-exist-p pdf)
      (delete-file pdf :if-access-denied :error))
    (let ((logbuf (get-buffer-create +logbuffer-name+)))
      (erase-buffer logbuf)
      (setup-temp-buffer logbuf)
      (let ((proc (make-process cmd :output logbuf)))
	(pop-to-buffer logbuf t t)
	(use-keymap *logbuffer-keymap*)
	(goto-buf srcbuf)
	(labels ((wait ()
		   (let ((win (get-buffer-window (selected-buffer)))
			 (logwin (get-buffer-window logbuf)))
		     (when logwin
		       (set-window logwin)
		       (goto-char (point-max))
		       (set-window win)))
		   (when (eq (process-status proc) :exit)
		     (stop-timer #'wait)
		     (case (process-exit-code proc)
		       (0 (goto-buf srcbuf)
			  (when onsuccess
			    (handler-case
				(funcall onsuccess pdf)
			      (error (c)
				(message-box (format nil "~A" c) nil '(:exclamation))))))
		       (t (goto-buf logbuf)
			  (goto-char (point-min))
			  (highlight-error-message)
			  (goto-char (point-max))
			  (message "SATySFi command failed"))))
		   (refresh-screen)))
	  (start-timer 0.1 #'wait))))))

(defun compile-to-pdf (&optional debug)
  (interactive "p")
  (run-hooks '*before-compile-hook*)
  (run-satysfy (selected-buffer) :debug debug))

(defun compile-and-view-pdf (&optional debug)
  (interactive "p")
  (run-hooks '*before-compile-hook*)
  (run-satysfi (selected-buffer) :debug debug :onsuccess #'view-pdf))

(defun view-pdf (pdf)
  (unless (file-exist-p pdf)
    (msgbox "file not found\n~A" pdf)
    (return-from view-pdf))
  (if (null *pdf-viewer*)
      (shell-execute pdf)
    (funcall *pdf-viewer* pdf)))

(defun view-compiled-pdf ()
  (interactive)
  (view-pdf (pdf-name (get-buffer-file-name))))


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
  (run-hooks 'satysfi::*satysfi-mode-hook*))

(export '(satysfi-mode))

(provide "satysfi-mode")
