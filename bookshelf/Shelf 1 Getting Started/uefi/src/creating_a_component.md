# Creating a component

By this point, we have set up our development workspace between the patina-dxe-core-qemu and the patina-qemu repositories and have them wired together so that the image loaded and run in the QEMU emulator is that which was built from the patina-dxe-core-qemu sources.

Now let's create our own component that we can add to this set.

In the `src` directory we find a `component` directory and some other small `.rs` files. The `component` directory is where we will be adding our new component.

### Defining the component code

Inside the `component` directory, create a new file named `test_component.rs` that contains this content:

```
use log::info;
use patina_sdk::{component::params::Config, error::Result};

#[derive(Default, Clone, Copy)]
pub struct Name(pub &'static str);

pub fn run_test_component(name: Config<Name>) -> Result<()> {
    info!("============= Test Component ===============");
    info!("Hello, {}!", name.0);
    info!("=========================================");
    Ok(())
}
```
As you can see, this presents a classic 'hello world' style example, which is all we will need to get started.

It starts by importing (the `use` statements at the top) the logging support we will use for our message, the Config construct from the patina_sdk that we will use for our parameter, and the classic Rust `Result` construct.

The function signature for this implementation forms the basis for the dependency injection we will register in the next step.

To understand the `Config` parameter structure and the dependency injection and Monolithically Compiled Components a little better, consult the [Component Interface](https://sturdy-adventure-nv32gqw.pages.github.io/driver/interface.html) discussion of the Patina Repository Documentation.

### Registering the component

The file `bin/q35_dxe_core.rs` is the main binding and execution point for the manifest of components that will make up the image.

If we look at this file we will see a `Core:default()` function is called with a number of `with_config()` and `with_component()` calls, along with a few others, chained together. This sets up the components that will be included.
The chain concludes with `.start().unwrap()`.  We can add our component just prior to this, by inserting the lines
```
.with_component(test_component::run_test_component)
.with_config(test_component::Name("World"))
```
just before the `.start()` call.

### importing the component
Of course, before this code can register our component, it must know about it.

We name it as one of the exported components by editing `src/q35/component.rs` and adding the line `pub mod test_component;` to this file.

We can then add our import to the list of 'use` statements near the top of the `bin/q35_dxe_core.rs` file with the line
```
use qemu_resources:q35::component::test_component;
```


### removing other samples
_(optional)_
You may have noticed in the debug.log dispatches to other "hello, world" sample components.  These come from the patina_samples section of the 'patina' repository.  Recall, the 'patina' repository is like a library of prebuilt-crates.  This sample code there is one of these crates, but we don't need to use it.  Let's either comment out or remove the `use patina_samples as sc` line from the list of `use` statements and these lines from the Core::default() chain:

```
.with_config(sc::Name("World")) // Config knob for sc::log_hello
```
```
        .with_component(sc::log_hello) // Example of a function component
        .with_component(sc::HelloStruct("World")) // Example of a struct component
        .with_component(sc::GreetingsEnum::Hello("World")) // Example of a struct component (enum)
        .with_component(sc::GreetingsEnum::Goodbye("World")) // Example of a struct component (enum)
```
As this will remove some of the clutter from our example build. We will leave the other components there, and verify that we've added our `test_component` references.


## Building 
We can now build with the command `cargo make q35`

. 

Once we have built without errors, switch to Z:\ and run
`stuart_build -c Platforms\QemuQ35Pkg\PlatformBuild.py --FlashRom`

and check the debug.log after it runs.

Search for 'test component' and you should find this:
```
INFO - DISPATCH_ATTEMPT BEGIN: Id = ["qemu_resources::q35::component::test_component::run_test_component"]
INFO - ============= Test Component ===============
INFO - Hello, World!
INFO - =========================================
INFO - DISPATCH_ATTEMPT END: Id = ["qemu_resources::q35::component::test_component::run_test_component"] Status = [Success]
```

Congratulations! you have built and run your first Patina Rust component and executed it as emulated firmware!


