# Secretive ![Test](https://github.com/maxgoedjen/secretive/workflows/Test/badge.svg) ![Release](https://github.com/maxgoedjen/secretive/workflows/Release/badge.svg)


Secretive is an app for storing and managing SSH keys in the Secure Enclave. It is inspired by the [sekey project](https://github.com/sekey/sekey), but rewritten in Swift with no external dependencies and with a handy native management app.

<img src="/.github/readme/app.png" alt="Screenshot of Secretive" width="600">


## Why?

### Safer Storage

The most common setup for SSH keys is just keeping them on disk, guarded by proper permissions. This is fine in most cases, but it's not super hard for malicious users or malware to copy your private key. If you store your keys in the Secure Enclave, it's impossible to export them, by design.

### Access Control

If your Mac has a Secure Enclave, it also has support for strong access controls like Touch ID, or authentication with Apple Watch. You can configure your key so that they require Touch ID (or Watch) authentication before they're accessed.

<img src="/.github/readme/touchid.png" alt="Screenshot of Secretive authenticating with Touch ID">

### Notifications

Secretive also notifies you whenever your keys are acceessed, so you're never caught off guard.

<img src="/.github/readme/notification.png" alt="Screenshot of Secretive notifying the user">

### Support for Smart Cards Too!

For Macs without Secure Enclaves, you can configure a Smart Card (such as a YubiKey) and use it for signing as well.

## Getting Started

### FAQ

There's a [FAQ here](FAQ.md).

### Auditable Build Process

Builds are produced by GitHub Actions with an auditable build and release generation process. Each build has a "Document SHAs" step, which will output SHA checksums for the build produced by the GitHub Action, so you can verify that the source code for a given build corresponds to any given release.

### A Note Around Code Signing and Keychains

While Secretive uses the Secure Enclave for key storage, it still relies on Keychain APIs to access them. Keychain restricts reads of keys to the app (and specifically, the bundle ID) that created them. If you build Secretive from source, make sure you are consistent in which bundle ID you use so that the Keychain is able to locate your keys.

### Backups and Transfers to New Machines

Because secrets in the Secure Enclave are not exportable, they are not able to be backed up, and you will not be able to transfer them to a new machine. If you get a new Mac, just create a new set of secrets specific to that Mac.

## Security

If you discover any vulnerabilities in this project, please notify [max.goedjen@gmail.com](mailto:max.goedjen@gmail.com) with the subject containing "SECRETIVE SECURITY."
