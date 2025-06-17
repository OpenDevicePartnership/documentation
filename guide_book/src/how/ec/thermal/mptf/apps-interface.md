# Apps to MCU Interface

When using eSPI transport we define a mapped memory region in the peripheral bus, that must be agreed on between apps side and MCU side.


[eSPI Specification](https://www.intel.com/content/www/us/en/content-details/841685/enhanced-serial-peripheral-interface-espi-interface-base-specification-for-client-and-server-platforms.html)

## Memory Layout Definition

Both apps side and MCU side are using RUST, we define the memory layout in YAML format and currently have a python script that converts this to a RUST format.

`embedded-services/embedded-service/src/ec_type/generator/ec_memory.yaml`

```
# EC Memory layout definition

Version:
  major:
    type: u8
  minor:
    type: u8
  spin:
    type: u8
  res0:
    type: u8
...
# Size 0x38
Thermal:
  events:
    type: u32
  cool_mode:
    type: u32
  dba_limit:
    type: u32
  sonne_limit:
    type: u32
  ma_limit:
    type: u32
  fan1_on_temp:
    type: u32
  fan1_ramp_temp:
    type: u32
  fan1_max_temp:
    type: u32
  fan1_crt_temp:
    type: u32
  fan1_hot_temp:
    type: u32
  fan1_max_rpm:
    type: u32
  fan1_cur_rpm:
    type: u32
  tmp1_val:
    type: u32
  tmp1_timeout:
    type: u32
  tmp1_low:
    type: u32
  tmp1_high:
    type: u32

```

## Converting YAML to RUST

To convert YAML to RUST simply run the ec-memory-generator.py using the following command

`python ec-memory-generator.py ec_memory.yaml`

This will outut the following two files for C based structure definition and RUST based

```
structure.rs
ecmemory.h
```

When compiling embedded-services the structure.rs must be copied under

`embedded-services/embedded-service/src/ec_type`

## Versioning

Any time a breaking change is made the major version must be updated and if EC and apps don't agree on a major version the fields cannot be interpreted. Whenever possible we only want to add fields which means we can keep the structure backwards compatible and just the minor version can be updated.

## MCU eSPI Service

When the apps modifies or writes some value into the peripheral channel on the MCU side a service can register for notifications to specific regions of the memory map. The handling of all eSPI events can be found in

`embedded-services/espi-service/src/espi_service.rs`

This contains the entry point and main message handling loop.

```
#[embassy_executor::task]
pub async fn espi_service(mut espi: espi::Espi<'static>, memory_map_buffer: &'static mut [u8]) {
    info!("Reserved eSPI memory map buffer size: {}", memory_map_buffer.len());
    info!("eSPI MemoryMap size: {}", size_of::<ec_type::structure::ECMemory>());
    ...
    loop {
        ...
    }
```

VWire events and Peripheral channel events come in on Port 0, while OOB messages come in on Port 1. For details about the eSPI protocol see the eSPI secification

Based on the offset of the access in the peripheral channel the data is routed to the correct service

```
    if offset >= offset_of!(ec_type::structure::ECMemory, therm)
                && offset < offset_of!(ec_type::structure::ECMemory, therm) + size_of::<ec_type::structure::Thermal>()
    {
        self.route_to_thermal_service(&mut offset, &mut length).await?;
    }
```

This gets converted to a transport independent message and routed to the thermal endpoint that can register and listen for these messages

```
    async fn route_to_thermal_service(&self, offset: &mut usize, length: &mut usize) -> Result<(), ec_type::Error> {
        let msg = {
            let memory_map = self.ec_memory.borrow();
            ec_type::mem_map_to_thermal_msg(&memory_map, offset, length)?
        };

        comms::send(
            EndpointID::External(External::Host),
            EndpointID::Internal(Internal::Thermal),
            &msg,
        )
        .await
        .unwrap();

        Ok(())
    }
    ```
