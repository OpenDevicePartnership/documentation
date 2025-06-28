# Creating a component

By this point, we have set up our development workspace between the patina-dxe-core-qemu and the patina-qemu repositories and have them wired together so that the image loaded and run in the QEMU emulator is that which was built from the patina-dxe-core-qemu sources.

## Starting our test component project
In our test component project root, create a new folder for our project space. Call it `test_component`.

In this project, we will be mimicking the parts of the code layout that is used in `patina-dxe-core-qemu`, and adding our own files or replacing those that are represented there with updated versions.  

In your test_component project, create this file structure.  No need for content in any of the files just yet:

```
-\
  - bin\
    - q35_dxe_core.rs
  - src\
    - component\
        - test_component.rs
  - q35.rs  
```  
in `src/q35.rs`, set the content to simply
```rust
pub mod test_component
```


> 👀
>
> Note that We will not be using the service-related files from the patina-dxe-core-qemu repository in this example. These components implement platform services related to hardware configuration—such as ACPI port address emulation and HOB (Hand-Off Block) population—that are important for more advanced firmware scenarios.
>
> For our purposes, which focus on demonstrating a basic custom component using Patina’s DXE Core, these services are unnecessary. This allows us to simplify the component setup and focus on the essentials of the registration and dispatch model.
>
> These service components are useful when simulating realistic platform behavior—like memory-mapped I/O, reset control, or dynamic configuration discovery—and would be valuable when bringing up firmware against specific hardware targets. They can be reintroduced later if needed.


### Defining the component code

for the `src/component/test_component.rs` file, add this content to define our new test component

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

### Registering the component

The file `bin/q35_dxe_core.rs` is the main binding and execution point for the manifest of components that will make up the image.

Find this file in the `patina-dxe-core-qemu` repository directory and copy it to your project space at `bin/q35_dxe_core.rs` so we start from the full contents.

If we look at the patina-dxe-core-qemu version of this file we will see a `Core:default()` function is called with a number of `with_config()` and `with_component()` calls, along with a few others, chained together. This sets up the components that will be included.

The chain concludes with `.start().unwrap()`.  

Remove these lines from your copy and between 
```rust
with_section_extractor(patina_section_extractor::CompositeSectionExtractor::default())
        .init_memory(physical_hob_list) // We can make allocations now!
``` 
and
```rust
        .start()
```        

We will want logging, so replace the line
```rust
        .with_component(adv_logger_component)
``` 

We can add our component just prior after this, by inserting the lines
```rust
.with_component(test_component::run_test_component)
.with_config(test_component::Name("World"))
```
just before the `.start()` call.

It should end up looking similar to this:

```rust
    Core::default()
        .with_section_extractor(patina_section_extractor::CompositeSectionExtractor::default())
        .init_memory(physical_hob_list) // We can make allocations now!
        .with_component(adv_logger_component)
        .with_component(test_component::run_test_component)
        .with_config(test_component::Name("World"))
        .start()
        .unwrap();

    log::info!("Dead Loop Time");
    loop {}

```

also, toward the top of that file, remove the line that looks like this, since we are not using the services in this component:

```rust
use qemu_resources::q35::component::service as q35_services;
```



### importing the component
Of course, before this code can register our component, it must know about it.

We've already named it in `q35.rs` with `pub mod test_component`;

We can then add our import to the list of `use` statements near the top of the `bin/q35_dxe_core.rs` file with the line
```rust
use qemu_resources::q35::component::test_component;
```
You should see a similar line:
```rust
use qemu_resources::q35::component::service as q35_services;
```
add our test_component import near here.


## Building 
We can now build with the command 
```cmd
Z:
cd patina-dxe-core-qemu
cargo make q35 Z:\\test_component
```
and once that's done, we can build it into QEMU and run it with

```cmd
Z:
cd patina-qemu
q35env\Scripts\activate.bat
stuart_build -c Platforms\QemuQ35Pkg\PlatformBuild.py --flashrom BLD_*_DXE_CORE_BINARY_PATH="Z:\patina-dxe-core-qemu\target\x86_64-unknown-uefi"
```
Like before, this will take several minutes to build before it starts QEMU and begins logging the output of the execution.  

A large amount of log output is generated by subsystems that trigger before and after our component is run, so it will be tricky to find the output in the scroll-back window of your terminal. 

You should be able to locate your "Hello, World!" output within a section that starts with "Dispatching Local Drivers".  But be aware that the default patina-qemu image has similar "Hello, World" type examples within it, so be sure to look for mention of `test_component` in the log as well to verify it is running your code.  You can also modify the text of your test message to verify this.  If you only see the "other" samples, then something has gone wrong.  Verify that the `BLD_*_DXE_CORE_BINARY_PATH` environment variable correctly points to the `.efi` file built by your test component project. If needed, rebuild your component and re-run the `stuart_build` command.
