#lang scribble/base

@; "The first challenge for computer science is to discover how to maintain
@;  order in a finite, but very large, discrete universe that is intricately
@;  intertwined."  -- Dijkstra, 1979 (from Emina's thesis)

@require["common.rkt" "util.rkt" "benchmark.rkt"]

@profile-point{sec:intro}
@title[#:tag "sec:intro"]{The Gradual Typing Design Space}

Programmers use dynamically typed languages to build all kinds of applications.
Telecom companies have been running Erlang programs for years@~cite[armstrong-2007],
 Sweden's pension system is a Perl program@~cite[v-aplwa-2010],
 and the @emph{lingua franca} of the Internet is JavaScript.
New companies frequently use languages such as Python, PHP, and Ruby in server-side applications;
 see for example, Dropbox, Facebook, and Twitter.

Regardless of why programmers choose dynamically typed languages,
 the maintainers of these applications inevitably find the lack of explicit type
 annotations an obstacle to their work.
Explicit annotations crystallize a programmer's intent to other human readers.
Furthermore, the toolchain can check the annotations for inconsistencies
 and leverage types to improve the efficiency of compiled code.
Researchers have tried to overcome the lack of type annotations with numerous inference algorithms,
 but there is no substitute for programmer-supplied annotations.
     @; Confirming problem, and responses:
     @; - PEP type hints
     @; - pycharm parsing comments
     @; - type-testing JITS for php/js
     @; - typescript flow

@; Enter GT
Gradual typing@~cite[st-sfp-2006 thf-dls-2006]@note{We prefer the more descriptive term @emph{incremental typing}, but defer to the better sloganeer.}
 is a linguistic approach to the problem.
 @; What problem? Is it really clear enough?
    @; NOTE: a GT "language" is ideally a "superset" of an existing lang,
    @;       but the cast calculus & gradualizer/foundations have their place
In a gradually typed language,
 programmers can incrementally add type annotations to dynamically typed code.
At the lexical boundaries between annotated code and dynamically
 typed code, the type system inserts runtime checks to guarantee the soundness
 of the type annotations.

From a syntactic perspective the interaction is seamless, but dynamic checks introduce runtime overhead.
During execution, if an untyped function flows into a variable @racket[f] with
 type @racket[(Real -> Real)] then a dynamic check must
 follow every subsequent call to @racket[f] because typed code can never trust
 that the untyped function produces values that have the syntactic type @racket[Real].
Conversely, typed functions invoked by untyped code must dynamically check their argument values.
If functions or large data structures frequently cross these
 @emph{type boundaries},
 enforcing type soundness might impose a huge runtime cost.

Optimistically, researchers have continued to explore the theory and practice of sound
 gradual typing@~cite[htf-tfp-2007
                      sgt-esop-2009
                      TypedRacket
                      wgta-ecoop-2011
                      acftd-scp-2013
                      rnv-ecoop-2015
                      vksb-dls-2014
                      rsfbv-popl-2015
                      gc-popl-2015].@note{See @url{https://github.com/samth/gradual-typing-bib} for a full bibliography.}
Some research groups have invested significant resources implementing sound gradual type systems.
Suprisingly few groups have rigourously evaluated the performance of gradual typing.
Most acknowledge an issue with performance in passing.
Worse yet, others report only the performance ratio of fully typed programs relative to
 fully untyped programs, ironically ignoring the entire space of programs
 that mix typed and untyped components.

This paper presents a method for the performance evaluation of gradual type systems.
The method is to
 (1) fix a granularity for adding or removing type annotations,
 (2) fully type a suite of representative benchmark programs,
 (3) consider all possible ways of removing a subset of type annotations in each program,
 (4) report the @emph{overhead} of these gradually typed @emph{configurations}
     relative to the baseline performance of the fully untyped program.
We demonstrate that the method characterizes
 both the @emph{absolute} performance of a gradual type system and the @emph{relative}
 performance of two implementations of gradual typing for the same untyped language.
In particular, we evaluate the performance of @integer->word[(length (*RKT-VERSIONS*))]
 Typed Racket versions on a suite of @integer->word[(*NUM-BENCHMARKS*)] functional
 and object-oriented benchmark programs ranging in size and complexity.

Building on the evaluation method introduced in an earlier conference version@~cite[tfgnvf-popl-2016],
 this paper contributes:
@itemlist[
  @item{
    data for @integer->word[(*NUM-OO-BENCHMARKS*)]
     object-oriented benchmark programs and
     @integer->word[(- (*NUM-BENCHMARKS*) (*NUM-OO-BENCHMARKS*) NUM-POPL)]
     new functional programs;
  }
  @item{
    a comparitive evaluation of @integer->word[(length (*RKT-VERSIONS*))] versions
     of Typed Racket; and
  }
  @item{
    in-depth discussions of the performance bottlenecks in each benchmark,
     their resolution,
     and general lessons for implementors of gradually typed languages.
  }
  @;@item{
  @;  preliminary reports on a method for predicting the performance overhead for
  @;   any of a program's @exact{$2^N$} configurations after taking @exact{$O(N)$}
  @;   measurements.
  @;}
]

@parag{Disclaimer:} 3x overhead is not "deliverable" performance.
We never claimed so in the conference version and our opinion certainly has not changed.
