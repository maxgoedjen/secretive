# Setting up Third Party Apps FAQ

## Tower

Tower provides [instructions](https://www.git-tower.com/help/mac/integration/environment).

## GitHub Desktop

Should just work, no configuration needed

## Fork

Add this to your `~/.ssh/config` (the path should match the socket path from the setup flow).

```
Host *
	IdentityAgent /Users/$YOUR_USERNAME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
```

## VS Code

Add this to your `~/.ssh/config` (the path should match the socket path from the setup flow).

```
Host *
	IdentityAgent /Users/$YOUR_USERNAME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
```


# The app I use isn't listed here!

If you know how to get it set up, please open a PR for this page and add it! Contributions are very welcome.
If you're not able to get it working, please file a [GitHub issue](https://github.com/maxgoedjen/secretive/issues/new) for it. No guarantees we'll be able to get it working, but chances are someone else in the community might be able to.