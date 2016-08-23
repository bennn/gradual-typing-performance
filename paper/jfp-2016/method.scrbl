#lang scribble/base

@require[
  "common.rkt"
  "util.rkt"
  "benchmark.rkt"
  benchmark-util/data-lattice
  "typed-racket.rkt"
  (only-in pict blank hc-append scale)
  (only-in with-cache *use-cache?*)
  (only-in gtp-summarize/summary
    from-rktd
    get-num-modules
    get-num-iterations
    D-deliverable
    get-num-configurations)
  (only-in gtp-summarize/lnm-plot
    count-configurations/mean)
  (except-in gtp-summarize/lnm-parameters defparam)
]

@profile-point{sec:method}
@title[#:tag "sec:method"]{Evaluation Method}

Performance evaluation for gradual type systems must reflect how
 programmers use such systems.
Migrating an entire project from untyped to typed is rare,
 while incremental transition is common.
Consequently, programmers tend to judge the performance of a gradual type system @emph{locally},
 by comparing the performance of an incrementally modified program against the program's previous running version.
If type-driven optimizations result in a performance improvement, all is well.
Otherwise, the programmer may seek ways to reduce the cost of type boundaries.
As the program evolves, this process repeats.

We turn this observation into an evaluation method in three stages:
 first by describing the @emph{space} over which a performance evaluation must take place,
 second by giving @emph{metrics} relevant to the performance of a gradually typed program,
 and third by introducing a visualization that concisely presents the metrics on exponentially large datasets.


@; -----------------------------------------------------------------------------

@section{Performance Lattice}

The promise of Typed Racket's macro-level gradual typing is that programmers may
 add types to any subset of the modules in an untyped program.
A comprehensive performance evaluation must therefore consider the space of
 @emph{configurations} a programmer could possibly create by typing some modules.
That is, all ways of choosing a single module to type, all ways of choosing two
 modules to type, and so on to include every combination of typed and untyped modules.
We describe this space as a lattice.
@itemlist[
  @item{
    A (@emph{program}) @emph{configuration} is a sequence of
     @math{N} modules. Each module is either typed or untyped.
  }
  @item{
    For a fixed sequence of @math{N} modules there are @exact{$2^N$} possible
     configurations.
  }
  @item{
    Let @math{S} be the set of all configurations for @math{N} modules.
    For @exact|{$c \in S$}| and @exact|{$i \in [0, N)$}|,
     let @exact|{$c(i) = 1 \mbox{ iff the } i^{\emph{th}}$}| module in the sequence is typed
     and
     let @exact|{$c(i) = 0 \mbox{ iff the } i^{\emph{th}}$}| module in the sequence is untyped.
  }

  @item{
    Define @exact|{$\leq$}| (a subset of @exact|{$S \times S$}|) as:
     @exact|{$c_1 \leq c_2$}|
     if and only if
     @exact|{$c_1(i) = 1$}|
     implies
     @exact|{$c_2(i) = 1$}|
     for all @exact|{$i \in [0, N)$}|.
  }

  @item{
    @exact|{$(S, \leq)$}| is a complete lattice; henceforth, a @emph{performance lattice}.
    The fully untyped configuration is the
     bottom element and the fully-typed configuration is the top element.
  }

  @item{
    Define an indexed @emph{type conversion} relation @exact{$\rightarrow_k$} (a subset of @exact{$\leq$}) as:
     @exact{$c_1 \rightarrow_k c_2$} if and only if @exact{$c_1 \leq c_2$}
     and the sum @exact{$\,\Sigma_i\,\big[c_2(i) - c_1(i)\big]$} is less than or equal to @exact{$k$}.
    If @exact|{$c_1 \rightarrow_k c_2$}| we say that @exact{$c_2$} is reachable from
     @exact{$c_1$} in at most @exact{$k$} type conversion steps.
  }
]

@(define suffixtree-lattice-version "6.2")
@(define S (from-rktd (benchmark-rktd suffixtree suffixtree-lattice-version)))
@(define suffixtree-num-modules     (integer->word (get-num-modules S)))
@(define suffixtree-num-configs     (get-num-configurations S))
@(define suffixtree-num-configs-str (number->string suffixtree-num-configs))
@(define suffixtree-num-iters       (number->string (get-num-iterations S)))
@(define suffixtree-sample-D        2)
@(define suffixtree-num-D           ((D-deliverable suffixtree-sample-D) S))
@(define suffixtree-num-D-str       (integer->word suffixtree-num-D))
@(define suffixtree-sample-k        1)
@(define suffixtree-num-k           ((count-configurations/mean S suffixtree-sample-k) suffixtree-sample-D))
@(define suffixtree-num-k-str       (integer->word suffixtree-num-k))

A performance lattice collects one program's configurations.
Equipped with a labeling @exact{$l$} such that @exact{$l(c)$} characterizes the
 performance of configuration @exact{$c$}, a lattice is a full description of
 the program's performance under gradual typing.

@Figure-ref{fig:suffixtree-lattice} is a labeled lattice for @bm[suffixtree], a mid-sized program from our benchmark suite.
The program consists of @|suffixtree-num-modules| modules, thus the lattice has @|suffixtree-num-configs-str| configurations.
Each configuration is rendered as a @|suffixtree-num-modules|-segment rectangle.
The bottom element in the lattice represents the untyped configuration.
The first level of the lattice represents all configurations with one typed module;
 these configurations' rectangles have 1 filled segment.
In general the @exact|{$i^{\emph{th}}$}| level of the lattice represents all configurations
 with @math{i} typed modules as rectangles with @math{i} filled segments.

The label below each rectangle is that configuration's overhead@note{Ratio of two means; each mean is over @|suffixtree-num-iters| samples.}
 relative to the untyped configuration.
@;For instance, the fully typed configuration runs 40% faster than the untyped configuration
@; and the slowest configuration is @id[@round[@max-overhead[@[benchmark-rktd suffixtree "6.2"]]]]x slower than untyped.
With this data, a language implementor can answer nearly any question about this benchmark's
 performance overhead due to gradual typing.
For instance, @|suffixtree-num-D-str|
 configurations run within a @id[suffixtree-sample-D]x overhead
 and @|suffixtree-num-k-str|
  configurations are at most @id[suffixtree-sample-k] type conversion step
  from a configuration that runs within @id[suffixtree-sample-D]x overhead.

A performance lattice, however, is a poor visual aid for answering such questions.
Images such as @figure-ref{fig:suffixtree-lattice} do not scale.
@(let* ([too-many-modules 8]
        [num-bm-with-too-many (length (filter (lambda (b) (< too-many-modules (benchmark->num-modules b))) ALL-BENCHMARKS))])
  @elem{
     @string-titlecase[@integer->word[num-bm-with-too-many]]
      of our benchmarks have
      over @integer->word[too-many-modules] modules;
      their lattices do not fit in print.
  })
Realisitic programs will be much larger.
For example the Typed Racket @library{plot} library has over 80 modules.

    @figure*["fig:suffixtree-lattice" @elem{Performance overhead in @bm[suffixtree], on Racket v@|suffixtree-lattice-version|.}
      @(parameterize ([*LATTICE-CONFIG-MARGIN* 3]
                      [*LATTICE-LEVEL-MARGIN* 8]
                      [*LATTICE-FONT-SIZE* 9]
                      [*LATTICE-BOX-HEIGHT* 6]
                      [*LATTICE-BOX-WIDTH* 3]
                      [*LATTICE-BOX-SEP* 0]
                      [*LATTICE-BOX-TOP-MARGIN* 0]
                      [*LATTICE-TRUNCATE-DECIMALS?* #t]
                      [*LATTICE-BORDER-WIDTH* 0.5]
                      [*LATTICE-BOX-BOT-MARGIN* 1])
        (render-data-lattice suffixtree suffixtree-lattice-version))
    ]

@; -----------------------------------------------------------------------------
@section[#:tag "sec:measurements"]{Performance Metrics}

The most basic question about a gradually typed language is
 how fast fully-typed programs are in comparison to their fully untyped relative.
In principle, static types enable optimizations and can serve in place of the
 runtime tags used in safe dynamic languages.
The net effect of such improvements may, however, be offset by runtime type checks
 in programs that rely heavily on an untyped library.
Hence we characterize the relative performance of fully-typed programs
 using a ratio to capture the possibility of speedups and slowdowns.

@; Determining whether speedups or slowdowns are the norm for fully typed programs
@;  may influence a software team's decision to experiment with gradual typing.

    @def[#:term "typed/untyped ratio"]{
     The typed/untyped ratio of a performance
      lattice is the time needed to run the top configuration divided by the
      time needed to run the bottom configuration.
    }

For users of a gradual type system, the important performance
 question is how much overhead their current configuration suffers
 relative to the original program.
If the performance overhead is low enough, programmers can release the
 configuration to clients.
Depending on the nature of the software and clients' expectations,
 an appropriate substitute for "low enough" might take any value between zero overhead
 and an order-of-magnitude slowdown.
To account for these varying requirements, we use
 the following parameterized definition of a deliverable configuration.

    @def[#:term @list{@deliverable{}}]{
     A configuration
      is @deliverable{} if its performance is no worse than a
      @math{D}x slowdown compared to the untyped configuration.
    }

    @; NOTE: really should be using %, but Sec 4 shows why we stick to x

If a software project is currently in a non-@deliverable[] configuration,
 the next question is how much work a team must invest to reach a
 @deliverable[] configuration.
We propose as a coarse measure of "work" the number of modules that must be
 annotated with types before performance improves.

    @def[#:term @list{@step{}}]{
     A configuration is @step[] if it is at most @math{k}
      type conversion steps from a @deliverable{} configuration.
    }

@profile-point{sec:method:example}
@(define sample-data
  (let* ([mean+std* '#((20 . 0) (15 . 0) (35 . 0) (10 . 0))]
         [mean (lambda (i) (car (vector-ref mean+std* i)))])
    (lambda (tag)
      (case tag
       [(c00) (mean 0)]
       [(c01) (mean 1)]
       [(c10) (mean 2)]
       [(c11) (mean 3)]
       [(all) mean+std*]
       [else (raise-user-error 'sample-data "Invalid configuration '~a'. Use e.g. c00 for untyped." tag)]))))
@(define (sample-overhead cfg)
  (ceiling (/ (sample-data cfg) (sample-data 'c00))))

Let us illustrate these terms with an example.
Suppose we have a project with
 two modules where the untyped configuration runs in @id[(sample-data 'c00)]
 seconds and the typed configuration runs in @id[(sample-data 'c11)] seconds.
Furthermore, suppose the gradually typed configurations run in
  @id[(sample-data 'c01)] and @id[(sample-data 'c10)] seconds.
@Figure-ref{fig:demo-lattice} is a performance lattice for this hypothetical program.
The label below each configuration is its overhead relative to the untyped configuration.

    @figure["fig:demo-lattice" "Sample performance lattice"
      (parameterize ([*LATTICE-CONFIG-MARGIN* 30]
                     [*LATTICE-LEVEL-MARGIN* 4]
                     [*LATTICE-BOX-SEP* 0])
        (make-performance-lattice (sample-data 'all)))
    ]

@(let ([tu-ratio (/ (sample-data 'c11) (sample-data 'c00))]
       [t-str @id[(sample-overhead 'c11)]]
       [g-overhead (inexact->exact (max (sample-overhead 'c10) (sample-overhead 'c01)))])
  @elem{
    The typed/untyped ratio is @id[tu-ratio],
     indicating a performance improvement due to adding types.
    The typed configuration is also
      @deliverable[t-str]
      because it runs within a @elem[t-str]x
      slowdown relative to the untyped configuration.
    Both gradually typed configurations are
      @deliverable[@id[g-overhead]]
      because they run within @id[(* g-overhead (sample-data 'c00))] seconds.
    Lastly, these configurations are @step[t-str t-str]
     because each is one conversion step
     from the fully-typed configuration.
  })

The ratio of @deliverable{D} configurations in such a lattice is a measure of
 the overall feasibility of gradual typing.
When the ratio is high, then no matter how the software evolves performance will
 likely remain acceptable.
Conversely, a low ratio means a team may struggle to recover performance after
 incrementally typing a few modules.
Practitioners with fixed performance requirements can therefore use the number
 of @deliverable[] configurations to extrapolate the performance of a gradual type system.


@; -----------------------------------------------------------------------------
@section[#:tag "sec:graphs"]{Overhead Graphs}

@; pre-reqs to plots
@; - D parameter, varying requirements
@; - 

@; SECONDARY
@; - location of good configs, relation to one another

@(render-lnm-plot
  #:rktd*** (list (list (list (benchmark-rktd suffixtree suffixtree-lattice-version))))
  (lambda (pict*)
    (list
      @figure*["fig:suffixtree-plot" @elem{Overhead graphs for @bm[suffixtree], on Racket v@|suffixtree-lattice-version|.}
        (car pict*)
      ]
      @; less than half of all @bm[suffixtree] configurations run within a @id[(*MAX-OVERHEAD*)]x slowdown.
      @elem{
        The main lesson to extract from a performance lattice is the number of
         @deliverable{} configurations.
        The plot on the left half of @figure-ref{fig:suffixtree-plot} presents this
         information for the @bm[suffixtree] benchmark.
        On the x-axis, possible values for @math{D} range continuously from one to @integer->word[(*MAX-OVERHEAD*)].
        Dashed lines to the left of the 2x tick pinpoint overheads of 1.2x, 1.4x, 1.6x, and 1.8x.
        To the right of the 2x tick, similar dashed lines pinpoint 4x, 6x, 8x, etc.
        The y-axis gives the proportion of configurations in the lattice that
         suffer at most @math{D}x performance overhead.
        Using this plot, one can confirm our earlier observation that @|suffixtree-num-D-str|
         of the @|suffixtree-num-configs-str| configurations
         (@(id (round (* 100 (/ suffixtree-num-D suffixtree-num-configs))))%)
         run within a @id[suffixtree-sample-D]x overhead.

        Viewed as a cumulative distribution function, the plot demonstrates
         a tradeoff between performance overhead and
         the number of deliverable configurations.
        In this case, the shallow slope implies that the tradeoff is poor;
         few configurations become deliverable as the programmer accepts a larger performance overhead.
        The ideal slope would have a steep incline and a large y-intercept,
         meaning that very few configurations suffer large overhead and many
         run faster than the untyped baseline.

        @;Nonetheless, the plot effectively summarizes this large dataset.
        @;Similar plots will handle arbitrarily large programs.

        The plot on the right half of @figure-ref{fig:suffixtree-plot} gives
         the number of @step{1} configurations.
        A point @math{(X,Y)} on this plot represents the percentage @math{Y}
         of configurations @exact{$c_1$} such that there exists a configuration
         @exact{$c_2$} where @exact{$c_1 \rightarrow_1 c_2$} and @exact{$c_2$}
         runs at most @math{X} times slower than the untyped configuration.@note{Note that @exact{$c_1$} and @exact{$c_2$} may be the same. They are definitely the same when @exact{$c_1$} is the fully-typed configuration.}
        Intuitively, this plot has a similar shape to the (0-step) @deliverable[] plot
         because accounting for one type conversion step only makes more configurations ``deliverable''.
        It does not change the overall characteristics of the benchmark.

        These @emph{overhead plots} concisely summarize the @bm[suffixtree] dataset.
        The same technique scales to arbitrarily large benchmarks.
        Furthermore, one can make high-level comparisons between two implementations
         of gradual typing by plotting their curves on the same axes.
      })))

@subsection{Assumptions and Limitations}

Plots in the style of @figure-ref{fig:suffixtree-plot} rest on two assumptions
 and evince two significant limitations, which readers
 must keep these in mind when interpreting our results.

@; - assn: log scale
The @emph{first assumption} is that configurations with less than 2x overhead are significantly
 more practical than configurations with over 10x overhead.
Hence the plots use a log-scaled x-axis
 to encourage fine-grained comparison in the 20-60% overhead range
 and simultaneously blur the distinction between, e.g., 14x and 18x slowdowns.

@; Zorn: 30% of execution time in storage management "represent the worst-case overhead that that might be expected to be associated with garbage collection."

@; - assn: 20x
The @emph{second assumption} is that configurations with more than 20x
 overhead are completely unusable in practice.
Pathologies like the 100x slowdowns in @figure-ref{fig:suffixtree-lattice}
 represent a challenge for implementors, but if these overheads suddenly
 dropped to 30x the configurations would still be useless to developers.

@; - assn: ok to take means
@; meh whocares

@; - limit: no identity, no relation between configs (where is typed?)
The @emph{first limitation} of the overhead plots is that they hide
 configurations' identity.
One cannot distinguish the fully-typed configuration; moreover,
 the @exact{$\leq$} and @exact{$\rightarrow_k$} relations are lost.
To compensate for the former we give the typed/untyped ratio above the left plot.
Unfortunately, the other configurations remain anonymous.

@; - limit: angelic choice
The @emph{second limitation} is that the @step{1} plot optimistically chooses the
 best type conversion step.
In a program with @math{N} modules, a programmer has up to @math{N} type conversion steps to choose from,
 some of which may not lead to a @deliverable[] configuration.
For example, the untyped configuration in @bm[suffixtree] is @step["1" "2"],
 but only one of the six possible steps leads to a @deliverable{2} configuration.
