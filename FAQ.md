# FAQ

### Secretive doesn't work with my git client

Secretive relies on the `SSH_AUTH_SOCK` environment variable being respected. The `git` and `ssh` command line tools natively respect this, but third party apps may require some configuration to work. A non-exhaustive list of clients is provided here:

Tower - [Instructions](https://www.git-tower.com/help/mac/integration/environment)
GitHub Desktop: Should just work, no configuration needed

### Why should I trust you?

You shouldn't, for a piece of software like this. Secretive, by design, has an auditable build process. Each build has a fully auditable build log, showing the source it was built from and a SHA of the build product. You can check the SHA of the zip you download against the SHA output in the build log (which is linked in the About window).

### I want to build Secretive from source

Awesome! Just bear in mind that because an app only has access to the keychain items that it created, if you have secrets that you created with the prebuilt version of Secretive, you'll be unable to access them using your own custom build (since you'll have changed the bundled ID).

### I have a security issue

Please contact [mailto:max.goedjen@gmail.com](max.goedjen@gmail.com) immediately with details, and I'll address the issue and credit you ASAP.

### I want to contribute to Secretive

Sweet! Please check out the [contributing guidelines](Contributing.md) and go from there.