#lang scribble/base

@require[
  "benchmark.rkt"
  "common.rkt"
  "typed-racket.rkt"
  "util.rkt"
  (only-in racket/list first last)
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
Adaptor modules (# Adp.) roughly correspond
 to the number of user-defined datatypes in each benchmark.
The ``Annotation'' column is the number of type annotations in the fully typed
 version of the benchmark.@note{The benchmarks use more annotations than Typed Racket requires in practice, as they provide full type signatures for each import, even imports from other typed modules.}
Lastly, the boundaries (# Bnd.) and exports (# Exp.) describe the graph structure of each benchmark.
Boundaries are import statements from one module in the benchmark to another (omits external boundaries).
Exports are identifiers that cross such boundaries statically.
For example, there is one module boundary in @tt{sieve} and nine identifiers cross this boundary.
@; At runtime, these nine identifiers are repeatedly invoked as functions; however, the number of invocations is not part of @figure-ref{fig:bm}.

See the appendix for a precise definition of adaptor modules and figures representing each benchmark as a graph.
Edges in the graphs correspond to module boundaries (# Bnd.).

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
The machine collected data with at most two of its 32 cores.
Each core ran at minimum frequency as determined by the @tt{powersave} CPU governor (approximately @|FREQ-STR|).

For each benchmark, we chose a random permutation of its configurations and ran each configuration through one warmup and one collecting iteration.
Depending on the time needed to collect data for one benchmark's configurations, we repeated this process between @|MIN-ITERS-STR| and @|MAX-ITERS-STR| times per benchmark.

This protocol consistently produced unimodal data for individual configurations.
Furthermore, we have recorded similar performance overhead on three other machines@~cite[tfgnvf-popl-2016].
We are therefore confident that the performance overhead we observed is reproducible across machines and computing environments.
Nevertheless, @secref{sec:threats} reports threats to validity regarding our experimental protocol.

All scripts we used to run our experiments and the data we collected
 are available in the online supplement to this paper and in the @tt{jfp}
 branch of this paper's public repository.@note{@url{https://github.com/nuprl/gradual-typing-performance}}


@; -----------------------------------------------------------------------------
@profile-point{sec:tr:plots}
@section[#:tag "sec:plots"]{Evaluating Performance}

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
        @(apply Figure-ref name*) present our experimental results in a series of overhead graphs.
        As in @figure-ref{fig:suffixtree-plot}, the left column of figures counts @deliverable[] configurations and the right column counts @step["1" "D"] configurations.
        These plots additionally give data for three versions of Racket released between June 2015 and February 2016.
        Data for version 6.2 are thin red curves with short dashes.
        Data for version 6.3 are mid-sized green curves with long dashes.
        Data for version 6.4 are thick, solid, blue curves.
        The typed/untyped ratio for each version appears above each pair of plots.

        @; -- overall, bleak picture
        @(let* ([num-bm (length ALL-BENCHMARKS)]
                [num-bm-str (integer->word num-bm)]
                [max-str (format "~ax" (*MAX-OVERHEAD*))]
                [suffixtree-num-modules (integer->word 6)]
                [num-max-deliverable 9] ; TODO, use *MAX-OVERHEAD*
                [num-max-deliverable-str (integer->word num-max-deliverable)]
                [num-mostly-2-deliverable 6]
                [num-mostly-2-deliverable-str (integer->word num-mostly-2-deliverable)]
                [num-good-slope 8]
                [num-good-slope-str (integer->word num-good-slope)]
                [v-min (first (*RKT-VERSIONS*))]
                [v-max (last (*RKT-VERSIONS*))]
                [absolute-min-overhead "1.2"]
                [absolute-min-overhead-bm "synth"]
               )
          @elem{
            These plots are mostly bad news for Typed Racket.
            First, many benchmarks demonstrate significant performance overhead.
            Out of @|num-bm-str| benchmark programs, @|num-max-deliverable-str| have configurations with over @|max-str| overhead on every version of Racket.
            These extreme configurations are unfortunately common, and many more configurations exhibit lesser performance overhead.
            At least half the configurations in @integer->word[(- num-bm num-mostly-2-deliverable)] benchmarks are not even @deliverable{2}.

            Second, only @|num-good-slope-str| curves have steep slopes.
            Among benchmarks with fewer than @|suffixtree-num-modules| modules, the most common slope is a flat line.
            Such lines imply that the performance of a family of configurations is dominated by a single type boundary.
            For instance, there is one type boundary in @bm[fsm] that adds overwhelming slowdown when present;
             all eight configurations with this boundary have over @|max-str| overhead.
            Benchmarks with @|suffixtree-num-modules| or more modules generally have smoother slopes.
            These do not hit the ``performance wall'' evident in the smaller benchmarks, but still the programmer faces high performance overhead.

            Third, moving from @math{k=0} to @math{k=1} in a fixed version of Racket does little to improve the number of @deliverable{} configurations.
            One type conversion step can eliminate a pathological boundary, such as those in @bm[fsm] and @bm[zombie], but the larger benchmarks have more intricate communication patterns.
            Unless most modules in the program are typed, adding types to one additional module is not likely to improve performance.

            Finally, only four benchmarks run faster when fully typed.
            The rest have typed/untyped ratios of at least 1, despite type specialization in the Typed Racket compiler@~cite[stf-optimization-coaching].
            In the case of @bm[mbta] and @bm[zordoz], these ratios are due to interactions with an untyped library.
            Object-oriented benchmarks such as @bm[take5] and @bm[acquire] suffer overhead from type casts@~cite[tfdffthf-ecoop-2015].
            And as mentioned above, @bm[quadMB] incurs overhead from type-generated predicates.

            On the other hand, the plots offer some good news.
            First, Typed Racket has improved significantly between versions.
            In particular @bm[kcfa], @bm[snake], and @bm[gregor] have many more @deliverable{} configurations on version @|v-max| than on version @|v-min|.

            Second, every benchmark has at least a handful of @deliverable{1.8} configurations.@note{The largest x-intercept is @|absolute-min-overhead|, in @|absolute-min-overhead-bm|.}
            These configurations are a small percentage of the total, but perhaps developers or an automated tool can locate them and avoid the many high-overhead configurations.

            Third, the @bm[lnm] benchmark demonstrates that clients of a typed library have a positive incentive to convert their modules to Typed Racket.
            Doing so can improve the application's performance.
            Racket's contracts are similarly @emph{infectious}@~cite[f-icfp-2014] because they properly attribute blame; new types track blame and remove some dynamic checks.
          })


        @; - canweget dungeon running???

        @; - something about t/u ratio

        @; -- between versions
        @; - generally improving
        @; - class/c bug (explains forth after 6.2?)
        @; - zombie k=1


      }
      (for/list ([p (in-list pict*)]
                 [name (in-list name*)]
                 [i (in-naturals 1)])
        (figure name (get-caption i) p)))))


@; -----------------------------------------------------------------------------
@section[#:tag "sec:compare"]{Comparing Gradual Type Systems}

Overhead plots summarize the high-level performance of gradual type systems, but do not quantify the uncertainty in measurements.
To precisely compare implementations of gradual typing, we must take uncertainty into account@~cite[kj-ismm-2013].
We do so AS FOLLOWS.

@; -- typed/untyped ratio graph, with error bars


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

