# Setting up for Patina

Patina is based upon the foundations of UEFI, and as such, much of the tooling used to build boot firmware
continues to leverage the existing proven tools from Tianocore, such as the `stuart_build` set of commands, and many other parts familiar within the EDK II framework.

The primary tooling repository -- containing the Rust ODP Patina component -- is [Patina](https://github.com/OpenDevicePartnership/patina).  Conceptual and Best Practices documentation for Patina can be found as part of the [Patina Repository Documentation}(https://sturdy-adventure-nv32gqw.pages.github.io/driver/interface.html).  This content can also be generated locally as an `mdbook` from the Patina repository source.

However, when targeting a build, the artifacts of the Patina repository are generally used by inclusion and reference.  For example, 
to build as we will be doing in these instructions for the QEMU emulator, there is the [patina-qemu](https://github.com/OpenDevicePartnership/patina-qemu) repository.

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

Much of the steps shown here are restructured from the [patina-qemu README](https://github.com/OpenDevicePartnership/patina-qemu?tab=readme-ov-file#first-time-tool-setup-instructions-for-this-repository), but contains a few additional clarifications.

The end result will be a set of Patina rust-based firmware running as a QEMU hosted emulated platform.  Once this is established, we can work with the firmware ourselves and/or we can target an actual platform board instead of the emulator.  But let's not get ahead of ourselves just yet.  First we need to get things into place.

## Qemu Q35 package
In these steps, we will be building an emulated platform based on the Intel Q35 chipset. This will demonstrate the Patina UEFI firmware development for x86/64.  The patina-qemu repository also has support for an ARM architecture. Refer there for more information.

## Preparing for "Stuart"
The EDK II build tool, `Stuart`, is duplicated in the patina-qemu repository and further leveraged by specific platform build scripts.

### Python
But before we go there, we need to make sure we have Python installed.
For Windows, download the [official Python installer]( https://www.python.org/downloads/windows/)

(For Linux or MacOS, consult available sources for installing Python for your platform).

The installer should install both `python` and `py` (python launcher).  Test your installation with

```
py -0
```
This should list the available python versions, and

```
python --version
```
should verify your default python version is available.

### patina-qemu
Now to get on with building the "Stuart" tools:

Start by cloning the patina-quemu repository to your workspace.  

```
git clone git@github.com:OpenDevicePartnership/patina-qemu.git
```


and then we are going to establish a virtual python environment in this space and use it to build the tools.

(Windows)
```
cd edk2
py -m venv .venv
.venv\Scripts\activate.bat
pip install -r pip-requirements.txt --upgrade
stuart_setup -c .pytool/CISettings.py
```

## Patina-qemu
Now we are equipped to build from the patina-qemu repository.

### Shorten the path
On Windows, the build commands reference pathnames that when combined can exceed the maximum allowed path length, so to prevent issues here, we will redirect where we work so that our paths are shorter.

This may not be necessary on later releases of Windows 11 or above, or if you have specifically enabled long path support for a previous version. However, following these steps may simplify the process regardless.

Do this from within the patina-quemu repository root directory:

```
cd
<this will show you the full path of the repository root, where you are>
subst z: <full path shown above>

cd z:\
z:
```

now you should be able to treat your Z:\ location the same as your repository root, but the resulting path names will be shorter.


### Preparing and Building
(from within your new Z:\ location)

```
# Create a Python virtual environment for this workspace
py -e -m venv patina.venv 
# and then activate it
.\patina.venv\Scripts\activate.bat
```
Note that there is `activate.bat` (for cmd) and `Activate.ps1` (for PowerShell).  Use the one that matches your console shell.

Now install the python dependencies:
```
pip install --upgrade -r pip-requirements.txt
```
Then use the Stuart tools to setup and build:
```
stuart_setup -c Platforms\QemuQ35Pkg\PlatformBuild.py
stuart_upgrade -c Platforms\QemuQ35Pkg\PlatformBuild.py

```
### First and subsequent setup 
The steps above will create a virtual python environment and install the stuart tools into it.
You should only need to do these steps the one time for your workspace.
On subsequent visits, simply activate the virtual environment again (`.\patina.venv\Scripts\activate.bat`) 
and then proceed with the build and/or run steps.

To build and install into QEMU, include the --FlashRom argument:
```
stuart_build -c Platforms\QemuQ35Pkg\PlatformBuild.py --FlashRom
```

building will take several minutes.  At the end of this you should see a QEMU window that shows a brief splash graphic and then a shell prompt and output showing success.

You will also see a long train of runtime debug output to the console window.  This will exceed the scroll-back buffer of the window so you won't be able to see the first portion of it.  The tail end of this runtime log will likely contain a number of TRACE level warnings at this stage.  We can ignore this output at this time.

To build without running on QEMU, leave off the `--FlashRom` flag.

To launch again into QEMU _without_ building, you can use `--FlashOnly` instead.  

### What did we just build?
The Patina DXE Core was successfully installed into your QEMU emulator!  But the actual Rust code for that is contained within a prebuilt .efi binary.  Next we will look at the steps you will need to take to update that .efi binary so that _your_ firmware development can be set into place.

Now that the QEMU tooling is ready, let's look at getting a customized Patina core and your own component code onto it with the next steps.


