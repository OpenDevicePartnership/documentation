# QEMU Setup

This section covers how to setup QEMU and boot windows image. We use QEMU as a reference for developing features that are not yet fully supported in hardware. This also gives us a HW agnostic platform that any SV or OEM can use for development.

## Downloading and building QEMU

The first step to setting up your system and validating you can boot to UEFI shell. The following has been validated with Ubuntu 22 under WSL. For full instructions see the following link:

[Building QEMU with Stuart](https://github.com/tianocore/tianocore.github.io/wiki/How-to-Build-With-Stuart)

This also depends on rustup being installed

[Install Rustup](https://rustup.rs)

### QEMU build and setup
Note this uses Version 9.0.0 tip QEMU and other versions have varying issues. Building the emulator takes some time depending on your computer.

```
sudo apt-get install git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build qemu-utils libudev-dev libncurses-dev
wget https://download.qemu.org/qemu-9.0.0.tar.xz
tar xf qemu-9.0.0.tar.xz
cd qemu-9.0.0
./configure --enable-vnc
make
sudo make install
```

## Running QEMU with Windows

You can download the Validation OS ISO which is stripped down version of the OS and boots much faster in QEMU
[Validation OS Windows 11](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/validation-os-overview?view=windows-11_)

When you mount the ISO you will have ValidationOS.vhdx and ValidationOs.wim files. Generally we work with virtual disk files (vhdx) in qemu. Copy the ValidationOS.vhdx file to your WSL file share, prepare it by injecting critical CAB file contents (below), and convert this to qcow2 image that is used by qemu.

`qemu-img convert -p -O qcow2 ValidationOS.vhdx winvos.qcow2`

You will need to modify Platforms/QemuSbsaPkg/Plugins/QemuRunner/QemuRunner.py to load your windows disk image. 

```
       windows_image = env.GetValue("QEMU_WINDOWS_IMAGE")
       if(windows_image != None):
         logging.log(logging.INFO, "Mapping windows image to boot: " + windows_image)
         args += " -hda " + windows_image
```

Now you can just port the environment variable to point to your windows image and it will load and boot windows rather than stopping at shell

`export QEMU_WINDOWS_IMAGE=/home/user/qemu/winvos.qcow2`

You should now be able to boot to windows and connect to the VNC session using your favorite VNC viewer at 127.0.0.1:5900

## Preparing the Windows Validation OS (WinVOS) Image

WinVOS is a pared down Windows OS image that is convenient for basic development while also booting relativley quickly under QEMU.  You'll need access to the [Validation OS Windows 11](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/validation-os-overview?view=windows-11&viewFallbackFrom=windows-11_) VHDX and minimally the following [CAB files](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/validation-os-optional-packages?view=windows-11_) (for keyboard input, connectivity, etc.):

- Microsoft-WinVOS-Connectivity-Package.cab
- Microsoft-WinVOS-Driver-Support-Package.cab
- Microsoft-WinVOS-PnP-Package.cab

To mount and install the CAB files into the VHDX:

1. Mount the VHDX image by double clicking on it and noting the drive letter.  Alternatively, from PowerShell:

    `Mount-VHD -Path "C:\Path\To\Your.vhdx"`

2. Inject each CAB file using DISM (replace the drive and paths with actual):

    `dism /Image:D:\ /Add-Package /PackagePath:"C:\temp\Microsoft-WinVOS-Connectivity-Package.cab"`

    `dism /Image:D:\ /Add-Package /PackagePath:"C:\temp\Microsoft-WinVOS-Driver-Support-Package.cab"`

    `dism /Image:D:\ /Add-Package /PackagePath:"C:\temp\Microsoft-WinVOS-PnP-Package.cab"`

3. Unmount your VDHX file to make sure it is saved by right-clicking on the drive in File Explorer and selecting Eject.  Alternatively, from PowerShell:

    `Dismount-VHD -Path "C:\Path\To\Your.vhdx`

At this point, the VHDX can be converted to a qcow2 image and booted in QEMU following the **Running QEMU with Windows** instructions above.
