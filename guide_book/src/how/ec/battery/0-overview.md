# Battery and Power Management

This example shows how to implement a mock battery service as part of the Embedded Controller (EC) power management system.

In this sample, we are going to implement a complete battery service subsystem.

## Relevant Repositories

We don't need to reinvent any wheels here. The ODP resources include ample template code and examples we can refer to for such a task. It is useful to identify which repositories contain these resources:

### embedded-services

We've touched on this before in [Embedded Services](../embedded_services/index.html), where we examined a Thermal subsystem implementation and explored variations between secure ARM-based and legacy x86_64-based systems.

We'll return to both of these concepts later. For now, we’ll focus on implementing a Battery subsystem and related Power Policy services. After that, we’ll fold in Thermal support and revisit the secure vs. non-secure implementations.

### embedded-batteries

This repository defines the Hardware Abstraction Layer (HAL) for a battery, tailored to the specific IC hardware being targeted. It builds a layered API chain upward, making most of the code portable and reusable across different integrations.

### embassy

Although our first exercises will be limited to simple desktop tests, we will then be building for an embedded context and that will require us to use features from [Embassy](https://embassy.dev/) both directly and indirectly.

### soc-embedded-controller

This repository provides the core EC functionality, which in this case is centered around power policy and regulation.

We will refer to this later as we work on our own (virtual) battery service implementation.

We’ll begin with the battery service — one of the embedded services — and later return here to integrate our battery into the broader scope of power management.

