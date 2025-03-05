# Compiling UEFI for QEMU

## Downloading and Building Image

The following steps will install required packages, setup and build UEFI image for QemuSbsaPkg which is ARM64 image.

```
git clone https://github.com/microsoft/mu_tiano_platforms.git
cd mu_tiano_platforms
git submodule update --init --recursive
sudo apt-get install python3
sudo apt-get install python3.10-venv
python3 -vm venv .venv
source .venv/bin/activate
sudo apt-get install python-is-python3
sudo apt-get install python3-pip
pip install -r pip-requirements.txt --upgrade
sudo apt-get install -y build-essential git nasm wget m4 bison flex uuid-dev unzip acpica-tools gcc-multilib
sudo apt-get install gcc-aarch64-linux-gnu
sudo apt-get install mono-complete
sudo apt-get install mtools
rustup override set nightly
cargo install cargo-make
export GCC5_AARCH64_PREFIX=/usr/bin/aarch64-linux-gnu-
stuart_setup -c Platforms/QemuSbsaPkg/PlatformBuild.py TOOL_CHAIN_TAG=GCC5
stuart_update -c Platforms/QemuSbsaPkg/PlatformBuild.py TOOL_CHAIN_TAG=GCC5
stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py TOOL_CHAIN_TAG=GCC5
```

## Running QEMU
After image has been built you can run the generated image using the following command. This assumes you already have qemu-system-aarch64 compiled and installed on your system.
```
stuart_build -c Platforms/QemuSbsaPkg/PlatformBuild.py TOOL_CHAIN_TAG=GCC5 --FlashOnly
```

This will run to UEFI Shell> and your QEMU is working and running
