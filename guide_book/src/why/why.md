# Why ODP?

Modern computing devices are ubiquitous in our lives.  They are integral to multiple aspects of our lives, from our workplace, to our finances, our creative endeavors, and our personal lifestyles.

Computer technology seemingly lept from its cradle a half century ago and never slowed its pace. It is easy to take much of it for granted.

We marvel as the new applications show us increasingly amazing opportunities.  We also recognize and guard against the threats these applications pose to ourselves and society.  

And in this heady environment, it is sometimes easy to forget that the "hidden parts" of these computers we use -- the lower-level hardware and firmware -- is often built upon languages and processes that, although having evolved to meet the demands of the time, are reaching the end of their practical sustainability for keeping up with the accelerating pace of the world around us.

What was originally just a "boot layer" and a few K of code for key hardware interfacing is now shouldering the responsibility of securing personal information and behavior patterns that a malicious intruder could use for nefarious purposes.  

High-value proprietary algorithms and Artificial Intelligence models are now built into the firmware and must be locked down. An increasing number of "always ready" peripherals, such as the battery and charger, biometric identification mechanisms, network connections, and other concerns are being increasingly handled by independent MCUs that must coordinate with one another and with the host system in a responsive, increasingly complex, yet highly secure manner.

Trying to manage all of this with what has been the status-quo for these concerns in past decades, without memory-safe languages and with a loosely-federated collection of standards and patterns agreed upon by an ad-hoc consortium of vendors is increasingly dangerous and costly.

---------------------


| __Legacy Approach__ | __ODP Approach__ |
| --------------------| -----------------|
| 🐜 Many vendor-specific changesets ❌ | 🧩 Cross-platform modularity 🔒|
| ❄️ Weak component isolation 🩸 | 🔐 Secure runtime services 🤖 |
| 🔩 Proprietary tool building ⚔️ | 🛠️ Rust-based build tools, Stuart 🧑‍🔧|



> _The firmware we once almost ignored is now the front line of platform security_

---------------------

The Open Device Partnership offers an alternative and a way forward to a more sustainable future that, while still built upon the proven paradigms of the past, boldly rejects the patterns that are known to be costly and ineffective in favor of future-ready, portable, sustainable, and expandable alternatives.

Key to this is the adoption of the programming language Rust as the successor to C. This immediately brings greater confidence that the code will not be susceptible to programming-error related vulnerabilities that may lead to either costly performance behaviors or be maliciously exploited by opportunistic bad actors. Code may be marked `unsafe` to allow certain difficult-to-static-analyze behaviors that can be asserted to be risk-free, so potentially dangerous area must be carefully justified.  Furthermore, the patterns adopted by ODP provides the confidence that code from outside of one's immediate provenance of control may be audited and trusted and ready to join into a firmware construction built upon industry standards.

In the pages ahead, we'll look a little more closely at the advantages of ODP one at a time.




