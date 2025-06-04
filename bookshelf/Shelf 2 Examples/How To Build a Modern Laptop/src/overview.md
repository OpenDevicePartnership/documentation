# Overview

The "How to Build a Modern Laptop" book will be organized as a series of steps, each which references previous example documention found on the Introduction and Example shelves. 

The general approach will be to explain the scope of what we are building: A Virtual laptop that runs in a QEMU virtual emulator with an embedded controller that is built onto an inexpensive, readily available commercial developer evaluation board using one of the board's supported communication protocols (e.g. SPI).  To do this, this book will first discuss setting up the development environment and pointing readers to ways to obtain a development board and associated cables.

The scope and audience of this book will be primarily aimed at those who are either already experienced in similar firmware development and are fluent in Rust. Although there will be frequent references to the prior material, a developer new to the domain or language may feel lost without at least that level of onboarding, so beginners should do all the introductory examples first.
Even experienced developers will likely want to review the introductory content before continuing, just to make sure they are on the same page to start.

This discussion will refer to articles found on Shelf 1 and 2 for a more tutorial-based approach to learning how to use these tools.

When the reader feels they have the tools they need in place and have a good working familiarity with the use of the aforementioned development tools, and a solid command of Rust programming, the book proceeds with the steps for the actual build.

![Plan Diagram](...) A diagram of the contents and steps should be inserted at this point to illustrate the overview in graphic form.

This starts with the implementation of the key components and services of the Embedded Controller.  Examples of how this may be accomplished will have been written for Battery, Charger, and Thermal at least, and possibly also USB.  These will be referred to as this book lays out which components need to be available, and how they must behave to be considered viable for the integration.

There will be a bit of a split track on this depending upon whehter or not the integration is into a "Legacy" (x86) environment or a "Secure" (ARM) environment incorporating a hypervisor and Hafnium.

_This "split" is not currently represented in the TOC listing, but will be added when the point of deviation becomes more resolved, and will include a new look at using Hafnium_

When all the Embedded Controller work is complete, it's time to move on to the Patina Boot Firmware.  Again, this is covered in prior introductory and example material that is referred to in this book.  Again, this discussion will split between support for the Secure and Legacy integrations with regard to orchestrating with the EC both in DXE and in Runtime.

_This "split" is not currently represented in the TOC listing, but will be added when the point of deviation becomes more resolved, and will include a new look at configuring paging tables and coordination with the FFA, etc._


The Patina discussion will also necessarily touch upon HID elements - at least a keyboard - and presumably with similar example articles to refer to as the other components for this.

Finally, the Patina layer will execute the boot loader to load and start a Windows OS image.  From there we can run a simple application to demonstrate the runtime services can report on battery status and/or other aspects.

The book closes with a summary and takeaways and suggested further references.


