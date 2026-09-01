# Security Policy

## Supported Versions

Only the latest release receives security updates.

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, email **security@idevtim.com** with:

- A description of the vulnerability
- Steps to reproduce
- Your StillAir version and macOS version

You can expect an initial response within 48 hours. If the vulnerability is confirmed, a fix will be prioritized and released as soon as possible. You'll be credited in the release notes unless you prefer to remain anonymous.

## Scope

StillAir is an unprivileged menu bar app. It reads SMC temperatures and Darwin thermal-pressure notify state. It does not write SMC keys and has no privileged helper.

Especially relevant:

- IOKit / SMC read handling
- Persistence under Application Support/StillAir
- Network requests (update checker)
