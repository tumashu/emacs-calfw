;;; calfw-cal.el --- calendar view for emacs diary -*- lexical-binding: t -*-

;; Copyright (C) 2011  SAKURAI Masashi

;; Author: SAKURAI Masashi <m.sakurai at kiwanami.net>
;; Keywords: calendar
;; Package-Requires: ((cl-lib "0.5")(calfw "1.6"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Display diary items in the calfw buffer.

;; (require 'calfw-cal)
;;
;; M-x calfw-cal-open-calendar

;; Key binding
;; i : insert an entry on the date
;; RET or Click : jump to the entry
;; q : kill-buffer


;; Thanks for furieux's initial code.

;;; Code:

(require 'cl-lib)
(require 'calfw)
(require 'calendar)

(defvar calfw-cal-diary-regex
  (let ((time   "[[:digit:]]\\{2\\}:[[:digit:]]\\{2\\}")
        (blanks "[[:blank:]]*"))
    (concat "\\(" time "\\)?"
            "\\(?:" blanks "-" blanks "\\(" time "\\)\\)?"
            blanks "\\(.*\\)"))
  "Regex extracting start/end time and title from a diary string")

(defun calfw-cal-entry-to-event (date string)
  "[internal] Add text properties to string, allowing calfw to act on it."
  (let* ((lines (split-string
                 (replace-regexp-in-string
                  "[\t ]+" " " (calfw-trim string))
                 "\n"))
         (first (car lines))
         (desc  (mapconcat 'identity (cdr lines) "\n"))
         (title (progn
                  (string-match calfw-cal-diary-regex first)
                  (match-string 3 first)))
         (start (match-string 1 first))
         (end   (match-string 2 first))
         (properties (list 'mouse-face 'highlight
                           'help-echo string
                           'calfw-marker (copy-marker (point-at-bol)))))
    (make-calfw-event :title       (apply 'propertize title properties)
                      :start-date  date
                      :start-time  (when start
                                     (calfw-parse-str-time start))
                      :end-time    (when end
                                     (calfw-parse-str-time end))
                      :description (apply 'propertize desc properties))))

(defun calfw-cal-onclick ()
  "Jump to the clicked diary item."
  (interactive)
  (let ((marker (get-text-property (point) 'calfw-marker)))
    (when (and marker (marker-buffer marker))
      (switch-to-buffer (marker-buffer marker))
      (goto-char (marker-position marker)))))

(defvar calfw-cal-text-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map [mouse-1] 'calfw-cal-onclick)
    (define-key map (kbd "<return>") 'calfw-cal-onclick)
    map)
  "key map on the calendar item text.")

(defun calfw-cal-schedule-period-to-calendar (begin end)
  "[internal] Return calfw calendar items between BEGIN and END
from the diary schedule data."
  (let ((all (diary-list-entries
              begin
              (1+ (calfw-days-diff begin end)) t))
        non-periods
        periods)
    (cl-loop for i in all
             for _date = (car i)
             for title = (nth 1 i)
             for date-spec = (nth 2 i)
             for _dmarker = (nth 3 i)
             for pspec = (cons date-spec title)
             do
             (if (string-match "%%(diary-block" date-spec)
                 (unless (member pspec periods)
                   (push pspec periods))
               (push i non-periods)))
    (append
     (cl-loop for (date string . rest)
              in non-periods
              collect (calfw-cal-entry-to-event date string))
     (list (cons 'periods
                 (cl-map 'list
                         #'(lambda (period)
                             (let ((spec (read (substring (car period) 2))))
                               (cond
                                ((eq calendar-date-style 'american)
                                 (list
                                  (list (nth 1 spec)
                                        (nth 2 spec)
                                        (nth 3 spec))
                                  (list (nth 4 spec)
                                        (nth 5 spec)
                                        (nth 6 spec))
                                  (cdr period)))
                                ((eq calendar-date-style 'european)
                                 (list
                                  (list (nth 2 spec)
                                        (nth 1 spec)
                                        (nth 3 spec))
                                  (list (nth 5 spec)
                                        (nth 4 spec)
                                        (nth 6 spec))
                                  (cdr period)))
                                ((eq calendar-date-style 'iso)
                                 (list
                                  (list (nth 2 spec)
                                        (nth 3 spec)
                                        (nth 1 spec))
                                  (list (nth 5 spec)
                                        (nth 6 spec)
                                        (nth 4 spec))
                                  (cdr period))))))
                         periods))))))

(defvar calfw-cal-schedule-map
  (calfw-define-keymap
   '(("q" . kill-buffer)
     ("i" . calfw-cal-from-calendar)))
  "Key map for the calendar buffer.")

(defun calfw-cal-create-source (&optional color)
  "Create diary calendar source."
  (make-calfw-source
   :name "calendar diary"
   :color (or color "SaddleBrown")
   :data 'calfw-cal-schedule-period-to-calendar))

(defun calfw-cal-open-calendar ()
  "Open the diary schedule calendar in the new buffer."
  (interactive)
  (save-excursion
    (let* ((source1 (calfw-cal-create-source))
           (cp (calfw-create-calendar-component-buffer
                :view 'month
                :custom-map calfw-cal-schedule-map
                :contents-sources (list source1))))
      (switch-to-buffer (calfw-cp-get-buffer cp)))))

(defun calfw-cal-from-calendar ()
  "Insert a new item. This command should be executed on the calfw calendar."
  (interactive)
  (let* ((mdy (calfw-cursor-to-nearest-date))
         (m (calendar-extract-month mdy))
         (d (calendar-extract-day   mdy))
         (y (calendar-extract-year  mdy)))
    (diary-make-entry (calendar-date-string (calfw-date m d y) t t))))

(provide 'calfw-cal)

;;; calfw-cal.el ends here
