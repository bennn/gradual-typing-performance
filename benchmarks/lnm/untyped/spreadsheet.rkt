#lang racket/base

;; Convert a dataset to a spreadsheet.

;; Printed spreadsheets have:
;; - A title row, counting the number of runs for each variation
;; - A data row for each variation.
;;   The leftmost column is the configuration's bitstring, the rest of the
;;   columns are experimental results.

(provide
  rktd->spreadsheet
)
;; ----------------------------------------------------------------------------

(require
  (only-in "bitstring.rkt" log2 natural->bitstring)
)

;; =============================================================================

(define-syntax-rule (spreadsheet-error sym)
  (error 'from-rktd (format "Unknown spreadsheet format '~a'" sym)))

;; Convert a symbol representing a spreadsheet format into a file
;; extension for the spreadsheet.
;; (: symbol->extension (-> Symbol String))
(define (symbol->extension sym)
  (case sym
    [(csv tab) (string-append "." (symbol->string sym))]
    [else (spreadsheet-error sym)]))

;; Convert a symbol to a spreadsheet column separator.
;; (: symbol->separator (-> Symbol String))
(define (symbol->separator sym)
  (case sym
    [(csv) ","]
    [(tab) "\t"]
    [else (spreadsheet-error sym)]))

;; -----------------------------------------------------------------------------

(define (vector->spreadsheet vec sep)
  (define num-configs (vector-length vec))
  (define num-runs (length (vector-ref vec 0)))
  (for ([(row n) (in-indexed vec)])
    (void (natural->bitstring n #:pad (log2 num-configs)))))

;; Print the rktd data stored in file `input-filename` to a spreadsheet.
;; (: rktd->spreadsheet (->* (Path-String) (#:format Symbol) String))
(define (rktd->spreadsheet vec
                             #:format [format 'tab])
  (define suffix (symbol->extension format))
  (define sep (symbol->separator format))
  (vector->spreadsheet vec sep))
