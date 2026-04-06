# Tutorial

#### _Ready to go hands-on?_

If you are not a developer, you can skip this section and go directly to the [Tracks of ODP](../tracks.md) to explore the various paths available. However, even non-developers may find it useful to understand the basics of Rust and how ODP uses it to ensure safety and reliability in firmware development.

If you plan on  writing real embedded code for real hardware, using one of many easily sourced and affordable development boards, such as the [STM32F3Discovery Board](https://www.st.com/en/evaluation-tools/stm32f3discovery.html), which is used in the _Rust Embedded Book_ and is appropriate for the introductory exercises we will conduct here, and should be suitable for hosting the simulated components we will build later to run independent of the host.

If you have a different development board, that's fine -- the examples are not really tied to any particular piece of  hardware, and only minor adjustments may be needed to adapt the instructions here to different hardware.

If you have a true SOC development board that features the hardware components we will be integrating, that's fantastic.  You'll need to attach actual HAL layers to pin traits rather that use our virtual examples, but the remainder of the exercises should track for you in that environment (with some adjustments).

If you do not have a development board -- no worries! You won't need any external development boards to complete the exercises and learn how to build and integrated ODP components using this guide.

>👓 👉 If you are new to embedded programming in Rust, you may find the guide and exercises in the 
[Rust Embedded Book](https://doc.rust-lang.org/stable/embedded-book/start) to be a great introduction. 

Once we have learned the basic principles of how to use the Rust language in an embedded environment, and have set up the tooling, we are ready to move into the ODP framework to structure our designs.

The next set of examples are meant to be explored on a development board.  Continue your journey with the [Discovery board](./tutorial/Discovery.md), which bridges familiar embedded projects and EC-style service structure.

#### ___Not__ ready to go hands-on?_
That's okay -- but you might want to look through this quick tutorial anyway because it contains key examples of the ODP construction patterns in practice.

