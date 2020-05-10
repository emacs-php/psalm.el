;;; flymake-psalm.el --- Flymake backend for PHP using Psalm  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Friends of Emacs-PHP development

;; Author: USAMI Kenta <tadsan@zonu.me>
;; Created: 31 Mar 2020
;; Version: 0.5.0
;; Keywords: tools, php
;; Homepage: https://github.com/emacs-php/psalm.el
;; Package-Requires: ((emacs "26.1") (psalm "0.5.0"))
;; License: GPL-3.0-or-later

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Flymake backend for PHP using Psalm (PHP Static Analysis Tool).
;;
;; Put the following into your .emacs file (~/.emacs.d/init.el)
;;
;;     (add-hook 'php-mode-hook #'flymake-psalm-turn-on)
;;
;; For Lisp maintainers: see [GNU Flymake manual - 2.2.2 An annotated example backend]
;; https://www.gnu.org/software/emacs/manual/html_node/flymake/An-annotated-example-backend.html

;;; Code:
(require 'php-project)
(require 'flymake)
(require 'psalm)
(eval-when-compile
  (require 'pcase))

(defgroup flymake-psalm nil
  "Flymake backend for PHP using Psalm."
  :group 'flymake
  :group 'psalm)

(defcustom flymake-psalm-disable-c-mode-hooks t
  "When T, disable `flymake-diagnostic-functions' for `c-mode'."
  :type 'boolean
  :group 'flymake-psalm)

(defvar-local flymake-psalm--proc nil)

(defun flymake-psalm-make-process (root command-args report-fn source)
  "Make Psalm process by ROOT, COMMAND-ARGS, REPORT-FN and SOURCE."
  (let ((default-directory root))
    (make-process
     :name "flymake-psalm" :noquery t :connection-type 'pipe
     :buffer (generate-new-buffer " *Flymake-Psalm*")
     :command command-args
     :sentinel
     (lambda (proc _event)
       (pcase (process-status proc)
         (`exit
          (unwind-protect
              (when (with-current-buffer source (eq proc flymake-psalm--proc))
                (with-current-buffer (process-buffer proc)
                  (goto-char (point-min))
                  (cl-loop
                   while (search-forward-regexp
                          (eval-when-compile
                            (rx line-start (1+ (not (any ":"))) ":"
                                (group-n 1 (one-or-more (not (any ":")))) ":"
                                (group-n 2 (one-or-more not-newline)) line-end))
                          nil t)
                   for msg = (match-string 2)
                   for (beg . end) = (flymake-diag-region
                                      source
                                      (string-to-number (match-string 1)))
                   for type = :warning
                   collect (flymake-make-diagnostic source beg end type msg)
                   into diags
                   finally (funcall report-fn diags)))
                (flymake-log :warning "Canceling obsolete check %s" proc))
            (kill-buffer (process-buffer proc))))
         (code (user-error "Psalm error (exit status: %s)" code)))))))

(defun flymake-psalm (report-fn &rest _ignored-args)
  "Flymake backend for Psalm report using REPORT-FN."
  (let ((command-args (psalm-get-command-args)))
    (unless (car command-args)
      (user-error "Cannot find a psalm executable command"))
    (when (process-live-p flymake-psalm--proc)
      (kill-process flymake-psalm--proc))
    (let ((source (current-buffer)))
      (save-restriction
        (widen)
        (setq flymake-psalm--proc (flymake-psalm-make-process (php-project-get-root-dir) command-args report-fn source))
        (process-send-region flymake-psalm--proc (point-min) (point-max))
        (process-send-eof flymake-psalm--proc)))))

;;;###autoload
(defun flymake-psalm-turn-on ()
  "Enable `flymake-psalm' as buffer-local Flymake backend."
  (interactive)
  (let ((enabled (psalm-enabled)))
    (when enabled
      (flymake-mode 1)
      (when flymake-psalm-disable-c-mode-hooks
        (remove-hook 'flymake-diagnostic-functions #'flymake-cc t))
      (add-hook 'flymake-diagnostic-functions #'flymake-psalm nil t))))

(provide 'flymake-psalm)
;;; flymake-psalm.el ends here
