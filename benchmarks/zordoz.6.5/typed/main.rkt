#lang typed/racket/base

(require require-typed-check
         "../base/typed-zo-structs.rkt")

(require/typed/check "zo-shell.rkt"
  [zo-read (-> Path-String zo)]
  [init (-> (Vector zo String) Void)])

;; Stress tests: search entire bytecode for the fairly-common branch struct
(define SELF-TEST '("../base/zo-shell.zo" "../base/zo-find.zo" "../base/zo-string.zo" "../base/zo-transition.zo"))
(define self-test : (Listof zo)
  (for/list : (Listof zo) ([fn (in-list SELF-TEST)])
    (zo-read fn)))

;(define SMALL-TEST "../base/hello-world.zo")
;(define (small-test)
;  (init (vector SMALL-TEST "branch")))
;
;(define LARGE-TEST "../base/streams.zo")
;(define (large-test)
;  (init (vector LARGE-TEST "branch")))

;; -----------------------------------------------------------------------------

(: main (-> (Listof zo) Void))
(define (main t*)
  (for ([ctx (in-list t*)])
    (init (vector ctx "branch"))))

(time (main self-test)) ; 1330ms
;(time (main small-test)) ;
;(time (main large-test)) ;
