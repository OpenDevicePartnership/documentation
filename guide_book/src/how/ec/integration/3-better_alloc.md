# Improving allocation strategies
In all of our previous examples, we have used the `StaticCell` type to manage our component allocations. This has worked well for our simple examples, but it was never the best approach.  Most notably, it forces us use the `duplicate_static_mut!` macro that uses declared `unsafe` casts to allow us to borrow a mutable reference more than once. This is not a good practice, and we should avoid it if possible.
Fortunately, there is an alternative.  It's not perfect, but it does allow us to resolve a static with more than a one-time call to `init` the way `StaticCell` does.  `OnceLock` is a type that is defined in both `std::sync` and in `embassy::sync`.  The `embassy` version is designed to work in an embedded context, and supports an asynchronous context, so we will use this version for our examples.
## Using `OnceLock`
The `OnceLock` type is a synchronization primitive that allows us to initialize a value once, and then access it multiple times. While this might seem to be the obvious alternative to `StaticCell`, it does have some limitations. Most notably, it does not allow us to borrow a mutable reference to the value after it has been initialized. This means that we cannot use it to manage mutable state in the same way that we do with `StaticCell`. So if we need more than one mutable reference to a value, we would still need to use `StaticCell` + `duplicate_static_mut!` or some other approach.

Fortunately, we have another approach in mind.

### Changing to `OnceLock` here
In earlier examples we used `StaticCell` (and oftentimes `duplicate_static_mut!`) to construct global singletons and pass `&'static mut references` into tasks. That worked in context, but it becomes easy to paint oneself into a corner: once `&'static mut` is handed out, it can be tempting to duplicate it, which breaks the `unsafe` guarantees and can violate Rust’s aliasing rules.  

`embassy_sync::OnceLock` provides a safer pattern for most globals. It lets us initialize a value exactly once (`get_or_init`) and __await its availability__ from any task (`get().await`) - avoiding the need for separate 'ready' signals. Combined with interior mutability (`Mutex`), we can share mutable state safely across tasks without ever forging multiple `&'static mut` aliases.

> ## OnceLock vs. StaticCell
> - `StaticCell` provides a mutable reference. A mutable reference may be more useful for accessing internals.
> - `OnceLock` provides a non-mutable reference.  It may not be as useful, but can be passed about freely
> - a `OnceLock` containing a `Mutex` to a `StaticCell` entity may be passed around freely and the mutex can resolve a mutable reference.
> -----


We still keep `StaticCell` for the cases where a library requires a true `&'static mut` for its entire lifetime. Everywhere else, `OnceLock + Mutex` is simpler, safer, and matches Embassy’s concurrency model.

We will be switching to this pattern in our examples going forward, but we will not necessarily update previous usage in the previously existing example code.  
Consider the old patterns we have learned up to now to be deprecated. This new paradigm can be a little awkward to bend one's head around at first, but the simplicity and safety of the end result is undeniable.



