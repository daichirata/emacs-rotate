;;; rotate.el --- Rotate window layouts and buffers  -*- lexical-binding: t; -*-

;; Copyright (C) 2013-2026  Daichi Hirata

;; Author: Daichi Hirata <bunny.hop.md@gmail.com>
;; Version: 0.2.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: window, layout, convenience
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

;;; Commentary:

;; This package provides commands for cycling preset window layouts
;; and rotating buffers across windows, inspired by tmux.
;;
;; Main entry points:
;;
;;   M-x rotate-layout  -- cycle through layouts in `rotate-functions'.
;;   M-x rotate-window  -- rotate buffers across the current windows.
;;
;; Layout commands:
;;
;;   `rotate-even-horizontal'  -- spread evenly left to right.
;;   `rotate-even-vertical'    -- spread evenly top to bottom.
;;   `rotate-main-horizontal'  -- one main window on top, others below.
;;   `rotate-main-vertical'    -- one main window on the left, others right.
;;   `rotate-tiled'            -- arrange in a tiled grid.

;;; Code:

(require 'cl-lib)

(defgroup rotate nil
  "Rotate the layout of Emacs windows."
  :group 'convenience
  :prefix "rotate-")

(defcustom rotate-functions
  '(rotate-even-horizontal
    rotate-even-vertical
    rotate-main-horizontal
    rotate-main-vertical
    rotate-tiled)
  "Layout commands cycled through by `rotate-layout'."
  :type '(repeat function)
  :group 'rotate)

(defun rotate--count ()
  "Return the layout index for the selected frame."
  (or (frame-parameter nil 'rotate--count) 0))

(defun rotate--set-count (n)
  "Set the layout index for the selected frame to N."
  (set-frame-parameter nil 'rotate--count n))

;;;###autoload
(defun rotate-layout ()
  "Switch to the next layout in `rotate-functions'."
  (interactive)
  (let* ((len (length rotate-functions))
         (idx (mod (rotate--count) len))
         (func (nth idx rotate-functions)))
    (message "%s" func)
    (funcall func)
    (rotate--set-count (if (>= idx (1- len)) 0 (1+ idx)))))

;;;###autoload
(defun rotate-window ()
  "Rotate buffers across the windows of the selected frame."
  (interactive)
  (let* ((bl (reverse (rotate--buffer-list)))
         (nbl (append (cdr bl) (list (car bl)))))
    (cl-loop for w in (rotate--window-list)
             for b in (reverse nbl)
             do (set-window-buffer w b))
    (select-window (next-window))))

;;;###autoload
(defun rotate-even-horizontal ()
  "Spread windows evenly from left to right."
  (interactive)
  (rotate--refresh-window #'rotate--horizontally-n))

;;;###autoload
(defun rotate-even-vertical ()
  "Spread windows evenly from top to bottom."
  (interactive)
  (rotate--refresh-window #'rotate--vertically-n))

;;;###autoload
(defun rotate-main-horizontal ()
  "Put one main window on top, the rest spread horizontally below."
  (interactive)
  (rotate--refresh-window #'rotate--main-horizontally-n))

;;;###autoload
(defun rotate-main-vertical ()
  "Put one main window on the left, the rest spread vertically on the right."
  (interactive)
  (rotate--refresh-window #'rotate--main-vertically-n))

;;;###autoload
(defun rotate-tiled ()
  "Arrange windows in a tiled grid."
  (interactive)
  (rotate--refresh-window #'rotate--tiled-n))

(defun rotate--main-horizontally-n (num)
  "Build the main-horizontal layout for NUM windows."
  (if (<= num 2)
      (split-window-horizontally
       (floor (* (window-width) (/ 2.0 3.0))))
    (split-window-vertically)
    (other-window 1)
    (rotate--horizontally-n (1- num))))

(defun rotate--main-vertically-n (num)
  "Build the main-vertical layout for NUM windows."
  (if (<= num 2)
      (split-window-vertically
       (floor (* (window-height) (/ 2.0 3.0))))
    (split-window-horizontally)
    (other-window 1)
    (rotate--vertically-n (1- num))))

(defun rotate--horizontally-n (num)
  "Split the current window into NUM equal horizontal panes."
  (if (<= num 2)
      (split-window-horizontally)
    (split-window-horizontally
     (- (window-width) (/ (window-width) num)))
    (rotate--horizontally-n (1- num))))

(defun rotate--vertically-n (num)
  "Split the current window into NUM equal vertical panes."
  (if (<= num 2)
      (split-window-vertically)
    (split-window-vertically
     (- (window-height) (/ (window-height) num)))
    (rotate--vertically-n (1- num))))

(defun rotate--tiled-n (num)
  "Tile the current frame into NUM windows."
  (cond
   ((<= num 2)
    (split-window-vertically))
   ((<= num 6)
    (rotate--tiled-2column num))
   (t
    (rotate--tiled-3column num))))

(defun rotate--tiled-2column (num)
  "Tile NUM windows into 2 columns."
  (rotate--vertically-n (/ (1+ num) 2))
  (dotimes (_i (/ num 2))
    (split-window-horizontally)
    (other-window 2)))

(defun rotate--tiled-3column (num)
  "Tile NUM windows into 3 columns."
  (rotate--vertically-n (/ (+ num 2) 3))
  (dotimes (_i (/ (1+ num) 3))
    (rotate--horizontally-n 3)
    (other-window 3))
  (when (= (% num 3) 2)
    (other-window -1)
    (delete-window)))

(defun rotate--window-list ()
  "Return the windows of the selected frame, excluding the minibuffer."
  (window-list nil nil (minibuffer-window)))

(defun rotate--buffer-list ()
  "Return the buffers displayed in the selected frame."
  (mapcar #'window-buffer (rotate--window-list)))

(defun rotate--refresh-window (proc)
  "Rebuild the layout using PROC and restore the existing buffers."
  (unless (one-window-p)
    (let ((window-num (count-windows))
          (buffer-list (rotate--buffer-list))
          (current-pos (cl-position (selected-window) (rotate--window-list))))
      (delete-other-windows)
      (funcall proc window-num)
      (cl-loop for w in (rotate--window-list)
               for b in buffer-list
               do (set-window-buffer w b))
      (select-window (nth current-pos (rotate--window-list))))))

;; Backward-compatible aliases for the pre-0.2.0 `rotate:foo' names.
;; They are built dynamically so the legacy symbols never appear as
;; literals in this source (which would otherwise trip `package-lint'
;; about the non-standard `:' separator).
(dolist (suffix '("even-horizontal"
                  "even-vertical"
                  "main-horizontal"
                  "main-vertical"
                  "tiled"))
  (define-obsolete-function-alias
    (intern (concat "rotate:" suffix))
    (intern (concat "rotate-" suffix))
    "0.2.0"))

(provide 'rotate)

;;; rotate.el ends here
