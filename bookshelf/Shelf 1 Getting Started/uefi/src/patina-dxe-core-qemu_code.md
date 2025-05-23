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

Read more about the construction and differences of the Patina code base in the [Patina Documentation](https://sturdy-adventure-nv32gqw.pages.github.io/)

## How does this come together?
Within the patina-dxe-core-qemu repository there is a primary file at `bin\q35_dxe_core.rs` that controls the monolithic construction of the core and its various components. Inpecting this file, we see a key function, `Core::defualt()` that is the launching point for a number of `.with_component()` and `.with_config()` calls chained together to construct the complement of our firmware image.

Patina uses a Dependency-Injection scheme to map components and their configurations into the dispatch mechanism, and this is where the registration comes together.

## Reviewing and finalizing the setup 
Before we start constructing our own component, let's take a moment to be sure we are set up properly and understand the steps of the process:

1. We will be making our coding additions within our local patina-dxe-core-qemu repository space, and build it there.
2. When the code is ready, we will switch to our Z:\ location (which is our alias for the patina-qemu repository root) and build and run the stuart_build process that will construct our emulator image and execute it in QEMU.

### Finalizing setup
For the binding in step 2 to work, we need to tell the patina-qemu tools where the `.efi` target file is, so that it can load it into the emulator.  Let's find out where this is.  

from your local patina-dxe-core-qemu root, type `cargo make q35` this should produce a build with no errors.  Now look in the location `target\x86_64-unknown-uefi\debug\` and you should see a `qemu_q35_dxe_core.efi` file created there. 
Note the full path to this file, i.e. `<your-path-to-repository-root>\target\x86_64-unknown-uefi\debug\qemu_q35_dxe_core.efi`

Go to your patina-qemu local directory and edit the file `Platforms\QemuQ35Pkg\QemuQ35Pkg.fdf`.  Around about line 644 you will see a section that looks like this:

```
FILE DXE_CORE = 23C9322F-2AF2-476A-BC4C-26BC88266C71 {
!if $(TARGET) == RELEASE
  SECTION PE32 = $(DXE_CORE_BINARY_PATH)/release/qemu_q35_dxe_core.efi
!else
  SECTION PE32 = $(DXE_CORE_BINARY_PATH)/debug/qemu_q35_dxe_core.efi
!endif
  SECTION UI = "DxeCore"
}
```
This implies that the DXE_CORE_BINARY_PATH environment variable can be used to redirect where the `.efi` file comes from.  
As of this writing, however, the repository code does not behave this way.  Instead, we must change this to a literal path that points to our location.

Change this section to look like this:
```
FILE DXE_CORE = 23C9322F-2AF2-476A-BC4C-26BC88266C71 {
SECTION PE32 = <your-path-to-repository-root>\target\x86_64-unknown-uefi\debug\qemu_q35_dxe_core.efi
SECTION UI = "DxeCore"
}
```
So that it will point to the output where your `.efi` is being constructed.  Note that we are explicitly referring to the debug (default) build here.  Adjust this path as needed for release builds or other targets.


### Redirecting log output
You may recall that when we did our first test run using the default `.efi` location that the runtime debug log output was output to the console and was too lengthy to see the top portion of. We can redirect the output to go to a file instead, which will allow us to see everything as well as keeping it in a place we can review after each run.

Edit the file `Platforms\QemuQ35Pkg\Plugins\QemuRunner.py` and look for a line that says  `args = "-debugcon stdio"` (about line 66) and change this to read `args = "-debugcon file:debug.log"`.  This will redirect log output to a file "debug.log" in your Z:\ location when run.

Now, still at the Z:\ prompt (activated), type
```
stuart_build -c Platforms\QemuQ35Pkg/PlatformBuild.py --FlashRom
```
Again, this will take several minutes and cover a few phases with lots of console output.
Finally, the QEMU window will appear, display it's splash graphic, identifying text, and shell prompt.  

You will find your Z:\debug.log file now populated and containing the run output.

Verify this is from your local build by checking this log.
You should see the log line 
```
INFO - DXE Core Platform Binary v0.3.2
```
around about line 900 - 910 or so
_note version number may be different_

This log line is emitted from the `bin/q35_dxe_core.rs` file of the patina-dxe-core-qemu sources, which is the launch point for the components.

We will create and install our own component in the next exercise.






