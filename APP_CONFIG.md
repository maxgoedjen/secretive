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

## nushell

Add this to your `~/.ssh/config` (the path should match the socket path from the setup flow).

```
Host *
	IdentityAgent /Users/$YOUR_USERNAME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
```

## Cyberduck

Add this to `~/Library/LaunchAgents/com.maxgoedjen.Secretive.SecretAgent.plist`

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>link-ssh-auth-sock</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>/bin/ln -sf $HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh $SSH_AUTH_SOCK</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

Log out and log in again before launching Cyberduck.

## Mountain Duck

Add this to `~/Library/LaunchAgents/com.maxgoedjen.Secretive.SecretAgent.plist`

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>link-ssh-auth-sock</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>/bin/ln -sf $HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh $SSH_AUTH_SOCK</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

Log out and log in again before launching Mountain Duck.

## GitKraken

Add this to `~/Library/LaunchAgents/com.maxgoedjen.Secretive.SecretAgent.plist`

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>link-ssh-auth-sock</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>/bin/ln -sf $HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh $SSH_AUTH_SOCK</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

Log out and log in again before launching Gitkraken. Then enable "Use local SSH agent in GitKraken Preferences (Located under Preferences -> SSH)

## Retcon

Add this to your `~/.ssh/config` (the path should match the socket path from the setup flow).

```
Host *
	IdentityAgent /Users/$YOUR_USERNAME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
```

# The app I use isn't listed here!

If you know how to get it set up, please open a PR for this page and add it! Contributions are very welcome.
If you're not able to get it working, please file a [GitHub issue](https://github.com/maxgoedjen/secretive/issues/new) for it. No guarantees we'll be able to get it working, but chances are someone else in the community might be able to.
