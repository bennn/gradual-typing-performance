#lang racket/base

(require require-typed-check)

(require "zo-shell.rkt")

;; Stress tests: search entire bytecode for the fairly-common branch struct
(define SELF-TEST '("../base/zo-shell.zo" "../base/zo-find.zo" "../base/zo-string.zo" "../base/zo-transition.zo"))
(define self-test
  (for/list ([fn (in-list SELF-TEST)])
    (zo-read fn)))

;(define SMALL-TEST "../base/hello-world.zo")
;(define (small-test)
;  (init (vector SMALL-TEST "branch")))
;
;(define LARGE-TEST "../base/streams.zo")
;(define (large-test)
;  (init (vector LARGE-TEST "branch")))

;; -----------------------------------------------------------------------------

(define (main t*)
  (for ([ctx (in-list t*)])
    (init (vector ctx "branch"))))

(time (main self-test)) ; 1316ms
;(time (main small-test)) ;
;(time (main large-test)) ; 63ms
