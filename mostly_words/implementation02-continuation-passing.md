# Continuation-passing style

It's easier to understand the implementation of lenses if you first
understand
["continuation-passing style"](https://en.wikipedia.org/wiki/Continuation-passing_style). Lenses
don't *exactly* use continuation-passing style, but it's pretty close.

In this style, every function call is a two-part instruction:

1. Dear function, do that thing you do, using these arguments, then...

2. ... do *not* return the result. Instead, pass it to the function I
   also gave you in an argument. That function is called the
   *continuation* (because it continues the overall computation of
   which the function call is a part).

Any function can be converted to continuation-passing style. Here's a
continuation-passing version of `Map.put/3`:

    def map_put(map, key, value, continuation) do
      Map.put(map, key, value)
      |> continuation.()
    end
    
(You can find the code and tests quoted on this page at
[`continuation_passing_test.exs`](../test/mostly_words/tutorial/continuation_passing_test.exs).)
    
And here's a use of `map_put`:

    iex> map_put(%{}, :a, 1, & &1)
    %{a: 1}
    
Here's a more elaborate call that puts two
different key/value pairs into a map:

    iex> map_put(%{}, :a, 1,
                 fn just_created_map ->
                   map_put(just_created_map, :b, 2,
                           & &1)
                 end)
    %{a: 1, b: 2}

There are two continuations here: one that calls another instance of
`map_put`, and one that just returns the final value. The sequence of events is:

1. `map_put` calculates %{a: 1}, and passes it to the bigger continuation.
2. The continuation passes that value on to another `map_put`,
   together with a second continuation, the identity function.
3. The second `map_put` calculates %{a: 1, b: 2} and passes it to the second continuation.
4. The second continuation just returns its value, so...
5. ... the second `map_put` returns the value to...
6. ... the first continuation, which returns it to...
7. ... the first instance of `map_put` which...
8. ... returns it to IEX for printing to the terminal.

(A sufficiently smart compiler could eliminate all but the last
return; indeed, continuation-passing style was invented for use in a
compiler as an intermediate form that lent itself to certain
optimizations.)

The code isn't what you'd call wildly readable. There's a general structure that's obscured by a bunch of constants. Here's the code with the constants marked:

      map_put(%{}, :a, 1,
      ^^^^^^^ ^^^  ^^  ^
              fn just_created_map ->
                map_put(just_created_map, :b, 2,
                ^^^^^^^                   ^^  ^
                        & &1)
                        ^^^^
              end)

Code full of constants can be turned into a function that takes appropriate arguments. Let's pull `%{}` and `& &1`out first:

    two_puts =
      fn initial_value, final_continuation ->
         ^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^
        map_put(initial_value, :a, 1,
                ^^^^^^^^^^^^^
                fn just_created_map ->
                  map_put(just_created_map, :b, 2,
                          final_continuation)
                          ^^^^^^^^^^^^^^^^^^
                end)
      end

    iex> two_puts.(%{}, & &1)
    %{a: 1, b: 2}

Next let's extract the two explicit calls to `map_put` into two "step"
arguments that give functions for the internal code to execute:

    step_combiner =
      fn step1, step2 ->
         ^^^^^  ^^^^^
        fn initial_value, final_continuation ->
          step1.(initial_value,
          ^^^^^  fn just_created_map ->
                   step2.(just_created_map,
                   ^^^^^  final_continuation)
                 end)
        end
      end

The `step_combiner` is a function that returns a function that
executes two computations in a row, passing the first result to the
second computation. It could be used like this:

    two_puts =
      step_combiner.(
        fn map, continuation ->
          map_put(map, :a, 1, continuation)
        end,
        fn map, continuation ->
          map_put(map, :b, 2, continuation)
        end)

    iex> two_puts.(%{}, & &1)
    %{a: 1, b: 2}


Let's do a little cleanup and use named functions instead of anonymous functions. Let's make the steps with this function:


    def make_put_fn(key, value) do
      fn map, continuation ->
        Map.put(map, key, value) |> continuation.()
      end
    end

(I expanded out `map_put` because I won't be using it any more.)

Let's also make `step_combiner` a named function:

    def step_combiner(step1, step2) do
      fn initial_value, final_continuation ->
        step1.(initial_value,
               fn step2_value ->
                 step2.(step2_value,
                        final_continuation)
               end)
      end
    end

Putting that together, we get:

    iex> step1 = make_put_fn(:a, 1)
    iex> step2 = make_put_fn(:b, 2)

    iex> put_twice = step_combiner(step1, step2)
    iex> put_twice.(%{}, & &1)
    %{a: 1, b: 2}

Say, that looks kind of familiar:

    iex> lens1 = Lens.key(:a)
    iex> lens2 = Lens.key(:b)
    iex> two_step = Lens.seq(lens1, lens2)
    iex> Deeply.put(%{a: %{b: 2}}, two_step, :NEW)
    %{a: %{b: :NEW}}

In fact, I can make it even more familiar. First, a function that
launches the combined step and supplies the identity function:

    def do_to(structure, step) do
      step.(structure, & &1)
    end

Second, a variant `make_put_fn` that takes a previous step and combines it with the one being created:

    def make_put_fn(previous, key, value) do
      step_combiner(previous, make_put_fn(key, value))
    end

And now:

    iex> two_step = make_put_fn(:a, 1) |> make_put_fn(b: 2))
    iex> do_to(%{c: 3}, two_step)
    %{a: 1, b: 2, c: 3}

