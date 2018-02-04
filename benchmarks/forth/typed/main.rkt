#lang typed/racket/base

(require
  require-typed-check
  "../base/command-types.rkt")
(require/typed/check "eval.rkt"
  (forth-eval* (-> (Listof String) (Values Any Any)))
)

;; =============================================================================

(define ln*
  (with-input-from-file (ann "../base/history.txt" Path-String)
    (lambda () (for/list : (Listof String) ((x (in-lines))) x))))

(: main (-> (Listof String) Void))
(define (main ln*)
  (let-values ([(_e _s) (forth-eval* ln*)]) (void))
  (void))

(time (main ln*))
