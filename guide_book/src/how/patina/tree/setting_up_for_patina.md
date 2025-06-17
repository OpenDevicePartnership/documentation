# Setting up for Patina

Patina is based upon the foundations of UEFI, and as such, much of the tooling used to build boot firmware
continues to leverage the existing proven tools from Tianocore, such as the `stuart_build` set of commands, and many other parts familiar within the EDK II framework.

The steps to setting up the tooling can be found documented in the Readme of the [patina-qemu](https://github.com/OpenDevicePartnership/patina-qemu) repository, but what is not immediately clear from that discussion is the role that different repositories play.  This is a bit of a marathon, so we'll walk through it here.

### The repositories involved
The full umbrella of ODP material encompassses multiple repositories, because ODP covers several diverse aspects of firmware development that speak to different audiences.  Simililarly, the Patina subsection of ODP itself is maintained in multiple repositories, which ones are utilized by a developer will depend upon the goals and scope of a particular project.

The most common Patina-related repositories are as follows

- __patina__ - This maintains a library of crates that implement UEFI-like code in Rust. This defines all of the reusable
'Patina SDK' components that may be pulled into other workflows (such as _patina-dxe-core-qemu_) to create customized `.efi` images.

- __patina-dxe-core-qemu__ - This repository holds the code responsible for pulling in reusable Rust DXE Core components from the Patina SDK, combining these with locally defined custom components, and building the resulting `.efi` image that may be loaded into the QEMU emulator.

- __patina-qemu__ - This repository supplies a platform wrapper that loads the `.efi` firmware into QEMU using EDK build tools (`stuart_build`) from the `.efi` file indicated at build time.

- __patina-fw-patcher__ - This repository simplifies the iterative turnaround for incremental builds in a workflow, once one has been established, able to forego the full `stuart_build` process for each code update.

- __patina-mtrr__ - This repository supports a MTRR(Memory Type Range Registers) API that helps program MTRRs on x86_64 architecture.
- __patina-paging__ - Common paging support for various architectures such as ARM64 and X64

In this discussion we will be focused on the steps required to build Patina into a QEMU emulator.  We will be primarily concerned
with the __patina-dxe-core-qemu__ and __patina-quemu__ repositories for this.

## Preparing the workspace environment

To explore how to create a component for Patina, we will build and test a simple "hello, world" type test component.
In this example, we will not be building for a host target board, but will be targeting the QEMU emulator instead.

Create a project space for your test component, and in this space, clone the necessary ODP repositories:

```
git clone https://github.com/OpenDevicePartnership/patina-qemu
git clone https://github.com/OpenDevicePartnership/patina-dxe-core-qemu
```
 You will be working with these repositories and their examples as you create your own component.

## Qemu Q35 package
In these steps, we will be building an emulated platform based on the Intel Q35 chipset. This will demonstrate the Patina UEFI firmware development for x86_64.  The patina-qemu repository also has support for an ARM architecture. Refer there for more information on that approach.  We will focus for now on the x86_64 option.



### 👉 Follow the instructions👈
Your next step is to look at the `README` of `patina-qemu`. ___It contains detailed information on how to properly set up a workspace for the QemuQ35Pkg project___ we will be working with.

Follow the prompts in the `workspace_setup.py` script wizard, and accept the recommended options which will result in establishing a python virtual environment and then prompting you to run the script again to build an image for QEMU.

Once you have followed these setup instructions and all has gone well, carefully follow all the steps in the `Build and Run` section for the __X64 Target__.


>Acquaint yourself with these steps. Note that as we work through our example component project, the normal 
development routine will be to switch to the patina-qemu directory, then execute `q35env\Scripts\activate.bat` to put us  into our Python Virtual Environment (if we aren't already in one).  Then, we will be regularly executing the `stuart_build`  command as shown in the "Stuart Build and Launch UEfi Shell" section as we move through the example steps.

#### Pointing to the qemu-dxe-core
Note that the path passed for `BLD_*_DXE_CORE_BINARY_PATH` is shown in that example as something like:  "C:\r\patina-dxe-core-qemu\target\x86_64-unknown-uefi".  
Unless you happened to create your patina test component project root folder at `C:\r` (or wish to move it there) this path will have to be changed.
Change the "C:\r" portion of that example path to be the 
absolute path to your workspace directory (where you have cloned the repositories).  

##### Oops -- too long a path
When you build, if you subsequently get an error from NMAKE that the path is too long, you can:

##### Use the Windows Group Policy Editor to enable long path support.
Find and run the Group Policy Editor application (`gpedit.exe`) from the Windows Command Prompt.
Navigate to `Computer Configuration` -> `Administrative Templates` -> `System` -> `Filesystem` -> `Enable Win32 long paths`.  Open this policy setting and select `enable`.

##### Other solutions to the long path problem include:
- relocating your project directory to a shorter path (e.g. `C:\r`)
- using `subst` to map this directory to a drive letter (e.g. `Z:\`)

##### Using `subst` for our example
For these examples, we will adopt the last option and use `subst` to remain consistent with the instructions to follow.

```
subst Z: <your absolute path to your patina project directory>
``` 
So that Z:\ is now your pantina component project root that contains the two cloned repositories:

```
Z:\>dir
 Volume in drive Z is Local Disk
 Volume Serial Number is 0A87-D98F

 Directory of Z:\

06/16/2025  09:59 AM    <DIR>          .
06/16/2025  09:58 AM    <DIR>          ..
06/16/2025  10:37 AM    <DIR>          patina-dxe-core-qemu
06/16/2025  11:04 AM    <DIR>          patina-qemu
               0 File(s)              0 bytes
  
```


Now, you should be able to follow the steps from "Build and Run", and it should look something like this:

```
Z:\>cd patina-qemu

Z:\patina-qemu>q35env\Scripts\activate.bat

(q35env) Z:\patina-qemu>stuart_build -c Platforms\QemuQ35Pkg\PlatformBuild.py --flashrom BLD_*_DXE_CORE_BINARY_PATH="Z:\patina-dxe-core-qemu\target\x86_64-unknown-uefi"
```


Building will take several minutes.  At the end of this you should see a QEMU window that shows a brief splash graphic and then a shell prompt and output showing success.

You will also see a long train of runtime debug output to the console window.  This will exceed the scroll-back buffer of the window so you won't be able to see the first portion of it.  The tail end of this runtime log will likely contain a number of TRACE level warnings at this stage.  We can ignore this output at this time.

To build without running on QEMU, leave off the `--flashrom` flag and the path assignment.

### What did we just build?
The Patina DXE Core was successfully installed into your QEMU emulator!  But the actual Rust code for that is contained within a prebuilt .efi binary.  Next we will look at the steps you will need to take to update that .efi binary so that _your_ firmware development can be set into place.

Now that the QEMU tooling is ready, let's look at getting a customized Patina core with your own component code onto it with the next steps.

