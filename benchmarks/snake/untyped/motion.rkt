#lang racket  
(require "data.rkt"
         "const.rkt"
         "motion-help.rkt")

(provide reset!)
(define r (make-pseudo-random-generator)) 
(define (reset!)
  (void))

(define my-random
  (let ([num*
         (with-input-from-file "../base/motion-random.rktd"
           (lambda ()
             (for/list ([ln (in-lines)])
               (string->number ln))))])
    (lambda (a b)
      (begin0 (car num*) (set! num* (cdr num*))))))

;; world->world : World -> World
(define (world->world w)
  (cond [(eating? w) (snake-eat w)]
        [else
         (world (snake-slither (world-snake w))
                (world-food w))]))
;; eating? : World -> Boolean
;; Is the snake eating the food in the world.
(define (eating? w)
  (posn=? (world-food w)
          (car (snake-segs (world-snake w)))))
;; snake-change-direction : Snake Direction -> Snake
;; Change the direction of the snake.
(define (snake-change-direction snk dir)
  (snake dir
         (snake-segs snk)))
;; world-change-dir : World Direction -> World
;; Change direction of the world.
(define (world-change-dir w dir)
  (world (snake-change-direction (world-snake w) dir)
         (world-food w)))
;; snake-eat : World -> World
;; Eat the food and generate a new one.
(define (snake-eat w)
  (define i (add1 (my-random (sub1 BOARD-WIDTH) r)))
  (define j (add1 (my-random (sub1 BOARD-HEIGHT) r)))
  (world (snake-grow (world-snake w))
         (posn i j)
         
         #;(posn (- BOARD-WIDTH 1) (- BOARD-HEIGHT 1))))
(provide
 world-change-dir
 world->world)
