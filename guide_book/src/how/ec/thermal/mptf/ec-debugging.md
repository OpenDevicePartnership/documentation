# EC Service Debugging
Since the EC service runs in the secure world you cannot debug it through windbg. Most debugging is done through serial log messages or JTAG with SWD.

For SWD debugging see references to Hafnium and JTAG debugging.

# Serial Debug
In the code you can simply use println or logging interface and these messages will be routed to serial port by default.

Eg.

```
        println!(
            "set_variable instance id: 0x{:x}
                length: 0x{:x}
                uuid: {}
                data: 0x{:x}",
            req.id, req.len, req.var_uuid, req.data
        );
```

You will see these messages printed out on the serial terminal
```
15:29:00.621 : SP 8003: DEBUG - set_variable instance id: 0x1
15:29:00.622 : SP 8003:                 length: 0x4
15:29:00.623 : SP 8003:                 uuid: 5cf839df-8be7-42b9-9ac5-3403ca2c8a6a
15:29:00.623 : SP 8003:                 data: 0x19
```
