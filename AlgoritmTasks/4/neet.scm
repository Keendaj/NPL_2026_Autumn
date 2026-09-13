(define (matrix-ref matrix cols i)
  (vector-ref (vector-ref matrix (quotient i cols))
              (remainder i cols)))

(define (search-matrix matrix target)
  (let* ((rows  (vector-length matrix))
         (cols  (vector-length (vector-ref matrix 0)))
         (total (* rows cols)))
    (define (binary-search low high)
      (if (> low high)
          #f
          (let* ((mid   (quotient (+ low high) 2))
                 (value (matrix-ref matrix cols mid)))
            (cond
              ((= value target) #t)
              ((< value target) (binary-search (+ mid 1) high))
              (else             (binary-search low (- mid 1)))))))
    (if (= total 0)
        #f
        (binary-search 0 (- total 1)))))

(define (rows->matrix rows-list)
  (list->vector (map list->vector rows-list)))

(define (report matrix-data target expected)
  (let* ((matrix (rows->matrix matrix-data))
         (result (search-matrix matrix target))
         (status (if (eq? result expected) "OK  " "FAIL")))
    (display status) (display " target=") (display target)
    (display " -> ") (display result)
    (newline)))

(report '((1 3 5 7) (10 11 16 20) (23 30 34 60)) 3  #t)  
(report '((1 3 5 7) (10 11 16 20) (23 30 34 60)) 13 #f)  
(report '((1))                                    1  #t) 
(report '((1))                                    2  #f) 
(report '((1 3))                                  3  #t)  
(report '((1) (3))                                3  #t) 