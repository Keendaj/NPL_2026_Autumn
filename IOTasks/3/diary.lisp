(defparameter *db-path* "diary.db")

(defun today-string ()
  (multiple-value-bind (sec min hour day month year) (get-decoded-time)
    (declare (ignore sec min hour))
    (format nil "~4,'0D-~2,'0D-~2,'0D" year month day)))

(defun trim (line)
  (string-trim '(#\Space #\Tab #\Return #\Newline) line))

(defun valid-date-p (s)
  (and (stringp s)
       (= (length s) 10)
       (char= (char s 4) #\-)
       (char= (char s 7) #\-)
       (every (lambda (i) (digit-char-p (char s i))) '(0 1 2 3 5 6 8 9))
       (let ((month (parse-integer s :start 5 :end 7))
             (day   (parse-integer s :start 8 :end 10)))
         (and (<= 1 month 12) (<= 1 day 31)))))

(defun ask (fmt &rest args)
  (apply #'format t fmt args)
  (finish-output)
  (let ((line (read-line *standard-input* nil nil)))
    (and line (trim line))))

(defun ask-date (what)
  (let ((raw (ask "~A (ГГГГ-ММ-ДД, Enter = сегодня ~A): " what (today-string))))
    (cond ((null raw) nil)
          ((string= raw "") (today-string))
          ((valid-date-p raw) raw)
          (t (format t "Некорректная дата.~%") nil))))

(defun read-body ()
  (format t "Текст записи, завершить строкой с одной точкой:~%")
  (finish-output)
  (let ((lines '()))
    (loop for line = (read-line *standard-input* nil nil)
          until (or (null line) (string= (trim line) "."))
          do (push line lines))
    (format nil "~{~A~^~%~}" (nreverse lines))))

(defun load-entries ()
  (if (probe-file *db-path*)
      (with-open-file (in *db-path* :external-format :utf-8)
        (or (read in nil nil) '()))
      '()))

(defun save-entries (entries)
  (with-open-file (out *db-path* :direction :output
                                 :if-exists :supersede
                                 :if-does-not-exist :create
                                 :external-format :utf-8)
    (prin1 entries out)
    (terpri out))
  entries)

(defun sorted (entries)
  (sort (copy-list entries) #'string< :key #'first))

(defun show-entry (entry)
  (destructuring-bind (date title body) entry
    (format t "~&-- ~A -- ~A~%~A~%" date title body)))

(defun show-all (entries label)
  (if (null entries)
      (format t "~A: ничего не найдено.~%" label)
      (progn
        (format t "~A: записей ~D.~%" label (length entries))
        (mapc #'show-entry entries)))
  (values))

(defun cmd-add (entries)
  (let ((date (ask-date "Дата записи")))
    (if (null date)
        entries
        (let* ((title (or (ask "Заголовок: ") ""))
               (body  (read-body))
               (new   (sorted (cons (list date title body) entries))))
          (save-entries new)
          (format t "Запись за ~A сохранена.~%" date)
          new))))

(defun cmd-list (entries)
  (show-all entries "Все записи")
  entries)

(defun cmd-by-date (entries)
  (let ((date (ask-date "Искомая дата")))
    (when date
      (show-all (remove-if-not (lambda (e) (string= (first e) date)) entries)
                (format nil "Записи за ~A" date))))
  entries)

(defun cmd-by-range (entries)
  (let ((from (ask-date "Начало периода")))
    (when from
      (let ((to (ask-date "Конец периода")))
        (when to
          (show-all (remove-if-not (lambda (e)
                                     (and (string<= from (first e))
                                          (string<= (first e) to)))
                                   entries)
                    (format nil "Записи с ~A по ~A" from to))))))
  entries)

(defun cmd-by-text (entries)
  (let ((needle (ask "Подстрока для поиска: ")))
    (when (and needle (string/= needle ""))
      (show-all (remove-if-not (lambda (e)
                                 (or (search needle (second e) :test #'char-equal)
                                     (search needle (third e) :test #'char-equal)))
                               entries)
                (format nil "Записи со словом ~S" needle))))
  entries)

(defun cmd-delete (entries)
  (let ((date (ask-date "Удалить записи за дату")))
    (if (null date)
        entries
        (let ((rest (remove-if (lambda (e) (string= (first e) date)) entries)))
          (format t "Удалено записей: ~D.~%" (- (length entries) (length rest)))
          (save-entries rest)))))

(defun menu ()
  (format t "~%1 добавить  2 все записи  3 поиск по дате  4 поиск по периоду~%")
  (format t "5 поиск по тексту  6 удалить по дате  0 выход~%"))

(defun main ()
  (format t "~&=== Дневник === (файл ~A)~%" *db-path*)
  (let ((entries (load-entries)))
    (format t "Загружено записей: ~D.~%" (length entries))
    (loop
      (menu)
      (let ((cmd (ask "> ")))
        (cond ((or (null cmd) (string= cmd "0"))
               (format t "~&До встречи.~%")
               (return))
              ((string= cmd "1") (setf entries (cmd-add entries)))
              ((string= cmd "2") (setf entries (cmd-list entries)))
              ((string= cmd "3") (setf entries (cmd-by-date entries)))
              ((string= cmd "4") (setf entries (cmd-by-range entries)))
              ((string= cmd "5") (setf entries (cmd-by-text entries)))
              ((string= cmd "6") (setf entries (cmd-delete entries)))
              (t (format t "Неизвестная команда.~%")))))))

(main)
