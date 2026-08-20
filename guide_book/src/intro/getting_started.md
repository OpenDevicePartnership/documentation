# Getting Started with ODP

![Choose Your Path](./media/choose_path.png)

## Welcome to the Open Device Partnership (ODP)!

ODP is a community-driven framework for building **secure**, **modular**, and **reusable** firmware components across a range of systems. Whether you’re interested in low-level boot firmware, embedded controller services, or integrating a complete firmware stack, ODP has something for you.

## What is ODP?

ODP brings modern software engineering practices—like memory safety and dependency injection—to the world of firmware. It leverages Rust to improve confidence, maintainability, and modularity across diverse hardware and system designs.

It also embraces existing standards like UEFI, DICE, ACPI, and EC protocols—but makes them more accessible and safer to implement.

---

## How to Use This Guide
This documentation is designed to serve multiple audiences working with the Open Device Partnership (ODP). Whether you're a firmware engineer, technology advisor, integrator, or contributor, you'll find resources tailored to your needs.

In the [Tracks of ODP](../tracks.md), you will find curated content organized into guided paths. Each track is designed to help you learn about ODP from different perspectives, whether you're focused on value propositions, specific technologies like Patina, or roles such as engineering or advising.

### Role-Based Reading Guidance

|   Role            | Recommended Path                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| __Firmware Engineer__ | Follow the documentation from start to finish. Includes technical tutorials, architectural insights, and integration exercises. |
| __Technology Advisor__ | Read the mainline content up through the Architectural Overview. Skip hands-on exercises. Then proceed to the Tracks page to explore summaries and technical overviews by topic.|    
| __Integrator__        | Read through the Architectural Overview and Integration sections, then follow the [Integrator Track](../../tracks/integrator/track_overview.md) for platform-specific setup and bundling guidance. |
| __Contributor__       | Review the mainline Value Proposition and Architecture Overview, then head to the [Contributor Track](../../tracks/contributor/track_overview.md) for community, contribution standards, and roadmap content. |
| __Security Reviewer__ | Jump to the [Security Track](../../tracks/security/track_overview.md). It includes collected topics around trusted boot, isolation, and other security concerns, with cross-links to affected design areas. |
| __Patina SDK (UEFI) Developer__ | Refer to external Patina resources: the [Patina Book](https://opendevicepartnership.github.io/patina/) for guides and concepts, and the [Patina source repository](https://github.com/opendevicepartnership/patina) for crates, code examples, and implementation notes. |  


---

### Where to next?

If you are not a developer, you can skip the next section and go directly to the [Tracks of ODP](../tracks.md) to explore the various paths available.  However, even non-developers may find it useful to understand the basics of Rust and how ODP uses it to ensure safety and reliability in firmware development.
