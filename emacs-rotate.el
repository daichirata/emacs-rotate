;;; emacs-rotate.el --- Rotate the layout of emacs

;; Copyright (C) 2013  daichirata

;; Author: daichi.hirata <hirata.daichi at gmail.com>
;; Version: 0.1.0
;; Keywords: frames, window, layout
;; URL: https://github.com/daichirata/emacs-rotate

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'cl-seq)

(eval-when-compile (require 'cl-lib))

(defgroup rotate nil
  "tmux like window manager"
  :group 'windows)

(defvar rotate-count 0)

(defcustom rotate:exclude-regex-alist
  '(
    ;; e.g.  " buffer-name-with-space-padded"
    "^ +"
    ;; e.g.  " *auto-generated-buffer*"
    "^[ ]+\\*[^*]+\\*"  ; Although this case is included in the 1st expression.
    )
  " Setting this variable sometimes becomes useful when you execute (rotate-window).
buffer-name matching list of regular expression is excluded.
More than a element of regular expression is tedious, but this makes it easy to maintain the list.
"
  :group 'rotate
  )

(defun rotate:exclude-p (win)
  "Return flags of list about which 'win is to be excluded.
 according to variable rotate:exclude-regex-alist.
Each flag have value 2^x, which is binary expression corresponding to rotate:exclude-regex-alist.
"
  ;;(loop with flag = (make-vector (length win) 0)
  (cl-loop with flag = (make-vector (length win) 0)
        with idx_reg = 0
        for regex in rotate:exclude-regex-alist
        do
        (cl-loop with idx_win = 0
              for w in win
              do
              (if (string-match regex (buffer-name (window-buffer w)))
                  (setf (aref flag idx_win) (+ (aref flag idx_win) (expt 2 idx_reg)))
                )
              (incf idx_win)
              )
        (incf idx_reg)
        finally (return (append flag nil)))
  )

(defun rotate:no-dedicated-window-p (win)
  "Return flag [1:true, 0:false ] of list for which 'win is window-dedicated-p"
  (mapcar #'(lambda (x) (if x 1 0)) (mapcar 'window-dedicated-p win))
  )

(defun rotate:count-windows:no-dedicated ()
  (length (rotate:window-list:no-dedicated))
  )

;;notused$ (defun rotate:count-windows:exclude-regex ()
;;notused$   "Return the number of windows each of which is not dedicated window and not matching rotate:exclude-regex-alist"
;;notused$   (length (rotate:exclude-p))
;;notused$   )

(defun rotate:count-windows:no-dedicated ()
  "Return the number of not dedicated windows."
  (length (delq t (mapcar 'window-dedicated-p (window-list-1))))
  )

(defun rotate:one-window-p:no-dedicated ()
  "Extended version of one-window-p. Ignore dedicated-windows."
  (let ( (num_win (rotate:count-windows:no-dedicated) ))
    (if (= num_win 1)
        t
      nil))
  )

;;;###autoload
(defun rotate:window-list:no-dedicated ()
  "Return list of windows.
Ignored files are
- window-dedicated-p
"
  (let* (
         (wl (window-list-1))
         (flg2 (rotate:no-dedicated-window-p wl))
         )
    (cl-loop
          for i2 in flg2
          for i3 in wl
          if (> 1 i2) collect i3
          );loop
    );let*
  )

;;;###autoload
(defun rotate:window-list:exclude-regex ()
  "Return list of windows.
Ignored files are
- window-dedicated-p
- named rotate:exclude-regex-alist"
  (let* (
        (wl (window-list-1))
         (flg1 (rotate:exclude-p wl))
         (flg2 (rotate:no-dedicated-window-p wl))
        )
    (cl-loop for i1 in flg1
          for i2 in flg2
          for i3 in wl
          if (> 1 (+ i1 i2))
          collect i3
     );loop
    );let*
  )

(defvar rotate-functions
  '(rotate:even-horizontal
    rotate:even-vertical
    rotate:main-horizontal
    rotate:main-vertical
    rotate:tiled))

;;;###autoload
(defun rotate-layout ()
  "Switches to the next window layout defined in
`rotate-functions'."
  (interactive)
  (let* ((len (length rotate-functions))
         (func (elt rotate-functions (% rotate-count len))))
    (prog1 (message "%s" func)
      (call-interactively func)
      (if (>= rotate-count (- len 1))
          (setq rotate-count 0)
        (cl-incf rotate-count)))))

;;;###autoload
(defun rotate-window ()
  "Rotates windows kind of like swapping them."
  (interactive)
  (let* ((bl (reverse (rotate:buffer-list)))
         (nbl (append (cdr bl) (list (car bl)))))
    (cl-loop for w in (rotate:window-list:no-dedicated)
          for b in (reverse nbl)
          do (set-window-buffer w b))
    (select-window (next-window))))

;;;###autoload
(defun rotate:even-horizontal ()
  (interactive)
  (rotate:refresh-window #'rotate:horizontally-n))

;;;###autoload
(defun rotate:even-vertical ()
  (interactive)
  (rotate:refresh-window #'rotate:vertically-n))

;;;###autoload
(defun rotate:main-horizontal ()
  (interactive)
  (rotate:refresh-window #'rotate:main-horizontally-n))

;;;###autoload
(defun rotate:main-vertical ()
  (interactive)
  (rotate:refresh-window #'rotate:main-vertically-n))

;;;###autoload
(defun rotate:tiled ()
  (interactive)
  (rotate:refresh-window #'rotate:tiled-n))

(defun rotate:main-horizontally-n (num)
  (if (<= num 2)
      (split-window-horizontally
       (floor (* (window-width) (/ 2.0 3.0))))
    (split-window-vertically)
    (other-window 1)
    (rotate:horizontally-n (- num 1))))

(defun rotate:main-vertically-n (num)
  (if (<= num 2)
      (split-window-vertically
       (floor (* (window-height) (/ 2.0 3.0))))
    (split-window-horizontally)
    (other-window 1)
    (rotate:vertically-n (- num 1))))

(defun rotate:horizontally-n (num)
  (if (<= num 2)
      (split-window-horizontally)
    (split-window-horizontally
     (- (window-width) (/ (window-width) num)))
    (rotate:horizontally-n (- num 1))))

(defun rotate:vertically-n (num)
  (if (<= num 2)
      (split-window-vertically)
    (split-window-vertically
     (- (window-height) (/ (window-height) num)))
    (rotate:vertically-n (- num 1))))

(defun rotate:tiled-n (num)
  (cond
   ((<= num 2)
    (split-window-vertically))
   ((<= num 6)
    (rotate:tiled-2column num))
   (t
    (rotate:tiled-3column num))))

(defun rotate:tiled-2column (num)
  (rotate:vertically-n (/ (+ num 1) 2))
  (dotimes (i (/ num 2))
    (split-window-horizontally)
    (other-window 2)))

(defun rotate:tiled-3column (num)
  (rotate:vertically-n (/ (+ num 2) 3))
  (dotimes (i (/ (+ num 1) 3))
    (rotate:horizontally-n 3)
    (other-window 3))
  (when (= (% num 3) 2)
    (other-window -1)
    (delete-window)))

(defun rotate:window-list ()
  (window-list nil nil (minibuffer-window)))

(defun rotate:buffer-list ()
  (mapcar (lambda (w) (window-buffer w)) (rotate:window-list:no-dedicated)))

(defun rotate:refresh-window (proc)
  (when (not (one-window-p))
    (let ((window-num (rotate:count-windows:no-dedicated))
          (buffer-list (rotate:buffer-list))
          (current-pos (cl-position (selected-window) (rotate:window-list:no-dedicated))))
      (delete-other-windows)
      (funcall proc window-num)
      (cl-loop for w in (rotate:window-list:no-dedicated)
            for b in buffer-list
            do (set-window-buffer w b))
      (select-window (nth current-pos (rotate:window-list:no-dedicated))))))

(provide 'emacs-rotate)
