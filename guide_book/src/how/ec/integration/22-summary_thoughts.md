# Summary Thoughts

Congratulations on your success in building and integrating, understanding, and testing virtual components using the ODP framework!

There are, of course, a number of things that one would do differently if they were working with actual hardware and building for an actual system. 

For starters, much of the behavioral code we created in these exercises needed to substitute simulated time and physical responses that would "just happen" with real hardware in real time, and real-world physics may differ from our simplified models here.

We use `println!` pretty liberally in our examples -- this is fine since we are building for a std environment with these apps currently, but when migrating to a target build, these will need to replaced by `log::debug!` or `info!` and limited in context.

With the simplistic integration we have here, the battery is always the source of power -- it will charge, but if the load exceeds the charger ability, the battery will eventually fail even when the device is presumably plugged in. This is an artifact of our simplified model. A real Embedded Controller integrations power-path control so that mains input can bypass the battery when not available. Readers are encouraged to look into the usb-pd support found in the [ODP usb-pd repository](https://github.com/OpenDevicePartnership/embedded-usb-pd) for resources that can be used in extending the integration to support a "plugged-in" mode.

## Where do we go from here?

There are some key steps ahead before one can truly claim to have an EC integration ready:
- __Hardware__ - We have not yet targeted for actual embedded hardware -- whether simulated behavior is used or not -- that is coming up in the next set of exercises. This could target an actual hardware board or perhaps a QEMU virtual system as an intermediary step.
- __Standard Bus Interface__ - To connect the EC into a system, we would need to adopt a standard bus interface -- most likely __ACPI__ 
- __Security__ - We have conceptually touched upon security, but have not made any implementation efforts to support such mechanisms.  A real-world system _must_ address these.  In environments that support it, a Hafnium-based hypervisor implementation for switching EC services into context is recommended.

## The ODP EC Test App
Once a complete EC is constructed, there is a very nice test app produced by the ODP that can be used to validate that the ACPI plumbing is correct and the EC responds to calls with the expected arguments in and return values back.

[ODP ec-test-app](https://github.com/OpenDevicePartnership/ec-test-app)

At this point, you have the building blocks in hand to extend your virtual EC toward this validation path by adding ACPI plumbing on top of the Rust components we've built and exposing them in a QEMU or hardware container.

The ec-test-app repo even includes sample ACPI tables (thermal + notification examples) to show how the methods are expected to be defined. That could be a starting point for the essential bridge between the Rust-based EC simulation examples we've worked with, and the Windows validation world for a true device.




