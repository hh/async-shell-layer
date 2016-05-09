

(defun org-babel-async-execute:shell ()
  "Execute the python src-block at point asynchronously.
  :var headers are supported.
  :results output is all that is supported for output.

  A new window will pop up showing you the output as it appears,
  and the output in that window will be put in the RESULTS section
  of the code block."

  ;; http://kitchingroup.cheme.cmu.edu/blog/2015/11/20/Asynchronously-running-python-blocks-in-org-mode/
  (interactive)
  (require 'ob-shell)
  (let* ((current-file (buffer-file-name))
         (uuid (format "%04x%04x-%04x-%04x-%04x-%06x%06x"
                       (random (expt 16 4))
                       (random (expt 16 4))
                       (random (expt 16 4))
                       (random (expt 16 4))
                       (random (expt 16 4))
                       (random (expt 16 6))
                       (random (expt 16 6))))
         (code (org-element-property :value (org-element-context)))
         (temporary-file-directory ".")
         (tempfile (make-temp-file "sh-"))
         (pbuffer (format "*%s*" uuid))
         (varcmds (org-babel-variable-assignments:shell
                   (nth 2 (org-babel-get-src-block-info))))
         process)
    ;; get rid of old results, and put a place-holder for the new results to
    ;; come.
    (org-babel-remove-result)
    (save-excursion
      (re-search-forward "#\\+END_SRC")
      (insert (format
               "\n\n#+RESULTS: %s\n: %s"
               (or (org-element-property :name (org-element-context))
                   "")
               uuid)))

    ;; open the results buffer to see the results in.
    (switch-to-buffer-other-window pbuffer)

    ;; Create temp file containing the code.
    (with-temp-file tempfile
      ;; if there are :var headers insert them.
      (dolist (cmd varcmds)
        (insert cmd)
        (insert "\n"))
      (insert code))

    ;; run the code
    (setq process (start-process
                   uuid
                   pbuffer
                   "bash"
                   tempfile))

    ;; when the process is done, run this code to put the results in the
    ;; org-mode buffer.
    (set-process-sentinel
     process
     `(lambda (process event)
        (save-window-excursion
          (save-excursion
            (save-restriction
              (with-current-buffer (find-file-noselect ,current-file)
                (goto-char (point-min))
                (re-search-forward ,uuid)
                (beginning-of-line)
                (kill-line)
                (insert
                 (mapconcat
                  (lambda (x)
                    (format ": %s" x))
                  (butlast (split-string
                            (with-current-buffer
                                ,pbuffer
                              (buffer-string))
                            "\n"))
                  "\n"))))))
        ;; delete the results buffer then delete the tempfile.
        ;; finally, delete the process.
        (when (get-buffer ,pbuffer)
          (kill-buffer ,pbuffer)
          (delete-window))
        (delete-file ,tempfile)
        (delete-process process)))))

