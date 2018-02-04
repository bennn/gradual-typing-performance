#lang racket/base

(require (only-in "eval.rkt"
  forth-eval*
))

;; =============================================================================

(define ln*
  (with-input-from-file "../base/history.txt"
    (lambda () (for/list ((x (in-lines))) x))))

(define (main ln*)
  (let-values ([(_e _s) (forth-eval* ln*)]) (void))
  (void))

(time (main ln*))
