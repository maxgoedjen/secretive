# Homebrew Cask — Secretive with CLI binary symlink
# Phase 4.2: Add bin.install_symlink so `secretive` CLI is available in PATH
# after `brew install --cask secretive`.
#
# SUBMIT TO: https://github.com/Homebrew/homebrew-cask
# FILE:      Casks/s/secretive.rb
#
# The change: add `binary` stanza pointing to the CLI embedded inside the app.
# This creates a symlink at $(brew --prefix)/bin/secretive.

cask "secretive" do
  on_ventura :or_older do
    on_big_sur :or_older do
      version "2.3.1"
      sha256 "493a72362898b4480baa70f115d9515b41b2af4a503caf00277e2bc3824b0bbd"
    end
    on_monterey :or_newer do
      version "2.4.1"
      sha256 "00ddf651f1151f1e3888c51e58ce343f6888480db79771b6de7371db21bde4d8"
    end

    livecheck do
      skip "Legacy version"
    end
  end
  on_sonoma do
    version "3.0.4"
    sha256 "696d07812e4431075234a900a0136dbad3131a91086e535fc2b07d69a1d084ba"

    livecheck do
      skip "Legacy version"
    end
  end
  on_sequoia :or_newer do
    version "4.0.0"
    sha256 :no_check # update with real sha256 from the release artifact

    livecheck do
      url "https://github.com/maxgoedjen/secretive/releases/latest"
      strategy :github_latest
    end
  end

  url "https://github.com/maxgoedjen/secretive/releases/download/v#{version}/Secretive.zip"
  name "Secretive"
  desc "Store SSH keys in the Secure Enclave"
  homepage "https://github.com/maxgoedjen/secretive"

  app "Secretive.app"

  # Phase 4.2: Symlink the CLI binary embedded inside the app into Homebrew's bin/.
  # Users get `secretive` on their PATH without any manual setup.
  binary "#{appdir}/Secretive.app/Contents/MacOS/secretive"

  # Shell completions — installed to the correct Homebrew completion dirs.
  # zsh
  zsh_completion "completions/_secretive"
  # bash
  bash_completion "completions/secretive.bash"
  # fish
  fish_completion "completions/secretive.fish"

  # man page
  manpage "man/secretive.1"

  uninstall quit: "com.maxgoedjen.Secretive"

  zap trash: [
    "~/Library/Application Support/com.maxgoedjen.Secretive.SecretAgent",
    "~/Library/Logs/com.maxgoedjen.Secretive.SecretAgent",
  ]
end
