#lang racket/base

(require require-typed-check
         (only-in racket/file file->lines file->string))

(require "lcs.rkt")

(define LARGE_TEST (file->lines "../base/prufock.txt"))
;(define SMALL_TEST (file->lines "../base/hunt.txt"))
;(define KCFA_TYPED "../base/kcfa-typed.rkt")

;; LCS on all pairs of lines in a file
(define (main lines)
  (for* ([a lines] [b lines])
    (longest-common-substring a b))
  (void))

;(time (main SMALL_TEST)) ;150ms
(time (main LARGE_TEST)) ; 2500ms
;(time (main KCFA_TYPED)) ; 22567ms
