#lang scribble/base

@require[
  "benchmark.rkt"
  "common.rkt"
  "typed-racket.rkt"
  "util.rkt"
  (only-in gtp-summarize/path-util add-commas)
  (only-in racket/string string-join)
  (except-in gtp-summarize/lnm-parameters defparam)
]

@profile-point{sec:tr}
@title[#:tag "sec:tr"]{Evaluating Typed Racket}

To validate the evaluation method, we apply it to a suite of @integer->word[(count-benchmarks)] Typed Racket programs.
This section briefly describes each benchmark, documents our protocol for collecting performance lattice data, and presents the overhead graphs we derived from the data.
@; comparisons?


@; -----------------------------------------------------------------------------
@section[#:tag "sec:bm"]{The Benchmark Programs}

The benchmarks are representative of actual user code yet
 small enough to make exhaustive performance evaluation tractable.
The following descriptions, arranged from smallest performance lattice to largest,
 briefly explain the purpose of each benchmark.

@emph{Note on terminology:} Racket's @emph{chaperones} are proxies that may perform only side effects but preserve object equality@~cite[chaperones-impersonators].
Typed Racket compiles each higher-order type annotating a type boundary to a chaperone and applies this proxy to all runtime values that cross the boundary.


@; -----------------------------------------------------------------------------
@subsection{Benchmark Descriptions}

@profile-point{sec:tr:descriptions}
@render-benchmark-descriptions[
@(cons sieve
  @elem{
    Demonstrates a scenario where user code is tightly coupled to higher-order library code.
    The library implements a stream data structure; the user creates a stream of prime numbers.
    Introducing a type boundary between these modules introduces significant overhead.
  })
(cons forth
  @elem{
    Interprets Forth programs.
    The interpreter represents calculator commands as a list of first-class objects.
    These objects accumulate chaperones as they cross type boundaries.
  })
(cons (list fsm fsmoo)
  @elem{
    Simulates the interactions of economic agents, modeled as finite-state automata@~cite[n-mthesis-2014].
    This benchmark has functional (@bm[fsm]) and object-oriented (@bm[fsmoo]) implementations.
    The object-oriented version frequently sends first-class objects across type boundaries; the functional version does the same with mutable vectors.
  })
(cons mbta
  @elem{
    Builds a map of Boston's subway system and answers reachability queries.
    The map encapsulates a boundary to Racket's untyped @library{graph} library; when the map is typed, the boundary to @library{graph} becomes a significant type boundary.
  })
(cons morsecode
  @elem{
    Computes Levenshtein distances and morse code translations for a fixed sequence of pairs of words.
    Every function that crosses a type boundary in @bm[morsecode] operates on strings and integers, thus overhead is relatively low.
  })
(cons zombie
  @elem{
    Implements a game where players dodge computer-controlled ``zombies''.
    Curried functions over symbols (i.e. ``method names'') implement game entities and repeatedly cross type boundaries.

    @;@racket[
    @;  (define-type Point
    @;    ((U 'x 'y 'move)
    @;     ->
    @;     (U (Pairof 'x (-> Real))
    @;        (Pairof 'y (-> Real))
    @;        (Pairof 'move (Real Real -> Point)))))
    @;]

    @;The program was originally object-oriented but the authors converted it
    @; to a functional encoding as a test case for soft contract verification@~cite[nthvh-icfp-2014].
    @;We benchmark a typed version of the functional game on a small input (100 lines).
    @;Repeatedly sending encoded objects across a type boundary leads to exponential slowdowns.

    @; --- 2016-04-22 : this type is a little too awkward to talk about
    @;As an example of the encoding, the following type signature implements a
    @; point object.
    @;By supplying a symbol, clients get access to a (tagged) method.

    @;Intersection
    @; types would be more straightforward than the tagged codomains used here,
    @; but Typed Racket does not yet support intersections.

  })
(cons dungeon
  @elem{
    Builds a grid of wall and floor objects by choosing first-class classes from a list of ``template'' pieces.
    This list accumulates chaperones when it crosses a type boundary.

    @;Originally, the program imported the Racket @library{math} library
    @; for array operations and @library{racket/dict} for a generic dictionary interface.
    @;The benchmark uses Racket's vectors instead of the @library{math} library's arrays
    @; because Typed Racket v6.2 could not compile the type @racket[(Mutable-Array (Class))] to a contract.
    @;The benchmark does not use @library{racket/dict} so that the results for
    @; @bm[dungeon] describe internal type boundaries rather than the type
    @; boundary to the untyped dict interface.
  })
(cons zordoz
  @elem{
    Traverses Racket bytecode (@tt{.zo} files).
    The @library{compiler-lib} library defines the bytecode data structures.
    Typed code interacting with the library suffers overhead.

    @emph{Note}:
     the Racket bytecode format changed between versions 6.2 and 6.3 with
     the release of the set-of-scopes macro expander@~cite[f-popl-2016].
    This change makes a significant difference in the running time and overhead of @bm[zordoz].
    @todo{doublecheck}

    @;As it turns out, the change from 6.2 to 6.3 improved the typed/untyped ratio
    @; from
    @; @add-commas[(rnd (typed/untyped-ratio (benchmark-rktd zordoz "6.2")))]x in v6.2 to
    @; @add-commas[(rnd (typed/untyped-ratio (benchmark-rktd zordoz "6.3")))]x in v6.3 because
    @; the more recent bytecode structures generate less expensive type contracts.
    @;The ratio for the newest bytecode format is
    @; @add-commas[(rnd (typed/untyped-ratio (benchmark-rktd zordoz "6.5")))]x.
  })
(cons lnm
  @elem{
    Renders overhead graphs@~cite[tfgnvf-popl-2016].
    Two modules are tightly-coupled to Typed Racket libraries.
    Removing their type boundaries improves performance.
  })
(cons suffixtree
  @elem{
    Computes longest common subsequences between strings.
    The largest performance overheads come from a boundary between data definitions and functions manipulating the data.
  })
(cons kcfa
  @elem{
    Performs 1-CFA on a lambda calculus term that computes @exact|{~$\RktMeta{2*(1+3) = 2*1 + 2*3}$}| via Church numerals.
    The (mutable) binding environment flows throughout the program.
    When this environment crosses a type boundary, it acquires a new chaperone.
  })
(cons snake
  @elem{
    Implements the Snake game;
     the benchmark replays a fixed sequence of moves.
    Mostly first-order data crosses the module boundaries in @bm[snake], however the frequency of boundary-crossings is very high.
  })
(cons take5
  @elem{
    Runs a card game between AI players.
    These AI communicate infrequently, so gradual typing adds relatively little overhead.
  })
(cons acquire
  @elem{
    Simulates a board game; implemented in a stateful, object-oriented style.
    Few values cross module boundaries, therefore performance overhead is low.
  })
(cons tetris
  @elem{
    Replays a pre-recorded game of Tetris.
    Frequent interactions, rather than proxies or expensive runtime checks, are the source of performance overhead.
  })
(cons synth
  @elem{
    Converts a description of notes and drum beats to @tt{WAV} format.
    Modules in the benchmark come from two sources, a music library and an array library.
    The worst overhead occurs when arrays frequently cross type boundaries.
  })
(cons gregor
  @elem{
    Provides tools for manipulating calendar dates.
    The benchmark builds tens of date values and runs unit tests on these values.
  })
(cons (list quadBG quadMB)
  @elem{
    Converts S-expression source code to @tt{PDF} format.
    We have two versions of @bm[quad], each with very different performance characteristics.

    The first version, @bm[quadMB], uses type annotations by the original author.
    This version has a high typed/untyped ratio
     because it explicitly compiles types to runtime predicates
     and uses these predicates to eagerly check data invariants.
    In other words, the typed version is slower because it performs more work than the untyped program.

    The second version, @bm[quadBG], uses identical code but weakens types to match the untyped program.
    This version is therefore suitable for judging the implementation
     of Typed Racket rather than the user experience of Typed Racket.

    The conference version of this paper gave data only for
     @bm[quadMB]@~cite[tfgnvf-popl-2016].

    @; To give a concrete example of different types, here are the definitions
    @;  for the core @tt{Quad} datatype from both @bm[quadMB] and @bm[quadBG].

    @; @racket[(define-type QuadMB (Pairof Symbol (Listof QuadMB)))]

    @; @racket[(define-type QuadBG (Pairof Symbol (Listof Any)))]

    @; The former is a homogenous, recursive type.
    @; As such, the predicate asserting that a value has type @racket[QuadMB] is a linear-time tree traversal.
    @; The predicate for @racket[QuadBG] runs significantly faster.
  })
]


@; -----------------------------------------------------------------------------
@profile-point{sec:tr:characteristics}
@subsection{Static Benchmark Characteristics}

@Figure-ref{fig:bm} lists static characteristics of the benchmark programs as a coarse measure of their size and complexity.
The lines of code (LOC) and number of modules (# Mod.) approximate program size.
    @; Note that the number modules determines the number of gradually typed configurations.
Adaptor modules (# Adt.) roughly correspond
 to the number of user-defined datatypes in each benchmark
See @secref{sec:todo} for a precise definition.
The ``Annotation'' column is the number of type annotations in the fully typed
 version of the benchmark.@note{The benchmarks use more annotations than Typed Racket requires in practice, as they provide full type signatures for each import. Only untyped modules require such signatures.}
Lastly, the boundaries (# Bnd.) and exports (# Exp.) describe the graph structure of each benchmark.
Boundaries are import statements from one module in the benchmark to another (omits external boundaries).
Exports are identifiers that cross such boundaries statically.
For example, there is one module boundary in @tt{sieve} and nine identifiers cross this boundary.
@; At runtime, these nine identifiers are repeatedly invoked as functions; however, the number of invocations is not part of @figure-ref{fig:bm}.

@figure*["fig:bm" "Static characteristics of the benchmarks"
  @render-benchmarks-table{}
]


@; -----------------------------------------------------------------------------
@profile-point{sec:tr:protocol}
@section[#:tag "sec:protocol"]{Experimental Protocol}

@(define MIN-ITERS-STR "2")
@(define MAX-ITERS-STR "30")
@(define FREQ-STR "1.40 GHz")

We measured configurations' running times on a Linux machine with two physical AMD Opteron 6376 2.3GHz processors and 128GB RAM.
The machine used at most two of its 32 cores to collect data; each core ran at minimum frequency (@|FREQ-STR|) via the @tt{powersave} CPU governor.

For each benchmark, we chose a random permutation of its configurations and ran each configuration through one warmup and one collecting iteration.
Depending on the time needed to collect this data, we repeated the process between @|MIN-ITERS-STR| and @|MAX-ITERS-STR|.
We manually confirmed that the data for each configuration were unimodal.
In total, across @integer->word[(*NUM-BENCHMARKS*)] benchmarks and @integer->word[(length (*RKT-VERSIONS*))] versions of Racket,
 we measured @add-commas[(* (length (*RKT-VERSIONS*)) (apply + (map benchmark->num-configurations ALL-BENCHMARKS)))] such configurations.

All scripts we used to run our experiments and the data we collected
 are available in the online supplement to this paper and in the @tt{jfp}
 branch of this paper's public repository.@note{@url{https://github.com/nuprl/gradual-typing-performance}}

@;For threats to validity regarding our experimental protocol,
@; see @Secref{sec:threats}.


@; -----------------------------------------------------------------------------
@profile-point{sec:tr:plots}
@section[#:tag "sec:plots"]{Results}

@(render-lnm-plot
  (lambda (pict*)
    (define name*
      (for/list ([p (in-list pict*)]
                 [i (in-naturals)])
        (format "fig:lnm:~a" i)))
    (define get-caption
      (let ([N (length name*)])
        (lambda (i) (format "Overhead Graphs (~a/~a)" i N))))
    (define NUMV (integer->word (length (*RKT-VERSIONS*))))
    (cons
      @elem{
        @; -- Quickly, just the basics
        @(apply Figure-ref name*) present our experimental results in
         a series of overhead graphs.
        Each graph is a cumulative distribution function showing the number
         of @deliverable{D} configurations for real-valued @math{D}
         between 1x and @id[(*MAX-OVERHEAD*)]x.
        Specifically, the x-axes represent overhead factors
         relative to the untyped configuration of each benchmark.
        The y-axes count the percentage of each benchmark's configurations
         that run within the overhead shown on the x-axes.
        The @id[NUMV] lines on each plot correspond to versions of Racket;
         newer versions have thicker lines.
        Plots in the left column of each figure show @step["0" "D"]
         configurations.
        Plots in the right column show @step["1" "D"] configurations.

        @; -- choice of x-axis, log scale, bode diagrams, picking D/U
        The range of values on the x-axes are plausible bounds on the
         overhead users of gradual type systems will accept.
        Granted, there may be software teams that require overhead
         under 1x---that is, a speedup relative to the untyped program---or
         can work with slowdowns exceeding @id[(*MAX-OVERHEAD*)]x,
         but we expect most users will tolerate only a small performance overhead.
        To emphasize the practical value of low overheads
         we use a log scale on the x-axis with minor tick lines at
         1.2x, 1.4x, etc. and again at 4x, 6x, etc.
        For example, the y-value at the first minor tick gives the number
         of @deliverable{1.2} configurations.
        To derive the number of @usable["1.2" "1.6"] configurations,
         subtract the number of @deliverable{1.2} configurations from
         the number of configurations deliverable at the third minor tick.

        @; -- choice of y-axis
        @; TODO
        To ease comparisons across benchmarks, the y-axes show
         the percentage of deliverable configurations rather than an absolute count.
        Each figure lists the total number of configurations in each benchmark
         along the right column.

        @; -- data lines
        A data point @math{(X,Y)} along any of the @id[NUMV] curves in a plot
         along the left column
         represents the percentage @math{Y} of configurations
         that run at most @math{X} times slower than the benchmark's
         untyped configuration.
        For example, 50% of @bm[sieve] configurations run within
         2x slower relative to the untyped configuration.
        On all Racket versions, the same 50% of configurations
         are the only ones that run within a @id[(*MAX-OVERHEAD*)]x overhead.
        @;bg; NEW DATA

        The right column of plots shows the effect of adding types
         to at most @math{1} additional untyped modules.
        A point @math{(X,Y)} on these curves represents the percentage @math{Y}
         of configurations @exact{$c_1$} such that there exists a configuration
         @exact{$c_2$} where @exact{$c_1 \rightarrow_1 c_2$} and @exact{$c_2$}
         runs at most @math{X} times slower than the untyped configuration.
        Note that @exact{$c_1$} and @exact{$c_2$} may be the same;
         they are definitely the same when @exact{$c_1$} is the fully-typed configuration.
        Again using @bm[sieve] as an example, 100% of configurations can
         reach a configuration with at most 1x overhead after at most one
         type conversion step.
        This is because the fully-typed configuration happens to be
         @deliverable{1} and both of the gradually typed configurations
         become fully-typed after one conversion step.
        On the other hand, freedom to type one extra module has no effect on the number of
         @deliverable{1.2} configurations in @bm[mbta].
        In other words, even if the programmer at a @deliverable{1.2} configuration
         happens to convert the untyped module best-suited to improve performance,
         their next configuration will be no better than @deliverable{1.2}.
        @; Theoretically, a developer might try every way of typing the next
        @;  one module, but at that point they have all the annotations to go
        @;  anywhere in the lattice.

        @; Matthias says NOOOO
        @; -- all about data, ideal shape
        The ideal gradual type system would introduce zero overhead, thus every
         curve in the left column would be a flat line at the
         top of the plot, meaning that all configurations on all tested versions
         of Racket run no slower than each benchmark's untyped configuration.
        If this were true, the right column would be identical to the left
         because every @deliverable{1} configuration can reach a @deliverable{1}
         configuration (itself) in at most one type conversion step.
        Conversely, a worst-case gradual type system would exhibit flat lines
         at the bottom of every plot, indicating that any configuration with at
         least one typed module is more than @id[(*MAX-OVERHEAD*)]x slower than the untyped configuration.
        Here too, freedom to type an additional module will not change performance
         and so the @math{k=0} and @math{k=1} plots will be identical.

        The reality is that each benchmark determines a unique curve.
        Using a different version of Racket or moving from @math{k=0} to @math{k=1}
         typically shifts the curve horizontally but does not change the overall
         shape i.e. the relative cost of type boundaries in a program.
        Regarding shapes, a steep slope implies a good tradeoff between
         accepting a larger overhead and increasing the number of
         deliverable configurations.
        A shallow slope or low, flat line is a poor tradeoff and implies
         the majority of configurations suffer very large performance overhead.
        Where large overheads are due to a pathological boundary between two
         tightly-coupled modules, the associated @math{k=1} graph should
         exhibit much better performance, as is the case for @bm[sieve].
      }
      (for/list ([p (in-list pict*)]
                 [name (in-list name*)]
                 [i (in-naturals 1)])
        (figure name (get-caption i) p)))))


@; -----------------------------------------------------------------------------
@subsection[#:tag "subsec:compare"]{Discussion}

@todo{prose, once we have reliable data}

Lessons from graphs:
@itemize[
  @item{
    Serious overheads, even on newest version.
    For those interested, the 5 benchmarks with the WORST overheads are @todo{list}.
    These pathologies are bad.

    @(let ([num-bad (length '(sieve forth fsm fsmoo zombie suffixtree tetris synth quadMB))])
      @elem{
        Even worse, nearly half the configurations in @id[num-bad] benchmarks
         (@id[(round (* 100 (/ num-bad (count-benchmarks))))]%) have over @id[(*MAX-OVERHEAD*)]x overhead.
      })
  }
  @item{
    At @math{k=1}, only @bm[synth] and @bm[quadMB] have any configurations that
     cannot reach a @deliverable{20} configuration.
    This suggests that many of the absolute worst overheads are due to one or
     two problematic type boundaries.
  }
  @item{
    That said, the @math{k=1} graphs are disturbingly similar to the @math{k=0}
     graphs, especially at low overheads.
    Even a 3x overhead will not be ``deliverable'' for most programmers.
    Thus, incrementally converting a module or two to Typed Racket is apparently
     a poor strategy for reducing overhead introduced by gradual typing.
  }
  @item{
    All benchmarks, even @bm[snake] and @bm[synth], have a handful of configurations
     with less than 2x overhead.
    Can we guide developers to those configurations?
  }
  @item{
    Generally, small improvements with newer versions of Racket.
    Caveats:
    @itemize[
      @item{
        Forth worse after 6.2 because @todo{why?}
      }
      @item{
        zombie @math{k=1} is strange
      }
      @item{
        tetris at 1.2x @math{k=1} is strange
      }
    ]
  }
]


@; -----------------------------------------------------------------------------
@section[#:tag "sec:compare"]{Comparing Typed Rackets}

@; really, don't worry about writing well right now

Overhead plots capture the high-level performance of a gradual type system
 and can make broad comparisons between different gradual type systems for
 the same language.
Each version of Typed Racket is essentially a new gradual type system for Racket;
 these plots confirm that the general trend in subsequent versions is to improve
 performance.

For more fine-grained comparisons, overhead plots are not very good,
 as they are tailored to users of gradual typing rather than implementors.
Potential clients of gradual typing need to know the likelihood that a configuration
 they find useful will also be performant.
Later, after clients have decided to really use gradual typing, they no longer
 need our plots to address their performance issues.
Implementors, on the other hand, care about the absolute performance of all
 configurations.
Overhead plots are two steps removed from this data: first they report overhead
 instead of absolute running time and second the "overhead" of a configuration
 is actually the mean of repeated runs.

@; 
@(let ([ex1 morsecode]
       [ex2 suffixtree])
      ;; LNM is also interesting
@list[@elem{
  @Figure-ref{fig:exact-runtimes} shows the exact data we collected for two
   benchmarks, 


  Wow, everything there in the middle for suffixtree is just hidden in the
   graphs.
  Missed the regression in 6.3 and major improvement in 6.4.
  }

      @figure["fig:exact-runtimes" "Exact running times"
         @render-exact-plot[ex1 ex2]
      ]
])
@; 

@; LESSONS
@; - standard error of measurements, for all configs (histogram?)
@; - careful of trends along dots
@;   - zscore as function of time??? take R2 for that?
@;     orjust R2(y, time) FOR EACH CONFIG ... maybe can plot on 1 diagram
@; - confidence interval, #configs with stat. sig. diff 
@; - something about magnitude of difference (just mean is maybe ok)

@; Good "STE" might be DEFINED as Z ~ (68 95 100)
@;
@; (data integrity table)
@; | BM | STE | Z < 1 | Z < 2 | Z < 3 |
@;   ??? 3 versions OH just color-code the data in columns

@; (comparing versions)
@;   - possible to compare 3 versions simultaneously?
@;     IF NOT, other tables can go in appendix
@;   - "overall gain" as function of deltas?
@; | BM | % better | % worse | % same (mean/median)
@;   ??? could also be triple-columns,
@;    but do 1-col first and see how it fits


Need also scatterplots to really compare versions (with @emph{confidence}).
@todo{add plots}

Note: The small but statistically significant variations in the untyped running
 mean that overheads from one version of Racket are
 not directly comparable to another for those benchmarks,
 but such are the hazards of benchmarking a large system.
At any rate, we hold that users' decision to invest in gradual typing will
 be influenced mostly by the overhead they witness---regardless of whether
 that overhead is due to enforcing type soundness or because untyped Racket
 is magically faster than all of Typed Racket.
For completeness we list all untyped runtimes in Appendix @todo{ref}.

