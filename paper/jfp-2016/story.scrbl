#lang scribble/base

@require["common.rkt" "benchmark.rkt" "util.rkt" racket/file
         (only-in pict vc-append rt-superimpose hline ht-append pict-width pict-height frame text vline)
         (only-in pict/code codeblock-pict) (only-in racket/string string-join)]

@profile-point{sec:story}
@title[#:tag "sec:story"]{Gradual Typing in Typed Racket}

Typed Racket@~cite[thf-popl-2008 tfffgksst-snapl-2017] is a sound gradual type system for Racket.
Its syntax is an extension of Racket's; its static type checker supports idioms common in dynamically-typed Racket programs@~cite[stf-esop-2009 tfdffthf-ecoop-2015]; and a Typed Racket module may import definitions from a Racket module.
A Racket module may likewise import definitions from a Typed Racket module.
To ensure type soundness, Typed Racket compiles static types to higher-order contracts and attaches these contracts at the lexical boundaries between Typed Racket and Racket modules@~cite[tfffgksst-snapl-2017].

@figure["fig:story:tr" "A gradually typed application"
  @(let* ([add-name (lambda (pict name) (rt-superimpose pict (frame (text (string-append " " name " ") "black" 10))))]
          [c1
             @codeblock-pict[@string-join['(
             "#lang racket"
             ""
             "(provide play)"
             ""
             "(define (play)"
             "  (define n (random 10))"
             "  (λ (guess)"
             "    (= guess n)))"
             ) "\n"]]]
          [c1-name "guess-game"]
          [c1/name (add-name c1 c1-name)]
          [c2
             @codeblock-pict[@string-join['(
             "#lang racket"
             ""
             "(provide stubborn-player)"
             ""
             "(define (stubborn-player i)"
             "  4)"
             ) "\n"]]]
          [c2-name "player"]
          [c2/name (add-name c2 c2-name)]
          [add-rkt (lambda (s) (string-append s ".rkt"))]
          [c3
             @codeblock-pict[@string-join[(list
             "#lang typed/racket"
             ""
             (format "(require/typed ~s" (add-rkt c1-name))
             "  [play (-> (-> Natural Boolean))])"
             (format "(require/typed ~s" (add-rkt c2-name))
             "  [stubborn-player (-> Natural Natural)])"
             ""
             "(define check-guess (play))"
             "(for/sum ([i : Natural (in-range 10)])"
             "  (if (check-guess (stubborn-player i)) 1 0))"
             ) "\n"]]]
          [c3-name "driver"]
          [c3/name (add-name c3 c3-name)]
          [c1+c2
           @ht-append[8 c1/name @vline[2 (+ 2 (max (pict-height c1) (pict-height c2)))] c2/name]]
             )
  @vc-append[8
    c1+c2
    @hline[(pict-width c1+c2) 2]
    c3/name]
  )
]

@Figure-ref{fig:story:tr} demonstrates gradual typing in Typed Racket with a toy application.
The module on the top left implements a guessing game with the function @racket[play].
Each call to @racket[play] generates a random number and returns a function that compares a given number to this chosen number.
The module on the top right implements a simple player.
The driver module at the bottom combines the game and player.
It instantiates the game, prompts @racket[stubborn-player] for ten guesses, and counts the number of correct guesses using the @racket[for/sum] comprehension.
Of the three modules, only the driver is implemented in Typed Racket.
This means that Typed Racket statically checks the body of the driver module under the assumption that its annotations for the @racket[play] and @racket[stubborn-player] functions are correct.
Typed Racket guarantees this assumption about these functions by compiling their type annotations into dynamically-checked contracts.
One contract checks that @racket[(play)] returns a function from natural numbers to booleans (by attaching a new contract to the returned value), and the other checks that @racket[stubborn-player] returns natural numbers.


@; -----------------------------------------------------------------------------
@section{How Mixed-Typed Code Emerges}

The close integration of Racket and Typed Racket makes it easy to migrate a code base from the former to the latter on an incremental basis.
By converting modules to Typed Racket, the maintainer obtains several benefits:
@itemlist[
  @item{
    @emph{assurance} from the typechecker against basic logical errors;
  }
  @item{
    @emph{documentation} in the form of reliable type annotations;
  }
  @item{
    @emph{protection} against dynamically-typed clients; and
  }
  @item{
    @emph{speed}, when the compiler can use types to improve the generated bytecode.
  }
]
These benefits draw many Racket programmers to Typed Racket.

Another way that Racket programs may rely on Typed Racket is by importing definitions from a typed library.
For example, the creator of Racket's @racket[plot] library wrote part of the library in Typed Racket, and thus the program that typeset this paper interacts with typed code.
This kind of import is indistinguishable from importing definitions from a Racket library
 and is a rather subtle way of creating a mixed-typed codebase.

Conversely, developers who start with Typed Racket programs may rely on Racket in the form of legacy libraries.
For such libraries, the programmer has a choice between writing a type-annotated import statement for the library API and converting the entire library to Typed Racket.
Most choose the former approach.

In summary, the introduction of Typed Racket has given rise to a fair number of projects that mix typed and untyped code.@note{See @hyperlink["https://pkgd.racket-lang.org/pkgn/search?q=typed-racket"]{@tt{pkgd.racket-lang.org/pkgn/search?q=typed-racket}} for a sample.}
The amount of mixed-typed code in the ecosystem is likely to grow;
 therefore, it is essential that Typed Racket programs interact smoothly with existing Racket code.


@; -----------------------------------------------------------------------------
@section{The Need for Performance Evaluation}

Typed Racket is an evolving research project.
The initial release delivered a sound type system that could express the idioms in common Racket programs.
Subsequent improvements focused on growing the type system to support variable-arity polymorphism@~cite[stf-esop-2009], control operators@~cite[tsth-esop-2013], and the object-oriented extensions to Racket@~cite[tfdffthf-ecoop-2015].
All along, the Typed Racket developers knew that the performance cost of enforcing type soundness could be high (see @secref{sec:devils} for rationale); however, this cost was not an issue in many of their programs.

As other programmers began using Typed Racket, a few discovered issues with its performance.
For instance, one user experienced a 1.5x slowdown in a web server,
 others found 25x--50x slowdowns when using an array library,
 and two others reported over 1000x slowdowns when using a library of functional data structures.@note{The appendix samples these user reports.}
Programmers found these performance issues unacceptable (because the slowdowns were large), difficult to predict, and difficult to debug.
Instead of making a program run more efficiently, adding types to the wrong boundary seriously degraded performance, negating an advertised benefit.
In short, programmers' experience with Typed Racket forced the Typed Racket team to develop a systematic method of performance evaluation.
