#lang typed/racket/base

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
  require-typed-check
  (only-in racket/file file->value)
)
(require/typed/check "bitstring.rkt"
  [log2 (-> Index Index)]
  [natural->bitstring (-> Index #:pad Index String)])

;; =============================================================================

(define-syntax-rule (spreadsheet-error sym)
  (error 'from-rktd (format "Unknown spreadsheet format '~a'" sym)))

;; Convert a symbol representing a spreadsheet format into a file
;; extension for the spreadsheet.
(: symbol->extension (-> Symbol String))
(define (symbol->extension sym)
  (case sym
    [(csv tab) (string-append "." (symbol->string sym))]
    [else (spreadsheet-error sym)]))

;; Convert a symbol to a spreadsheet column separator.
(: symbol->separator (-> Symbol String))
(define (symbol->separator sym)
  (case sym
    [(csv) ","]
    [(tab) "\t"]
    [else (spreadsheet-error sym)]))

;; -----------------------------------------------------------------------------

;; (vector->spreadsheet rktd-vector out-file sep)
;; Copy the data from `rktd-vector` to the file `out-file`.
;; Format the data to a human-readable spreadsheet using `sep` to separate rows
(: vector->spreadsheet (-> (Vectorof (Listof Index)) String Void))
(define (vector->spreadsheet vec sep)
  (define num-configs (vector-length vec))
  (define num-runs (length (vector-ref vec 0)))
  (for ([(row n) (in-indexed vec)])
    (void (natural->bitstring (cast n Index) #:pad (log2 num-configs)))))

;; Print the rktd data stored in file `input-filename` to a spreadsheet.
(: rktd->spreadsheet (->* [(Vectorof (Listof Index))] (#:format Symbol) Void))
(define (rktd->spreadsheet vec #:format [format 'tab])
  (define suffix (symbol->extension format))
  (define sep (symbol->separator format))
  (vector->spreadsheet vec sep))
