#lang scribble/base

@require[
  "benchmark.rkt"
  "common.rkt"
  "typed-racket.rkt"
  "util.rkt"
  (only-in racket/list first last)
  (only-in gtp-summarize/path-util add-commas)
  (prefix-in gtp: (only-in gtp-summarize/summary from-rktd configuration->overhead))
  (only-in gtp-summarize/bitstring natural->bitstring)
  (only-in racket/string string-join)
  (only-in racket/format ~r)
  (except-in gtp-summarize/lnm-parameters defparam)
]

@profile-point{sec:tr}
@title[#:tag "sec:tr"]{Evaluating Typed Racket}

To validate the evaluation method, we apply it to a suite of @integer->word[(count-benchmarks)] Typed Racket programs.
This section introduces the benchmarks, documents our protocol for collecting performance lattice data, and presents the overhead graphs we derived from the data.


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
    Introducing a type boundary between these modules leads to significant overhead.
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
    Every function that crosses a type boundary in @bm[morsecode] operates on strings and integers, thus dynamically type-checking these functions' arguments is relatively cheap.
  })
(cons zombie
  @elem{
    Implements a game where players dodge computer-controlled ``zombie'' tokens.
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
    This change significantly improved the overhead of @bm[zordoz].

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
    Two modules are tightly-coupled to Typed Racket libraries; typing these modules improves performance.
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
    Modules in this benchmark frequently exchange first-order values, such as lists and integers.
  })
(cons take5
  @elem{
    Runs a card game between AI players.
    These AI communicate infrequently, so gradual typing adds relatively little overhead.
  })
(cons acquire
  @elem{
    Simulates a board game via message-passing objects.
    The core game structures are encapsulated within these objects; few higher-order values cross type boundaries.
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
    In other words, the typed program is slower than untyped because it does more work.

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

@Figure-ref{fig:bm} tabulates the size and complexity of our benchmark programs.
The lines of code (Untyped LOC) and number of modules (# Mod.) approximate program size.
    @; Note that the number modules determines the number of gradually typed configurations.
The type annotations (Annotation LOC) are the new lines we added to make the untyped configuration type check.@note{The benchmarks use more annotations than Typed Racket requires because they give full type signatures for each import. Only imports from untyped modules require annotation.}
Adaptor modules (# Adp.) roughly correspond to the number of user-defined datatypes in each benchmark;
 the next section provides a precise explanation.
Lastly, the boundaries (# Bnd.) and exports (# Exp.) distill each benchmark's graph structure.
Boundaries are import statements from one module to another, excluding imports to runtime or third-party libraries.
An identifier named in such an import statement counts as an export.
For example, one import statement in @bm[sieve] names nine identifiers.
The appendix presents full module graphs for all benchmarks.

@figure*["fig:bm" "Static characteristics of the benchmarks"
  @render-benchmarks-table{}
]


@; -----------------------------------------------------------------------------
@profile-point{sec:tr:protocol}
@section[#:tag "sec:protocol"]{Experimental Protocol}

@(define MIN-ITERS-STR "3")
@(define MAX-ITERS-STR "30")
@(define FREQ-STR "1.40 GHz")

To generate all configurations in a benchmark, we usually started with untyped code, manually created the typed configuration, and then automatically generated all mixed configurations from these versions.
There were four complications.

First, the addition of types occasionally required type casts or small refactorings.
For example, the expression @racket[(string->number s)] had type @racket[(U Complex #f)] even when the programmer informally knew the expression would never produce a complex number.
To avoid similar losses of precision, we added runtime checks to the contrary.
As another example, the @bm[quad] benchmark called a library function to partition a @racket[(Listof (U A B))]
 into a @racket[(Listof A)] and a @racket[(Listof B)] using a predicate for values of type @racket[A].
Typed Racket could not ensure that values which failed the predicate had type @racket[B].
We rewrote that call site to satisfy the type checker.

Second, the @bm[fsm], @bm[synth], and @bm[quad] benchmarks came with type annotations.
We had to revise some of these annotations because Typed Racket could not enforce the original types on a type boundary.
For instance, Typed Racket could not impose parametric polymorphism on Racket struct definitions, so we made the core datatypes in @bm[synth] monomorphic.

Third, we converted any contracts in untyped benchmarks to type annotations and in-line assertions.@note{At the time, Typed Racket could not express contracts.}
The @bm[acquire] benchmark in particular used contracts to ensure ordered lists with unique elements.
We added such checks as explicit pre and post-conditions inside the relevant functions.

Fourth, we inserted @emph{adaptor modules} between modules exporting a struct and their typed clients.
Adaptor modules contained only type annotations, ensured a canonical set of types in configurations where the underlying server module was untyped.
The assignment of canonical types was necessary because in Typed Racket each import of an untyped struct generates a unique datatype.
Two typed modules could not share instances of such an untyped struct definition unless they referenced a common import annotation.
It was possible to implement this sharing without the layer of indirection, but adaptor modules provided a uniform solution and did not introduce noticeable overhead.

As for collecting data, we measured the running times of configurations on a Linux machine with two physical AMD Opteron 6376 2.3GHz processors and 128GB RAM.
The machine collected data with at most two of its 32 cores.
Each core ran at minimum frequency as determined by the @tt{powersave} CPU governor (approximately @|FREQ-STR|).

For each benchmark, we chose a random permutation of its configurations, compiled the configurations using the standard settings, and ran each configuration through one warmup and one collecting iteration.
Depending on the time needed to collect data for one benchmark's configurations, we repeated this process between @|MIN-ITERS-STR| and @|MAX-ITERS-STR| times per benchmark.
The overhead graphs in the next section use the mean of these iterations.

Our results are consistent with the data we previously collected for Racket v6.2 using three different machines@~cite[tfgnvf-popl-2016].
We are thereby encouraged that the observed performance overhead is reproducible across machines and computing environments.
@Secref{sec:threats} reports threats to validity regarding our experimental protocol.

Both our experimental scripts and the collected data are available in the online supplement to this paper.


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
        As in @figure-ref{fig:suffixtree-plot}, the left column of figures are cumulative distribution functions for @deliverable[] configurations and the right column are cumulative distribution functions for @step["1" "D"] configurations.
        These plots additionally give data for three versions of Racket released between June 2015 and February 2016.
        Data for version 6.2 are thin red curves with short dashes.
        Data for version 6.3 are mid-sized green curves with long dashes.
        Data for version 6.4 are thick, solid, blue curves.
        The typed/untyped ratio for each version appears above each plot in the left column.

        @; -- overall, bleak picture
        @(let* ([num-bm (length ALL-BENCHMARKS)]
                [num-bm-str (integer->word num-bm)]
                [max-str (format "~a" (*MAX-OVERHEAD*))]
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
            Many curves have low slopes.
            These slopes demonstrate that gradual typing introduces large and widespread performance overhead in our benchmark programs.
            Among benchmarks with fewer than @|suffixtree-num-modules| modules, the most common slope is a flat line near the 50% mark.
            Such lines imply that the performance of a family of configurations is dominated by a single type boundary.
            @; For instance, there is one type boundary in @bm[fsm] that adds overwhelming slowdown when present; all eight configurations with this boundary have over @|max-str| overhead.
            Benchmarks with @|suffixtree-num-modules| or more modules generally have smoother slopes, but five such benchmarks still have low slopes.
            These low slopes carry the same underlying message as the flat lines; for many values of @math{D} between 1 and @|max-str|, few configurations are @deliverable{}.

            For example, consider @math{D=2}.
            In @integer->word[(- num-bm num-mostly-2-deliverable)] of the @|num-bm-str| benchmark programs, @emph{at most} half the configurations are @deliverable{2}.
            The situation is worse for lower (more realistic) overheads, and does not improve much for higher overheads.
            At @math{D=10}, ten benchmarks still have 50% or fewer configurations @deliverable{10}.

            The curves' endpoints describe the extremes of gradual typing.
            The left endpoint gives the percentage of configurations that run at least as quickly as the untyped program.
            Except for @bm[lnm], such configurations are a low proportion of the total.@note{@bm[sieve] is a degenerate case. Only its untyped and fully-typed configurations are @deliverable{1}.}
            The right endpoint shows how many configurations suffer over 20x performance overhead.
            In total, @|num-max-deliverable-str| benchmarks have configurations with such extreme slowdowns.

            Moving from @math{k=0} to @math{k=1} in a fixed version of Racket does little to improve the number of @deliverable{} configurations.
            Given the slopes of the @math{k=0} graphs, this result is not surprising.
            One type conversion step can eliminate a pathological boundary, such as those in @bm[fsm] and @bm[zombie], but the overhead in larger benchmarks comes from a variety of type boundaries.
            Except in configurations with many typed modules, adding types to one additional module is not likely to improve performance.

            On the other hand, subsequent versions of Typed Racket do exhibit less overhead.
            The three slopes for each benchmark are similar, but later versions typically have more @deliverable{} configurations for any fixed @math{D}.
            In particular @bm[kcfa], @bm[snake], and @bm[tetris] doubled the number of @deliverable{8} configurations between versions 6.2 and 6.4.

            The exceptions to this rule are @todo{check}.
            @; If this trend continues, Typed Racket may soon offer sound and performant gradual typing.

            Finally, note that every benchmark has at least a handful of @deliverable{1.8} configurations.@note{The largest x-intercept is @|absolute-min-overhead|, in @|absolute-min-overhead-bm|.}
            These configurations are a small percentage of the total, but perhaps developers or an automated tool can locate them and avoid the many high-overhead configurations.

         @;   Third, the @bm[lnm] benchmark demonstrates that clients of a typed library have a positive incentive to convert their modules to Typed Racket.
         @;   Doing so can improve the application's performance.
         @;   Racket's contracts are similarly @emph{infectious}@~cite[f-icfp-2014] because they properly attribute blame; new types track blame and remove some dynamic checks.
          })

        @; OTHER NOTES
        @; - canweget dungeon running???
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
@; @~cite[kj-ismm-2013].

@; uncertain runtimes, uncertain proportions
@(let* ([S-6.2 (gtp:from-rktd (benchmark-rktd morsecode "6.2"))]
        [S-6.4 (gtp:from-rktd (benchmark-rktd morsecode "6.4"))]
        [num-mod (benchmark->num-modules morsecode)]
        [interesting-config (natural->bitstring 13 #:pad num-mod)]
        [c6.2 (gtp:configuration->overhead S-6.2 interesting-config)]
        [c6.4 (gtp:configuration->overhead S-6.4 interesting-config)]
        [sample-D-str (let ([diff (abs (- c6.4 c6.2))])
                        (~r (+ (min c6.2 c6.4) (/ diff 2)) #:precision '(= 1)))])
@list[@elem{
  To demonstrate the issue, @figure-ref{fig:exact-runtimes} plots our entire dataset for the @bm[morsecode] benchmark.
  The @math{x}-axis has sixteen discrete intervals, one for each @bm[morsecode] configuration.@note{Configuration 0 is untyped and configuration 15 is fully typed. The mapping from @exact{$i \in [1,15]$} to configurations is in the appendix.}
  The @math{y} axis measures running time in milliseconds.
  Each data point is one running time for one configuration.
  These runnings times are coded by the version of Racket that produced them;
   times for v6.2 are red triangles,
   times for v6.3 are green circles,
   and times for v6.4 are blue squares.
  The left-to-right order of points for each configuration and version of Racket
   is the order we obtained the measurements.
  For example, the rightmost triangle for configuration 4 is the final running time we collected for configuration 4 on Racket v6.2.

  Compare @figure-ref{fig:exact-runtimes} with the overhead graph for @bm[morsecode] in @figure-ref{fig:lnm:1}.
  Both graphs reach the same conclusion; namely, @bm[morsecode] has a few configurations that perform better on v6.3 and a few that perform worse on v6.2, but overall performance between versions is similar.
  The overhead graph, however, summarizes each configuration by its mean runtime without communicating the variance between iterations evident in @figure-ref{fig:exact-runtimes}.
  Nevertheless, this variance is low and suggests that the conclusion is in fact statistically significant.

  @; "exact" lessons
  @; - clustered points, unimodal, left-to-right independent
  @; - triangles highest
  @; - have some uncertainty
  }

  @figure["fig:exact-runtimes" "Exact running times"
    @render-exact-plot[morsecode]
  ]
])
    @(define sample-D 2)
    @(define sample-confidence 98)

The challenge is to quantify variance and significance for datasets with exponentially many configurations.
We do so by equipping our performance metrics with confidence intervals@~cite[n-ptrs-1937].
In essence, a confidence interval is a probable bound for the true value of an unknown parameter.
For our purposes, non-overlapping confidence intervals for two unknown parameters serve as evidence that the parameters are truly different.

@Figure-ref{fig:uncertainty} quantifies the uncertainty in the typed/untyped ratio (top plot) and the number of @deliverable[@id[sample-D]] configurations (bottom plot) for each of our benchmark programs.
The @math{x}-axis of both plots represents the @integer->word[(*NUM-BENCHMARKS*)] programs, arranged left-to-right from smallest to largest performance lattice.
As before, each benchmark has data for @integer->word[(length (*RKT-VERSIONS*))] versions of Racket.
The @math{y}-axis of the top plot is the inverse of the typed/untyped ratio; that is, the performance of the untyped configuration divided by the performance of the typed configuration.
Higher @math{y}-values indicate better performance.
The @math{y}-axis of the bottom plot is the percent of configurations that are @deliverable[@id[sample-D]]; again, a larger percentage is better.

Every series of points in the top graph and every bar in the bottom graph is enclosed in an @tt{I}-shaped interval.
On the top graph, these intervals quantify variation among repeated samples of the typed/untyped ratio.
To be precise, each point in the top graph is the untyped runtime from one iteration of the benchmark divided by the typed runtime from the same iteration.
Ratios for subsequent iterations are arranged left-to-right within a column.
The confidence intervals are the @id[sample-confidence]% confidence intervals for each sequence of ratios;
 repeating this experiment and re-computing confidence intervals would, with high probability,
 produce intervals containing the true ratio.@note{``High probability'' is a far better mental model for interpreting @figure-ref{fig:uncertainty} than ``@id[sample-confidence]% confidence''.
  We say @id[sample-confidence]% because we use a critical value of 2.326, but these are not rigorous statistics.
  First, the so-called index method@~cite[f-arxiv-2006] we use to compute confidence intervals for ratios is intuitive, but ad-hoc compared to methods such as Fieller's@~cite[f-rss-1957].
  Second, a small overlap of (precise) @id[sample-confidence]% confidence intervals does not necessarily imply no significant difference at the @~r[(* 0.01 (- 100 sample-confidence)) #:precision '(= 2)] confidence level@~cite[bfwc-pm-2005].}

On the bottom graph, the intervals quantify uncertainty in the number of @deliverable[@id[sample-D]] configurations.
Recall that the overhead graphs in @secref{sec:plots} count the number of configurations with mean runtime at most @math{D} times slower than the mean runtime of the untyped configuration.
The rectangles in @figure-ref{fig:uncertainty} give the same, mean-derived counts for @math{D=@id[sample-D]}.
These counts have some uncertainty because the true overhead of a configuration might lie above or below the overhead determined by its mean running time.@note{Note: the slope of the overhead plots weakly correlates to the risk of confusing true and mean overheads; a steep slope is a higher risk.}
Therefore, if a configuration's @emph{mean overhead} were less than @id[sample-D] but its @emph{true overhead} were greater than @id[sample-D], the mean-based count would over-approximate the number of @deliverable[@id[sample-D]] configurations.
Conversely, under-approximations are possible if the mean overhead exceeds the true overhead.
The error bars around these rectangles therefore count @deliverable[@id[sample-D]] configurations based on the upper and lower bounds of a @id[sample-confidence]% confidence interval derived from our sample overheads.
If the lower confidence bound for one configuration's sequence of ratios was @deliverable[@id[sample-D]] but the same configuration's mean overhead was not @deliverable[@id[sample-D]], the upper error bar would be an additional 1% higher.

As it turns out, there is only one configuration with mean overhead that wavers near the @id[sample-D]x mark.
Every other configuration is stable; furthermore, all configurations are stable for overheads of 1.2x, 1.6x, 8x, and 10x.
These results imply that our mean overheads have relatively small error bounds, such that no configuration's mean overhead is within the noise of the above-mentioned values of @math{D}.

These graphs provide evidence for stronger statements about the relative performance of the three implementations of Typed Racket.
For example,
@itemlist[
  @item{
    Version 6.3 has significantly better typed/untyped ratios than version 6.2 on seven benchmarks.
    These improved benchmarks include @bm[mbta], @bm[zombie], and @bm[zordoz], which were among the highest typed/untyped ratios on v6.2.

         @; ; in fact, the typed/untyped ratios demonstrate that only four benchmarks run faster when fully typed on Racket version 6.4.
         @;   Finally, only four benchmarks run faster when fully typed.
         @;   The rest have typed/untyped ratios of at least 1, despite type specialization in the Typed Racket compiler@~cite[stf-optimization-coaching].
         @;   In the case of @bm[mbta] and @bm[zordoz], these ratios are due to interactions with an untyped library.
         @;   Object-oriented benchmarks such as @bm[take5] and @bm[acquire] suffer overhead from type casts@~cite[tfdffthf-ecoop-2015].
         @;   And as mentioned above, @bm[quadMB] incurs overhead from type-generated predicates.

  }
  @item{
    Version 6.4 has significantly more @deliverable[@id[sample-D]] configurations than version 6.2 on ten benchmarks, and significantly fewer on two benchmarks.
  }
]
Similar graphs can assess the performance of any fixed configuration or @math{D} values.

@; - will need better stats when things cut close
@; - don't really care about means variation with overhead graphs, just look at slope

    @figure["fig:uncertainty" "Measuring Uncertainty"
      @(parameterize([*CONFIDENCE-LEVEL* sample-confidence])
         (render-uncertainty sample-D ALL-BENCHMARKS))
    ]

