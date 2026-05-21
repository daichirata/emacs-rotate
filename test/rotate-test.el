;;; rotate-test.el --- Tests for rotate.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with:
;;   emacs -Q --batch -L . -l test/rotate-test.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'rotate)

(defun rotate-test--with-fresh-frame (body)
  "Run BODY with a clean window state on a frame large enough to split."
  (set-frame-size (selected-frame) 200 80)
  (delete-other-windows)
  (set-frame-parameter nil 'rotate--count nil)
  (switch-to-buffer (get-buffer-create " *rotate-test-base*"))
  (unwind-protect
      (funcall body)
    (delete-other-windows)))

(defun rotate-test--make-windows (n)
  "Create N windows in the selected frame, each showing a distinct buffer.
Return the list of buffers in window order."
  (delete-other-windows)
  (let ((buffers (cl-loop for i from 1 to n
                          collect (get-buffer-create
                                   (format " *rotate-test-%d*" i)))))
    (set-window-buffer (selected-window) (car buffers))
    (dolist (buf (cdr buffers))
      (select-window (split-window-horizontally))
      (set-window-buffer (selected-window) buf))
    (select-window (frame-first-window))
    buffers))

(ert-deftest rotate-test-horizontally-n ()
  "`rotate--horizontally-n' should produce N windows."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate--horizontally-n 3)
     (should (= (count-windows) 3)))))

(ert-deftest rotate-test-vertically-n ()
  "`rotate--vertically-n' should produce N windows."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate--vertically-n 4)
     (should (= (count-windows) 4)))))

(ert-deftest rotate-test-tiled-n ()
  "`rotate--tiled-n' should produce N windows for various counts."
  (rotate-test--with-fresh-frame
   (lambda ()
     (dolist (n '(2 4 5 6 7 8 9))
       (delete-other-windows)
       (rotate--tiled-n n)
       (should (= (count-windows) n))))))

(ert-deftest rotate-test-even-horizontal-preserves-count ()
  "`rotate-even-horizontal' should keep the number of windows."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 3)
     (rotate-even-horizontal)
     (should (= (count-windows) 3)))))

(ert-deftest rotate-test-even-horizontal-preserves-buffers ()
  "`rotate-even-horizontal' should preserve the displayed buffers."
  (rotate-test--with-fresh-frame
   (lambda ()
     (let ((buffers (rotate-test--make-windows 3)))
       (rotate-even-horizontal)
       (should (equal (rotate--buffer-list) buffers))))))

(ert-deftest rotate-test-rotate-window-rotates-buffers ()
  "`rotate-window' should rotate the buffers across the windows."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 3)
     (let ((before (mapcar #'buffer-name (rotate--buffer-list))))
       (rotate-window)
       (let ((after (mapcar #'buffer-name (rotate--buffer-list))))
         (should (equal (sort (copy-sequence before) #'string<)
                        (sort (copy-sequence after) #'string<)))
         (should-not (equal before after)))))))

(ert-deftest rotate-test-layout-advances-frame-counter ()
  "`rotate-layout' should advance the per-frame counter."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 2)
     (set-frame-parameter nil 'rotate--count 0)
     (rotate-layout)
     (should (= (rotate--count) 1))
     (rotate-layout)
     (should (= (rotate--count) 2)))))

(ert-deftest rotate-test-layout-wraps-around ()
  "`rotate-layout' should wrap the counter when it reaches the end."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 2)
     (set-frame-parameter nil 'rotate--count
                          (1- (length rotate-functions)))
     (rotate-layout)
     (should (= (rotate--count) 0)))))

(ert-deftest rotate-test-skip-dedicated-windows-off ()
  "By default dedicated windows are included in `rotate--window-list'."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 3)
     (let ((rotate-skip-dedicated-windows nil)
           (dedicated (frame-first-window)))
       (set-window-dedicated-p dedicated t)
       (unwind-protect
           (should (= (length (rotate--window-list)) 3))
         (set-window-dedicated-p dedicated nil))))))

(ert-deftest rotate-test-layout-stable-with-protected-window ()
  "Repeated `rotate-layout' calls must not keep growing the layout when
a sidebar-style window protected by `no-delete-other-windows' is
present.  Regression test for the bug where the count of windows
increased by one on every invocation."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 3)
     (let ((sidebar (frame-first-window)))
       (set-window-parameter sidebar 'no-delete-other-windows t)
       (set-window-dedicated-p sidebar t)
       (unwind-protect
           (let ((rotate-skip-dedicated-windows t))
             ;; Make sure we are rotating from one of the eligible
             ;; windows, not the sidebar.
             (select-window (next-window sidebar))
             (let ((before (count-windows)))
               (dotimes (_ 5) (rotate-layout))
               (should (= (count-windows) before))))
         (set-window-dedicated-p sidebar nil)
         (set-window-parameter sidebar 'no-delete-other-windows nil))))))

(ert-deftest rotate-test-skip-dedicated-windows-on ()
  "When `rotate-skip-dedicated-windows' is non-nil, dedicated windows are skipped."
  (rotate-test--with-fresh-frame
   (lambda ()
     (rotate-test--make-windows 3)
     (let ((rotate-skip-dedicated-windows t)
           (dedicated (frame-first-window)))
       (set-window-dedicated-p dedicated t)
       (unwind-protect
           (progn
             (should (= (length (rotate--window-list)) 2))
             (should-not (memq dedicated (rotate--window-list))))
         (set-window-dedicated-p dedicated nil))))))

(ert-deftest rotate-test-obsolete-aliases ()
  "Legacy `rotate:foo' names should still resolve to the new functions."
  (should (eq (symbol-function 'rotate:even-horizontal)
              'rotate-even-horizontal))
  (should (eq (symbol-function 'rotate:tiled)
              'rotate-tiled)))

(provide 'rotate-test)

;;; rotate-test.el ends here
