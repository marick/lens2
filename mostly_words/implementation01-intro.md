# Introduction to debugging and `def_maker`

> I really hate this damn machine.    
> I wish that they would sell it.    
> It never does quite what I want,     
> But only what I tell it.    
> – Traditional    

When using simple composed lenses like `Lens.key(:a) |>
Lens.keys([:aa, :bb])`, you don't have to understand what's happening
behind the scenes. The lens descends through key `:a`, then through
keys `:aa` and `:bb`, and either returns a list of values or an
updated complete container (depending on whether you're using `Deeply.get_all` or `Deeply.update`. 

But sometimes – especially if you use some of the more unusual
combining lenses – you'll get surprised. I've reluctantly concluded
that the surest way to un-perplex yourself is to work through the
detailed steps of what's happening in the lens code. To do that, you
need to understand lenses well enough to write one from scratch. That's what this guide is about.

Note: you might want to defer reading this page until you actually
*are* perplexed or need to write a lens maker. Maybe you'll never need it!

----

A lens is an anonymous function created by a *lens maker* (a named
function). You can easily write a lens maker using `def`, but the
`def_maker` macro handles some busywork for you. In either case, the
form of the lens function is fixed: you use a template and fill in
some blanks.

Because the template is somewhat conceptually tricksy, I'll work my
way up to its full glory by going through four versions:

1. make a lens compatible with `Deeply.get_all`.
2. make one compatible with `Deeply.update`. 
3. combine the two into a lens function that works with both.
4. add compatibility with `Access` (so lenses work with `get_in`, `update_in`, and friends).

Then I'll show how this understanding can be used to debug a couple of
lenses that have surprising behavior in pipelines. 

Finally, I'll describe the implementations of some interesting makers,
so that you can pattern your own makers off them, should you want your
own makers.

