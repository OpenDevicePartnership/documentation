# MCU Debugging
Debugging on the MCU side is done primarily with J-Link SWD connection. Some platforms will provide a dedicated serial port to the MCU that allows debug print messages.

## J-Link Debugging

With JTAG debugger you can set breakpoints and step through MCU side code as well as print messages out through the JTAG port using probe-rs.

```
    info!("Reserved eSPI memory map buffer size: {}", memory_map_buffer.len());
    info!("eSPI MemoryMap size: {}", size_of::<ec_type::structure::ECMemory>());
```

@Jerry and Felipe to provide further details or link to MCU debugging document
