

# A quick look at Rust

If you are new to Rust, the venerable "Rust Book" is probably your best bet: 
[The Rust Programming Language](https://doc.rust-lang.org/stable/book/)

and a great sandbox to play in while learning can be found at [The Rust Playground](https://play.rust-lang.org/)

###  But before  you run off to do that...
Let's look a little at what Rust has to offer first.

___The basics are very important to learn because Rust builds on itself and the advanced features are made possible by
leveraging the advantages of the basic ones.  Most of these have to do with the type and memory safety models that are fundamental to the Rust proposition.___

There are several parts to the rust toolchain that you should be aware of to start. 

### cargo 
Cargo is an all-around utility player for the rust environment.  It is many things:
- a build manager
- a package manager
- a linter / static analyzer
- a documentation engine
- a test runner
- an extensible system driven by installed modules

### rustup
While Cargo is your go-to player for building with a toolchain, `rustup` is used to setup and modify the toolchain for different needs.

Among its other uses, you may want to familiarize yourself with `rustup doc` which will open a locally-sourced web book for Rust documentation that can be used offline.


### rustc
Rust is a highly optimized compiled language. It's compiler is called `rustc`.

Typically `rustc` is not invoked directly; it is usually invoked with `cargo build`

The compiler is thorough and strict by design.  Clean code is required on your part. Unused variables or mis-assigned variable types will result in compile errors.
- The compiler controls and understands memory allocation and deallocation
- It tracks borrows/references (borrow checking)
- Expands macros

Although some might accuse the Rust compiler of being deliberately unforgiving and opinionated, it is not heartless.  It will tell you when you've done something wrong, and it will ask for additional information if it can't figure it out on its own (type, lifetime of borrowed values, etc)

#### Statements and Expressions
    - Like many languages, Rust is primarily an expression-based language, where an expression produces a result or an effect.
    - Multiple expression types:
        - Literal
        - Path
        - Block
        - Operator
        - Struct
        - Tuple
        - Method
        - Closure
        - etc
    - Expressions may be nested and obey an evaluation ordering

    ```
    let y = 5;
    let y = { let x = 5; x + 6; };
    ```

#### Variable binding and ownership

In other languages, a "let" statement specifies an assignment.
In Rust, a "let" statement creates a variable binding. At first glance, this may seem the same, but there are important differences. A variable binding includes:
- Name of the binding
- Whether or not the value is mutable (default is false)
- The type of the value (based on type annotations, inferred by the compiler
or default associated with literal expression)​
- A value or backing resource (memory allocated on stack or heap)​
- Whether or not this binding "owns" the value.


 #### Binding examples (Primitive types)   
 ```
 fn main() {​
    // name: x, mutable: false, type: i32, value: 5 (stack), owner: true​
    let _x = 5;​
​
    // same result except with explicit type annotation of i32​
    let _x: i32 = 5; ​
​
    // now with unsigned integer​
    let _x: u32 = 5; ​
​
    //now mutable​
    let mut _x: u32 = 5; ​

    // creates 2 immutable variable bindings for x and y ​
    // using a tuple expression with integer literal expressions 1 and 2​
    let (_x, _y) = (1, 2); ​
​
    // now x & y are mutable​
    let (mut _x, mut _y) = (1, 2); ​
}
 ```       

#### Copy semantics and Move semantics

Consider this code:

```
fn copy_semantics() {​
    let x = 5;​
    let y = x;​
}
```

This binds the value 5 to 'x' and then binds the value of 'x' to 'y'.  So, in the end x == 5 and y == 5.
No surprise there, but it should be understood that this is true because the primitive types for this implement the "Copy" trait that allows this.

Now let's look at another bit of code

```
fn move_semantics() {
    // String does not implement the copy trait... ​

    let message = String::from("hello Rustaceans");
    let mut _hello = message;


    println!("{}", message);
}
```
If your run this code in the Rust Playground you will see the following output:

```
Exited with status 101

error[E0382]: borrow of moved value: `message`
 --> src/main.rs:8:20
  |
4 |     let message = String::from("hello Rustaceans");
  |         ------- move occurs because `message` has type `String`, which does not implement the `Copy` trait
5 |     let mut _hello = message;
  |                      ------- value moved here
...
8 |     println!("{}", message);
  |                    ^^^^^^^ value borrowed here after move
  |
  = note: this error originates in the macro `$crate::format_args_nl` which comes from the expansion of the macro `println` (in Nightly builds, run with -Z macro-backtrace for more info)
help: consider cloning the value if the performance cost is acceptable
  |
5 |     let mut _hello = message.clone();
  |                             ++++++++

For more information about this error, try `rustc --explain E0382`.
error: could not compile `playground` (bin "playground") due to 1 previous error

```
Types that implement the Copy trait (like integers and booleans) are duplicated on assignment. For other types, ownership is transferred.

Simple primitive types implement the Copy trait — a marker trait indicating that values of a type can be duplicated with a simple bitwise copy

So you can see, the rust compiler, despite being picky, is very helpful.  It explains exactly what is happening here:

String does not implement the "Copy" trait, so an assignent 'moves' the value from 'message' to '_hello' so that when we try to 
reference 'message' later in the print macro, we see the value is no longer there.  It even suggests some possible alternatives we might try.

#### Allocating, Deallocating, and scope
- Memory is allocated when the result of an expression is assigned to a variable binding
- Memory is deallocated when the variable binding that is the owner of the value goes out of scope
- For non-primitive types (on the heap), you may call the `drop` function (trait) for resources that _you_ control the lifetime scope for.
- The drop trait should be custom implemented for resource types that have specific destructor needs.
- Rust calls drop() automatically when a value goes out of scope, but you can override it via the Drop trait if your type needs custom cleanup logic (e.g. closing a file or freeing a resource).

#### Rust ownership rules
- Each value in rust has an owner (from a variable binding)
- There can only be __one__ owner at a time
- When an owner goes out of scope, the value will be dropped.

#### Borrowing
Borrowing is the term used for a copy-by-reference. For example:

```
fn borrowing() {​
    let mut x: String = String::from("asdf");​
​
    // Borrow is a verb… Borrowing a value from the owner​
    // The result of a borrow is a reference; below an immutable reference​
    let _y: &String = &x; ​
    // name: y, mutable: false, type: String, value: -> x, owner: false; an immutable reference​

    // Mutable borrow... the variable binding you are borrowing must be mutable​
    let _z: &mut String = &mut x;​
    // name: z, mutable: true, type: String, value: -> x, owner: false; a mutable reference​

    // You can borrow values stored on the heap or on the stack​
    let n: i32 = 5;​
    let _z: &i32 = &n; //is valid… same rules apply as for complex types​
}
```

##### Borrowing rules
- Only 1 _mutable_ borrow/reference at a time
- As many _immutable_ borrows as you like
- If you have 1 or more immutable borrows and 1 mutable borrow, attempting to use any of the immutable borrows _after the value
has changed_ will result in a compile error

Rust uses lifetimes to ensure that borrowed references don’t outlive the data they point to. While often inferred by the compiler, they become important in more advanced usage.


#### Functions
Rust functions look much like function definitions from other languages.  Here's some examples:

```
// A function that takes no parameters returns no useable result (unit type)​
fn do_something() -> () {}​

// equivalent to above… more typical​
fn do_something() {} ​

// this returns an i32 with value 3… ​
// remember return statement is not needed… just leave off the semi-colon​
fn get_three()-> i32 {​
    3​
}​
```

- The function starts with `fn`.  
- Rust style conventions prefer "snake case" (underscore separated lowercase words) style for the function name.
- Functions take parameters which are listed within parenthesis following the function name.
- Functions that return a type denote their return type with -> `<type>` after the parameter list.
- The function body is within { } brackets.
- The result of the last expression executed becomes the return value if no 'return' keyword is encountered.
- The return type () is called the unit type — it’s like void in C/C++, representing ‘no meaningful value’.

#### Function parameters
- parameters must have a type annotation
- all parameters will be copied, moved, or borrowed from their origins and delivered into the scope of the function (the parameter definition should indicate if they expect a borrow/reference, or an actual value).

```
fn do_some_things(x: i32, y: String, z: &String, a: &mut String) {}​
```
- x will be a copied value (from i32 primitive)
- y will be a moved value (from the string)
- z will be an immutable borrowed reference
- a will be a mutable borrowed reference


#### Tuples
- Tuples are primitive types that contain a finite sequence ​
- Tuples are heterogenous, the sequence does not need to be of the same type​
- Tuples are a convenient way of returning multiple results from a function​
- Tuples are often used with enums to associate one or more values with an enum variant​

_example:_
```
let x: (&str,i32, char) = ("hello", 42, 'c')
```
In the example we define a tuple consisting of three element types: A string reference, a 32-bit integer, and a character. Then we assign literal values for this tuple definition to the binding variable 'x'.


#### Struct 
A Struct (structure) in Rust is much like a structure definition in several other languages.

For example:
```
struct Example
{
    foo: String,
    bar: i32,
    baz: bool
}
```

There is also the concept of a 'tuple struct' which is a convenient way to give a name to a tuple that can be treated like a structure, such as the Tuple example we visited above:
```
struct MyTupleStruct(&String, i32, char)
```
Remember, tuples can have any number of elements in the sequence.

#### Enum, Option, and Result
An enum is a way of saying that a value is one from a set of possible values.  Most languages have some form of enum, but Rust
has an particularly robust level of support around this construct.

Consider this example from the "Rust Book":

```
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(i32, i32, i32),
}
```
One can imagine "Message" being used to direct some operation to do one of the four listed things.  But note that each of these "directives" has annotations to describe the associated data type that accompany it.  "Quit" needs no parameters, "Move" comes with structured data for x and y, "Write" is passed a String, and "ChangeColor" gets a Tuple. 

##### Option
Option is a way to handle Null values in a way a little different from some other languages.  An Option is basically a way to say that something has a value or it has no value (Some or None). Option is an enum that is part of the standard Rust library.
Since `Option<T>` is not the same type as `T`, the compiler will not allow an evaluation of a possible Null value.
You can also use the `is_some()` and `is_none()` functions of an option to determine if it has a value.

##### Result
Where Option is the state of "Some or None" Result is the state of "Ok or Err".  

`Option<T>` is used when a value may or may not be present. `Result<T, E>` is used when a function may succeed (Ok) or fail (Err). Both are enums and must be handled explicitly.

Any operation or function that is executed
may potentially fail, and Rust does not employ any sort of try/catch or "on_error" redirections found in other languages.
Error conditions are a fact of life and as such are part of the result of doing something. Getting used to evaluating the return value of a function operation may seem annoying at first, but it is actually pretty liberating because it generally simplifies error handling. 

Let's consider this function:

```
fn do_something() -> Result<String, std::io::Error> {
    let x:String = "hooray".to_string();
    return Ok(x);
}
```
We can see this function returns the "Ok" result (we don't create an error case in this example).
Of course, unless we explicitly documented it, the caller has no idea there will not be an error, so it handles it like so:
```
fn main() {
    
    let x = do_something();
    let y = match x {
        Ok(s) => s,
        Err(_e) => panic!("Oh noes!")
    };
    println!("{}", y);
}
```
The error case never occurs, but if it did, it would probably be inadvisable to simply call panic! as a result. Of course, sometimes
there are no good choices, but especially in firmware driver code, casually throwing panic! exceptions is not a good idea.

On that note, you will encounter a lot of sample code from the web and elsewhere that simply advise calling `.unwrap()` on an option or a result. While often used in examples or quick scripts, relying on .unwrap() in production firmware is discouraged. Define errors explicitly and handle them deliberately.


#### Functions and methods for user defined types

User define types include enums, structs, and  union
```
impl Student {​

    fn new_with_username_email(username: String, email: String) -> Self {​
        Student {​
            active_enrollment: true,​
            username,​
            email​
        }​
    }​
    //method – with methods you add special parameter…  ​
    //a variable binding to “self”.  This binding can be mutable or //immutable​\
    fn get_username(&self) -> String { self.username }​
    fn get_student(email: &str) -> Student { //query db, return student }​
}
```

`impl` blocks let you associate methods with a type. Methods that take &self or &mut self operate on an instance, while functions without self are typically constructors or associated functions.

#### Common construction / initialization patterns

- "new" function
- Default trait

```
impl Default for Student {​
    fn default() -> Self {​
        Student {​
            active_enrollment: true, ​
            username: String::default(), ​
            email: String::new()​
        }​
    }​
}
```

### Summary

This introduction to key concepts of Rust just touches the surface of the Rust language itself, not to mention the extended ecosystem and community that surrounds it.

The goal of this introduction has been to introduce the _fundamental safety and ownership guarantees_ Rust builds into its core design to alleviate some of the shortcomings that other languages often suffer from.  These fundamentals are keystones to understanding the logic behind the rest of the language.

__Don't stop here__: 
- visit [Learn Rust - Rust Programming Language](rust-lang.org) and learn the language!
- check out [crates.io](https://crates.io/) for a taste of the many thousand 3rd-party packages (crates) that you can import for your project
- Use the [playground](https://play.rust-lang.org) to experiment as you learn.
- for fun extended learning, visit [Rustlings](https://github.com/rust-lang/rustlings), where you get hands-on exercises to break in your muscle memory for writing solid Rust code.
- Since you are here, you undoubtedly have an interest in using Rust to write firmware, so you should visit [Rust Embedded Book](https://docs.rust-embedded.org/book/) for a relevant introduction to using Rust in an Embedded Development Environment.




 




