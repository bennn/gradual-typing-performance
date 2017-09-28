#lang tagged/racket/base

;; Adapter for gregor's `structs.rkt` file.

(provide
  (struct-out YMD)
  (struct-out HMSN)
  Month)

(require
  require-typed-check/tagged
  "../base/types.rkt")

(require/typed/check "core-structs.rkt"
  [#:struct YMD ([y : Natural]
                 [m : Month]
                 [d : Natural])]
  [#:struct HMSN ([h : Integer]
                 [m : Integer]
                 [s : Integer]
                 [n : Integer])])

