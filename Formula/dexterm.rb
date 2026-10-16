# Homebrew tap formula for dexterm (task-1301). Lives in a tap repo (e.g. github.com/dexterm-xyz/homebrew-dexterm,
# file Formula/dexterm.rb); users run `brew install dexterm-xyz/dexterm/dexterm`.
#
# It installs the reproducible source tarball from the GitHub release into libexec, links the workspace
# packages the same way install.sh does (dexterm has no third-party runtime deps, so no npm registry access
# is needed at install time), and writes a `dexterm` wrapper that runs Homebrew's Node. Nothing is compiled
# and nothing is a signed Mach-O, so Gatekeeper and notarization do not apply. The optional native chart
# window stays a user choice (`cargo` build documented in the README).
#
# Before the first release: replace dexterm-xyz, the version, and the sha256 (the SHA256SUMS line of the tarball;
# dexterm/distribution/GO-LIVE.md GO 2 does it with sed). `brew audit --strict --new dexterm` and
# `brew test dexterm` must pass in the tap.
class Dexterm < Formula
  desc "Terminal Solana memecoin screener with a local Claude analyst"
  homepage "https://dexterm.xyz"
  url "https://github.com/dexterm-xyz/dexterm/releases/download/v0.1.2/dexterm-0.1.2-src.tar.gz"
  sha256 "08c7bda1ab2806a3644b5484811f8da2548ffda24ed2709635edb0a336feec63"
  license "AGPL-3.0-only"
  head "https://github.com/dexterm-xyz/dexterm.git", branch: "main"

  depends_on "node" # >= 22.18: Homebrew's node is 24.x

  def install
    libexec.install Dir["*"]
    # same wiring as install.sh: EVERY workspace package except cli becomes node_modules/@dexterm/<name>
    # (derived, not a hand list: a stale list left @dexterm/packs and custom unlinked and crashed on first run)
    (libexec/"node_modules/@dexterm").mkpath
    (libexec/"packages").children.select { |d| d.directory? && (d/"package.json").exist? }.each do |dir|
      next if dir.basename.to_s == "cli"
      (libexec/"node_modules/@dexterm"/dir.basename).make_symlink dir
    end
    (bin/"dexterm").write <<~SH
      #!/bin/sh
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/packages/cli/bin/dexterm.mjs" "$@"
    SH
  end

  def caveats
    <<~EOS
      Run `dexterm doctor` first. Trading is paper by default.
      The analyst needs Claude Code (`claude`) installed and logged in; everything else works without it.
      For the docked chart window, install Rust and run:
        cd #{libexec}/packages/popup && npm run build:shell
    EOS
  end

  test do
    # offline, non-interactive, no live source contacted. The fixture frame imports every workspace package,
    # so a missing link fails here (ERR_MODULE_NOT_FOUND) instead of on the user's first run.
    output = shell_output("DEXTERM_OFFLINE=1 NO_COLOR=1 #{bin}/dexterm --help")
    assert_match "dexterm", output
    frame = shell_output("DEXTERM_OFFLINE=1 NO_COLOR=1 #{bin}/dexterm --screen screener --fixtures")
    assert_match "dexterm", frame
  end
end
