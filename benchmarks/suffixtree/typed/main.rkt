#lang typed/racket/base

(require require-typed-check
 (only-in racket/file file->lines file->string))

(require/typed/check "lcs.rkt"
  [longest-common-substring (-> String String String)])

(define LARGE_TEST (file->lines "../base/prufock.txt"))
;(define SMALL_TEST "../base/hunt.txt")
;(define KCFA_TYPED "../base/kcfa-typed.rkt")

;; LCS on all pairs of lines in a file
(: main (-> (Listof String) Void))
(define (main lines)
  (for* ([a lines] [b lines])
    (longest-common-substring a b))
  (void))

;(time (main SMALL_TEST)) ; 110ms
(time (main LARGE_TEST)) ; 1900ms
;(time (main KCFA_TYPED)) ; 16235ms
