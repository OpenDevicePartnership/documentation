# ACPI Customization

## Adding Test Content to ACPI

ACPI is compiled as part of the MU_TIANOCORE image. To update ACPI you simply need to modify the tables found here in the UEFI build.

`mu_tiano_platforms/Platforms/QemuSbsaPkg/AcpiTables`

Update the dsdt.asl in this folder to include your ACPI content in this case test.asl

```
...
    #include "test.asl"

    //
    // Legacy SOC bus
    //
    Device (SOCB) {
      Name (_HID, "ACPI0004")
      Name (_UID, 0x0)
      Name (_CCA, 0x0)
```

Recompile mu UEFI and it will pick up these ACPI changes in the QEMU_EFI.fd image when you boot QEMU.

<b>Note: </b> ACPI is provided as part of the firmware image so change ACPI does not require you to change your windows image.
