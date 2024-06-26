# Are lenses for you?

## It depends

Lenses, like `Access`, are used for getting data from within nested
containers, for putting data in nested containers, and for updating
existing data. They're part of the long tradition of methods to do
CRUD (create/read/update/delete) that include relational databases,
HTTP verbs, and the like. Whether they're worth learning depends on
you and the work you do.

The out-of-the-box, batteries included, `Kernel` module functions
`get_in`, `put_in`, `update_in`, and `pop_in` let you solve some CRUD
problems without writing an annoying amount of bookkeeping code: they allow
short and declarative(ish) solutions. Others, they don't.

Sometimes lenses will work better, and let you write straightforward
solutions when `update_in` and friends would require more convoluted
ones. The question is whether *sometimes* is *often enough*. Not in
some abstract sense, but *for you* (and your team) and for what you do.

How often do you get annoyed writing boilerplate code around nested
data structures? (Or, probably equally important, how often do you not
create a nested structure because working with them is so annoying.)

And is that often enough that spending time seeing if learning lenses
(and using yet another package) is worth it?

(Sometimes `Access` can do things lenses won't, but I don't
think there are that many such cases. I'll point them out as this
series goes along.)

## A note on choosing

It may seem weird and offputting to say you should decide on
lenses based on your personal and team annoyance with traversing nested
structures in a functional language. Surely I should be saying lenses
are better in some absolute sense? Well...

I got my first job as a programmer in 1975 (at the age of 16). I've
seen a *lot* of programmers making judgments about technology new to
them. When they reach for generalizations about "all programmers" or
"all programs", they tend to predict poorly. For example, from about 1983
(when I was a [Common Lisp](https://en.wikipedia.org/wiki/Common_Lisp) implementer) to the early '90s, I heard an
endless number of people say that garbage collection was impractical
for "serious work". Machines (except for
[expensive custom hardware](https://en.wikipedia.org/wiki/Lisp_machine))
objectively just weren't fast enough, and would never *be* fast
enough. Then Java came out, and the conventional wisdom completely
dropped the issue, even for the slow machines of the day. Garbage
collection was now *assumed*: the question was how to use it most
efficiently, except that most programmers never thought about that at
all. They adopted the new ["paradigm"](https://en.wikipedia.org/wiki/Paradigm#Scientific_paradigm) and moved on.)

And don't get me started about the debate (around 1981) of whether C
could ever replace assembly language for serious coding.

In any case: I've seen too often programmer decisions about technology
that are based on personal preference, typically informed by what that
programmer is used to, but – and let me emphasize this – **presented
as something objective**. To that, I repeat the last line of Ernest
Hemingway's
[*The Sun Also Rises*](https://en.wikipedia.org/wiki/The_Sun_Also_Rises):
"wouldn't it be pretty to think so?"

I *don't* think so, so I won't pitch lenses to you as if you were a
dispassionate person optimizing some objective criterion. That is:

1. If you are the exception, someone who really does weigh things objectively –
   and I believe you might exist, you're just exceptional: welcome!
   The series will, I hope, give you enough information to rationally
   judge. But I'm not going to structure my argument around your
   criteria. Sorry!

2. If you accept that you are prone to subjective judgments: welcome!
   I hope to show you why my subjective judgment about lenses just
   might mesh with yours, and that you might find lenses pleasant.

## Efficiency

I suspect lenses are somewhat slower than `Access` functions, which
are in turn somewhat slower than hand-crafted recursion, which would
likely be faster still if done with a
[C](https://www.erlang.org/doc/apps/erl_interface/ei_users_guide) or
[Rust](https://github.com/rusterlium/rustler) (etc.) foreign function
interface. I haven't measured any of them, though. The hoary old
interface applies: you're probably better writing the code in the way
most readable to your team, then optimizing after performance
measurements shows you where the bottlenecks are.

It's worth calling out [Pathex](https://github.com/hissssst/pathex), a
lens-like package said to be faster than `Access`. (I haven't measured that either.)

   