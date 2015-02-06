#lang typed/racket/base

(require (only-in "client.rkt" client)
         (only-in "server.rkt" server))

;; ---------------------------------------------------------------------------------------------------

(: main (-> Natural Void))
(define (main arg)
  (thread (lambda () (client arg)))
  (server))

(time (main 200000))