# Security Policy

## Security Principles

Secretive is designed with a few general tenets in mind:

### It's Hard to Leak a Key Secretive Can't Read The Key Material

Secretive only operates on hardware-backed keys. In general terms, this means that it should be _very_ hard for Secretive to have any sort of bug that causes a key to be shared, because Secretive can't access private key data even if it wants to.

### Simplicity and Auditability

Secretive won't expand to have every feature it could possibly have. Part of the goal of the app is that it is possible for consumers to reasonably audit the code, and that often means not implementing features that might be cool, but which would significantly inflate the size of the codebase.

### Dependencies

Both in support of the previous principle and to rule out supply chain attacks, Secretive does not rely on any third party dependencies. 

There are limited exceptions to this, particularly in the build process, but the app itself does not depend on any third party code.

## Supported Versions

The latest version on the [Releases page](https://github.com/maxgoedjen/secretive/releases) is the only currently supported version.

## Reporting a Vulnerability

To report security issues, please use [GitHub's private reporting feature.](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability#privately-reporting-a-security-vulnerability)
