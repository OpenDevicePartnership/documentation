# MCU Firmware

The MCU Firmware has a region of 256 bytes that is mapped as the peripheral channel on eSPI. This is used to read and write 32-bit values to and from the EC. Based on the parameters that we read and write the MCU firmware will adjust fan speeds and other parameters within the EC that adjust thermal.

![MCU Variables](media/fan.png)
