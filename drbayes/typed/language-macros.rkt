#lang racket/base

(require (for-syntax racket/base
                     racket/list
                     racket/math
                     syntax/parse
                     racket/syntax)
         racket/list
         racket/math
         racket/promise
         (for-template "language-functions.rkt"
                       racket/base
                       racket/list
                       racket/math)
         (only-in typed/racket/base : assert -> case-> Any Promise let let*)
         racket/stxparam
         (for-syntax (only-in "language-functions.rkt" syntax-const))
         "language-functions.rkt"
         "language-drbayes-dispatcher.rkt"
         "language-parameterized-expansion.rkt"
         "arrow-meaning-adapted.rkt"
         ;; "set.rkt"
         "arrow-proc-arrow.rkt"
         )
(provide define/drbayes struct/drbayes drbayes drbayes-run
         fail random store-uniform
         quote null empty
         condition
         and or not
         car cdr real? null? pair? boolean?
         exp log expm1 log1p abs sqr sqrt acos asin
         floor ceiling
         zero? negative? positive? nonnegative? nonpositive?
         partial-cos partial-sin
         cons + * - / < <= > >= =
         normal-inv-cdf cauchy-inv-cdf uniform-inv-cdf
         list uniform normal cauchy
         const
         lazy
         if cond else strict-if strict-cond
         let let*
         list-ref scale translate boolean
         equal? tag? tag untag)

(module typed-defs typed/racket/base
  (provide (all-defined-out))

  (require "set.rkt"
           "arrow.rkt")

  (: drbayes-run (meaning -> Value))
  (define (drbayes-run e)
    ((meaning-proc e) null))
  )

(require (submod "." typed-defs))

(begin-for-syntax
  (struct first-order-function (transformer) #:property prop:procedure 0)
  (struct bound-local-identifier (transformer) #:property prop:procedure 0)

  (define-syntax-class real
    #:description "literal real constant"
    (pattern x #:when (real? (syntax->datum #'x))))

  (define-syntax-class constant
    #:description "literal constant"
    #:attributes (expression)
    #:literals (quote null empty)
    (pattern (~or null empty) #:attr expression #'null/arr)
    (pattern (~or x:boolean x:number x:str x:char (quote x))
             #:attr expression #`(const/arr (quote #,(syntax-const #'x))))
    )

  (define-syntax-class primitive-transformer
    #:description "primitive syntax transformer"
    #:attributes (expression)
    #:literals (condition
                + - * /
                < <= > >= =
                and or not
                list
                uniform normal cauchy)
    (pattern (condition a:expr b:expr) #:attr expression #'(strict-if b a (fail)))
    ;; 0-ary operators
    (pattern (+) #:attr expression #'0)
    (pattern (*) #:attr expression #'1)
    ;; Simple folding binary operators
    (pattern ((~and op (~or + - * /)) e1 e2 e3 es ...)
             #:attr expression #'(op (op e1 e2) e3 es ...))
    ;; Conjunctive folding binary operators
    (pattern ((~and op (~or < <= > >= =)) e1 e2 e3 es ...)
             #:attr expression #'(let ([x e2]) (and (op e1 x) (op x e3 es ...))))
    ;; Folding disjunction
    (pattern (or) #:attr expression #'#f)
    (pattern (or e:expr) #:attr expression #'e)
    (pattern (or e0:expr es:expr ...) #:attr expression #'(strict-if e0 #t (or es ...)))
    ;; Folding conjunction
    (pattern (and) #:attr expression #'#t)
    (pattern (and e:expr) #:attr expression #'e)
    (pattern (and e0:expr es:expr ...) #:attr expression #'(strict-if e0 (and es ...) #f))
    ;; Negation
    (pattern (not e:expr) #:attr expression #'(strict-if e #f #t))
    ;; Lists
    (pattern (list) #:attr expression #'null)
    (pattern (list e0:expr es:expr ...) #:attr expression #'(cons e0 (list es ...)))
    ;; Distributions
    (pattern (normal μ:expr σ:expr)
             #:attr expression #'(+ μ (* σ (normal-inv-cdf (store-uniform)))))
    (pattern (cauchy m:expr s:expr)
             #:attr expression #'(+ m (* s (cauchy-inv-cdf (store-uniform)))))
    (pattern (uniform a:expr b:expr)
             #:attr expression #'(let ([c a]) (+ c (* (- b c) (random)))))
    )

  (define-syntax-class 0ary-primitive
    #:description "zero-argument primitive operator"
    #:attributes (computation)
    #:literals (fail store-uniform random)
    (pattern fail #:attr computation #'(fail/arr))
    (pattern random #:attr computation #'((store-uniform/arr) . >>>/arr . (uniform-inv-cdf/arr)))
    (pattern store-uniform #:attr computation #'(store-uniform/arr))
    )

  (define-syntax-class 1ary-primitive
    #:description "one-argument primitive operator"
    #:attributes (computation)
    #:literals (+ - * /
                  car cdr real? null? pair? boolean?
                  exp log expm1 log1p abs sqr sqrt acos asin floor ceiling round truncate
                  zero? negative? positive? nonnegative? nonpositive?
                  partial-cos partial-sin
                  normal-inv-cdf cauchy-inv-cdf uniform-inv-cdf)
    (pattern + #:attr computation #'(restrict/arr reals))
    (pattern - #:attr computation #'(neg/arr))
    (pattern * #:attr computation #'(restrict/arr reals))
    (pattern / #:attr computation #'(recip/arr))
    (pattern car #:attr computation #'(fst/arr))
    (pattern cdr #:attr computation #'(snd/arr))
    (pattern real? #:attr computation #'(real?/arr))
    (pattern null? #:attr computation #'(null?/arr))
    (pattern pair? #:attr computation #'(pair?/arr))
    (pattern boolean? #:attr computation #'(boolean?/arr))
    (pattern exp #:attr computation #'(exp/arr))
    (pattern log #:attr computation #'(log/arr))
    (pattern expm1 #:attr computation #'(expm1/arr))
    (pattern log1p #:attr computation #'(log1p/arr))
    (pattern abs #:attr computation #'(abs/arr))
    (pattern sqr #:attr computation #'(sqr/arr))
    (pattern sqrt #:attr computation #'(sqrt/arr))
    (pattern acos #:attr computation #'(acos/arr))
    (pattern asin #:attr computation #'(asin/arr))
    (pattern floor #:attr computation #'(floor/arr))
    (pattern ceiling #:attr computation #'(ceiling/arr))
    (pattern round #:attr computation #'(round/arr))
    (pattern truncate #:attr computation #'(truncate/arr))
    (pattern zero? #:attr computation #'(zero?/arr))
    (pattern negative? #:attr computation #'(negative?/arr))
    (pattern positive? #:attr computation #'(positive?/arr))
    (pattern nonnegative? #:attr computation #'(nonnegative?/arr))
    (pattern nonpositive? #:attr computation #'(nonpositive?/arr))
    (pattern partial-cos #:attr computation #'(partial-cos/arr))
    (pattern partial-sin #:attr computation #'(partial-sin/arr))
    (pattern uniform-inv-cdf #:attr computation #'(uniform-inv-cdf/arr))
    (pattern normal-inv-cdf #:attr computation #'(normal-inv-cdf/arr))
    (pattern cauchy-inv-cdf #:attr computation #'(cauchy-inv-cdf/arr))
    )

  (define-syntax-class 2ary-primitive
    #:description "two-argument primitive operator"
    #:attributes (computation)
    #:literals (+ - * / < <= > >= = equal?)
    (pattern + #:attr computation #'(+/arr))
    (pattern - #:attr computation #'(-/arr))
    (pattern * #:attr computation #'(*/arr))
    (pattern / #:attr computation #'(//arr))
    (pattern < #:attr computation #'(</arr))
    (pattern > #:attr computation #'(>/arr))
    (pattern <= #:attr computation #'(<=/arr))
    (pattern >= #:attr computation #'(>=/arr))
    (pattern = #:attr computation #'(=/arr))
    (pattern equal? #:attr computation #'(equal?/arr))
    )

  (define-syntax-class n+1-ary-primitive
    #:description "n+1-argument primitive operator"
    #:literals (- /)
    (pattern (~or - /)))

  (define-syntax-class n+2-ary-primitive
    #:description "n+2-argument primitive operator"
    #:literals (< <= > >= =)
    (pattern (~or < <= > >= =)))

  (define-syntax-class bad-primitive-application
    #:description "bad primitive application"
    #:attributes (message)
    (pattern (e:n+1-ary-primitive args ...)
             #:when (< 1 (length (syntax->list #'(args ...))))
             #:attr message "expected 1 or more arguments")
    (pattern (e:n+2-ary-primitive args ...)
             #:when (< 2 (length (syntax->list #'(args ...))))
             #:attr message "expected 2 or more arguments")
    (pattern (e:0ary-primitive args ...)
             #:when (not (= 0 (length (syntax->list #'(args ...)))))
             #:attr message "expected 0 arguments")
    (pattern (e:1ary-primitive args ...)
             #:when (not (= 1 (length (syntax->list #'(args ...)))))
             #:attr message "expected 1 argument")
    (pattern (e:2ary-primitive args ...)
             #:when (not (= 2 (length (syntax->list #'(args ...)))))
             #:attr message "expected 2 arguments")
    )

  (define-syntax-class let-binding
    #:description "[id  expr]"
    #:attributes (id expr)
    (pattern [id:id expr:expr]))

  (define-syntax-class boolean-expr-not-else
    #:description "boolean-expr (not else)"
    #:literals (else)
    (pattern (~and e:expr (~not else))))

  (define-syntax-class cond-case
    #:description "[boolean-expr  then-expr]"
    #:attributes (cond then)
    (pattern [(~and cond:expr _:boolean-expr-not-else) then:expr]))

  (define-syntax-class cond-else
    #:description "[else  else-expr]"
    #:attributes (expr)
    #:literals (else)
    (pattern [else  expr:expr]))

  (define-syntax-class if-expr
    #:description "(if boolean-expr then-expr else-expr)"
    #:attributes (cond then else)
    (pattern (_ cond:expr then:expr else:expr)))

  )  ; begin-for-syntax

(define-syntax-parameter let-depth 0)

(define-for-syntax make-bound-local-identifier
  (case-lambda
    [(old-d)
     (bound-local-identifier
      (λ (stx)
        (cond [(current-dispatcher-id #'drbayes-dispatcher)
               (define d (syntax-parameter-value #'let-depth))
               (define i (quasisyntax/loc stx (list-ref/arr #,(- d old-d))))
               (syntax-case stx () [(_ . args)  #`(#,i . args)] [_  i])]
              [else
               (raise-syntax-error 'drbayes "reference to DrBayes binding in Racket code" stx)])))]
    [(old-d idx)
     (bound-local-identifier
      (λ (stx)
        (cond [(current-dispatcher-id #'drbayes-dispatcher)
               (define d (syntax-parameter-value #'let-depth))
               (define i (quasisyntax/loc stx (>>>/arr (list-ref/arr #,(- d old-d))
                                                       (list-ref/arr #,idx))))
               (syntax-case stx () [(_ . args)  #`(#,i . args)] [_  i])]
              [else
               (raise-syntax-error 'drbayes "reference to DrBayes binding in Racket code" stx)])))]))

;; A `let' is transformed (partly) into a `let-syntax' with the result of calling this function as
;; its value
(define-for-syntax make-binding-transformer
  (case-lambda
    [(stx old-d)
     (quasisyntax/loc stx
       (make-bound-local-identifier #,old-d))]
    [(stx old-d idx)
     (quasisyntax/loc stx
       (make-bound-local-identifier #,old-d #,idx))]))

(define-syntax (interp stx)
  ;; Make sure `stx' has the source location of the inner expression; without this, there would be a
  ;; lot of (quasisyntax/loc stx (... #,(syntax/loc #'e (interp e)) ...)) in the following code
  (let ([stx  (syntax-case stx () [(_ e)  (syntax/loc #'e (interp e))])])
    (syntax-parse stx #:literals (const
                                  cons
                                  lazy
                                  if cond
                                  strict-if strict-cond
                                  let let*
                                  list-ref scale translate boolean
                                  tag? tag untag
                                  unquote)
      [(_ (unquote e:expr))
       (syntax/loc stx (meaning-arr e))]

      [(_ e:constant)
       (syntax/loc stx e.expression)]

      [(_ e:primitive-transformer)
       (syntax/loc stx (interp e.expression))]

      [(_ (cons e1 e2))
       (syntax/loc stx ((interp e1) . &&&/arr . (interp e2)))]

      [(_ (e:0ary-primitive))
       (syntax/loc stx e.computation)]

      [(_ (e:1ary-primitive e1))
       (syntax/loc stx ((interp e1) . >>>/arr . e.computation))]

      [(_ (e:2ary-primitive e1 e2))
       (syntax/loc stx (((interp e1) . &&&/arr . (interp e2)) . >>>/arr . e.computation))]

      [(_ e:bad-primitive-application)
       (raise-syntax-error 'drbayes (attribute e.message) stx #'e)]

      [(_ (const e:expr))
       (syntax/loc stx (const/arr (const e #'e)))]

      [(_ (lazy e:expr))
       (syntax/loc stx (lazy/arr (delay (interp e))))]

      [(_ (~and (if . _) ~! e:if-expr))
       (syntax/loc stx (ifte*/arr (interp e.cond) (interp (lazy e.then)) (interp (lazy e.else))))]

      [(_ (~and (strict-if . _) ~! e:if-expr))
       (syntax/loc stx (ifte/arr (interp e.cond) (interp e.then) (interp e.else)))]

      [(_ (~and (cond _) ~! (cond e:cond-else)))
       (syntax/loc stx (interp e.expr))]

      [(_ (~and (cond . _) ~! (cond c0:cond-case c:cond-case ... ~! e:cond-else)))
       (syntax/loc stx (interp (if c0.cond c0.then (cond c ... e))))]

      [(_ (~and (strict-cond _) ~! (strict-cond e:cond-else)))
       (syntax/loc stx (interp e.expr))]

      [(_ (~and (strict-cond . _) ~! (strict-cond c0:cond-case c:cond-case ... ~! e:cond-else)))
       (syntax/loc stx (interp (strict-if c0.cond c0.then (strict-cond c ... e))))]

      [(_ (list-ref e:expr i:exact-nonnegative-integer))
       (syntax/loc stx ((interp e) . >>>/arr . (list-ref/arr i)))]

      [(_ (list-ref ~! e:expr (const i:expr)))
       (syntax/loc stx ((interp e) . >>>/arr . (list-ref/arr (assert i exact-nonnegative-integer?))))]

      [(_ (scale e:expr x:real))
       (syntax/loc stx ((interp e) . >>>/arr . (scale/arr (const x #'x))))]

      [(_ (scale ~! e:expr (const x:expr)))
       (syntax/loc stx ((interp e) . >>>/arr . (scale/arr (assert (const x #'x) flonum?))))]

      [(_ (translate e:expr x:real))
       (syntax/loc stx ((interp e) . >>>/arr . (translate/arr (const x #'x))))]

      [(_ (translate ~! e:expr (const x:expr)))
       (syntax/loc stx ((interp e) . >>>/arr . (translate/arr (assert (const x #'x) flonum?))))]

      [(_ (boolean p:real))
       (syntax/loc stx (boolean/arr (assert (const p #'p) flonum?)))]

      [(_ (boolean ~! (const p:expr)))
       (syntax/loc stx (boolean/arr (assert (const p #'p) flonum?)))]

      [(_ (tag? ~! e:expr t:expr))
       (syntax/loc stx ((interp e) . >>>/arr . (tag?/arr t)))]

      [(_ (tag ~! e:expr t:expr))
       (syntax/loc stx ((interp e) . >>>/arr . (tag/arr t)))]

      [(_ (untag ~! e:expr t:expr))
       (syntax/loc stx ((interp e) . >>>/arr . (untag/arr t)))]

      [(_ (let () body:expr))
       (syntax/loc stx (interp body))]

      [(_ (let (b:let-binding) body:expr))
       (define d (+ 1 (syntax-parameter-value #'let-depth)))
       (define/with-syntax let-depth+1 d)
       (define/with-syntax value (make-binding-transformer stx d))
       (syntax/loc stx
         (let/arr (interp b.expr)
                  (let-syntax ([b.id  value])
                    (syntax-parameterize ([let-depth  let-depth+1])
                      (interp body)))))]

      [(_ (let ~! (b:let-binding ...) body:expr))
       (define d (+ 1 (syntax-parameter-value #'let-depth)))
       (define/with-syntax let-depth+1 d)
       (define/with-syntax (value ...)
         (build-list (length (syntax->list #'(b.id ...)))
                     (λ (idx) (make-binding-transformer stx d idx))))
       (syntax/loc stx
         (let/arr (interp (list b.expr ...))
                  (let-syntax ([b.id  value] ...)
                    (syntax-parameterize ([let-depth  let-depth+1])
                      (interp body)))))]

      [(_ (let* () body:expr))
       (syntax/loc stx (interp body))]

      [(_ (let* ~! (b0:let-binding b:let-binding ...) body:expr))
       (syntax/loc stx
         (interp (let ([b0.id b0.expr]) (let* (b ...) body))))]

      [(_ (x:id args ...))
       #:when (bound-local-identifier? (syntax-local-value #'x (λ () #f)))
       (raise-syntax-error (syntax->datum #'x) "expected function" stx #'x)]

      [(_ (f:id args ...))
       #:when (first-order-function? (syntax-local-value #'f (λ () #f)))
       (syntax/loc stx (f args ...))]

      [(_ (f:id . args))
       #:when (let ([proc  (syntax-local-value #'f (λ () #f))])
                (and (procedure? proc) (procedure-arity-includes? proc 1)))
       (raise-syntax-error 'drbayes "macro expansion not supported" (syntax/loc stx (f:id . args)))]

      [(_ f:id)
       #:when (first-order-function? (syntax-local-value #'f (λ () #f)))
       (raise-syntax-error (syntax->datum #'f) "expected function application" stx #'f)]

      [(_ x:id)
       #:when (bound-local-identifier? (syntax-local-value #'x (λ () #f)))
       (syntax/loc stx x)]

      [(_ e)
       (raise-syntax-error 'drbayes "unrecognized syntax" stx #'e)]
      )))

(define-syntax (drbayes stx)
  (syntax-case stx ()
    [(_ e)
     (syntax/loc stx
       (meaning (syntax-parameterize ([drbayes-dispatcher  proc-dispatcher])
                  (interp e))
                (syntax-parameterize ([drbayes-dispatcher  bot*-dispatcher])
                  (interp e))
                (syntax-parameterize ([drbayes-dispatcher  pre*-dispatcher])
                  (interp e))
                (syntax-parameterize ([drbayes-dispatcher  idx-dispatcher])
                  (interp e))))]))

(define-for-syntax (raise-syntax-arity-error name arity stx)
  (define arguments (if (= arity 1) "argument" "arguments"))
  (raise-syntax-error name (format "expected ~a ~a" arity arguments) stx))

(define-for-syntax (make-first-order-function name-body name-racket arity)
  (first-order-function
   (λ (stx)
     (define id (current-dispatcher-id #'drbayes-dispatcher))
     (if (identifier? id)
         (syntax-case stx ()
           [(_ arg ...)
            (= arity (length (syntax->list #'(arg ...))))
            (quasisyntax/loc stx
              (apply/arr (meaning-arr #,name-body) (list (interp arg) ...)))]
           [(_ . _)  (raise-syntax-arity-error 'drbayes arity stx)]
           [_        (raise-syntax-error 'drbayes "expected application" stx)])
         (syntax-case stx ()
           [(_ arg ...)
            (= arity (length (syntax->list #'(arg ...))))
            (quasisyntax/loc stx (#,name-racket arg ...))]
           [(_ . _)  (raise-syntax-arity-error 'drbayes arity stx)]
           [_        (quasisyntax/loc stx #,name-racket)])))))

(define-syntax (define/drbayes stx)
  (syntax-parse stx
    [(_ name:id body ...)
     (raise-syntax-error 'drbayes "cannot define probabilistic constants" stx)]
    [(_ (name:id arg:id ...) body:expr)
     (define arity (length (syntax->list #'(arg ...))))
     (define/with-syntax (value ...) (build-list arity (λ (i) (make-binding-transformer stx 1 i))))
     (define/with-syntax name-body (generate-temporary (format-id #'name "~a-body" #'name)))
     (define/with-syntax name-racket (generate-temporary (format-id #'name "~a-racket" #'name)))
     (define/with-syntax (Values ...) (build-list arity (λ (_) #'Value)))
     (quasisyntax/loc stx
       (begin
         (: name-body meaning)
         (define name-body
           (let-syntax ([arg value] ...)
             (syntax-parameterize ([let-depth 1])
               (drbayes body))))

         (: name-racket (Values ... -> Value))
         (define (name-racket arg ...)
           ((apply/proc (meaning-proc name-body) (list (const/proc (const arg)) ...)) null))

         (define-syntax name
           (make-first-order-function #'name-body #'name-racket #,arity))))]
    [(_ (name:id arg:id ...) body ...)
     (raise-syntax-error 'drbayes "functions may have only one body expression" stx)]))

(define-syntax (struct/drbayes stx)
  (syntax-case stx ()
    [(_ name (fields ...))
     (let ([arity  (length (syntax->list #'(fields ...)))])
       (with-syntax ([name-tag  (format-id #'name "~a-tag" #'name)]
                     [name?     (format-id #'name "~a?" #'name)]
                     [(name-field ...)  (map (λ (field) (format-id #'name "~a-~a" #'name field))
                                             (syntax->list #'(fields ...)))]
                     [(index ...)       (build-list arity values)]
                     [name-set    (format-id #'name "~a-set" #'name)]
                     [(Sets ...)  (build-list arity (λ (_) #'Set))])
         (syntax/loc stx
           (begin (define name-tag (make-set-tag 'name))
                  (define/drbayes (name fields ...)
                    (tag (list fields ...) name-tag))
                  (define/drbayes (name? x)
                    (tag? x name-tag))
                  (define/drbayes (name-field x)
                    (list-ref (untag x name-tag) index))
                  ...
                  (: name-set (Sets ... -> Set))
                  (define (name-set fields ...)
                    (set-tag (set-list fields ...) name-tag))
                  ))))]))
