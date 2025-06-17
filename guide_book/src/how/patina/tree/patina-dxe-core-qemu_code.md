# Patina-dxe-core-qemu Code
The ["patina-dxe-core-qemu" repository](https://github.com/OpenDevicePartnership/patina-dxe-core-qemu) contains the tooling and build steps needed to combine elements of the patina SDK (maintained in the 'patina' repository) with locally provided component code.

Let's review the component parts of UEFI again at this point:

![UEFI Diagram](./media/PI_Boot_Phases.jpg)

All of these sections can be found covered in the Patina implementation. 
The DXE Core (colloquially pronounced "Dixie") is the Driver Execution Environment and where most of the key development for components is centered.  
There is also of course the Runtime Services (RT) that continue beyond boot of the OS.
And there are all the parts in between, including security management, transient system load (TSL) handling, logging, boot device selection, and so forth.
There are some key differences between a conventional UEFI implmentation and Patina.
One such difference is there is no traditional EFI Dispatcher.  Instead, the DXE Core is built monolithically using dependency injection for the drivers that are bound to a prescribed function.

Read more about the monolithic construction model of Patina and other differences from UEFI in the [Patina Documentation](https://sturdy-adventure-nv32gqw.pages.github.io/component/interface.html)

## How does this come together?
Within the patina-dxe-core-qemu repository there is a primary file at `bin\q35_dxe_core.rs` that controls the monolithic construction of the core and its various components. 

Inpecting this file, we see a key function, `Core::default()` that is the launching point for a number of `.with_component()` and `.with_config()` calls chained together to construct the complement of our firmware image.

Patina uses a Dependency-Injection scheme to map components and their configurations into the dispatch mechanism, and this is where the registration comes together.

## Reviewing and finalizing the setup 
Before we start constructing our own component, let's take a moment to be sure we are set up properly and understand the steps of the process:

1. We will be creating our component within its own project inside our workspace.  
1. We will pass the path of this local component project to the `make q35` command of `patina-dxe-core-qemu` and it will combine this with the default stubs from its own sources to create our custom build with our component in it.
2. When the code is ready, we will switch to our Z:\patina-qemu location  and build and run the stuart_build process that will construct our emulator image and execute it in QEMU.


