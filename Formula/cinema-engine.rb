class CinemaEngine < Formula
  desc "Cinema-style DSP for macOS system audio"
  homepage "https://github.com/jotx19/cinema-engine"
  url "https://github.com/jotx19/cinema-engine.git", branch: "main"
  version "1.0.0"
  license "MIT"

  depends_on xcode: ["14.3", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/cinema-engine"
  end

  def caveats
    <<~EOS
      BlackHole 2ch is required so cinema-engine can capture system audio:

        brew install --cask blackhole-2ch

      Then run:

        cinema-engine
    EOS
  end

  test do
    assert_match "1.0.0", shell_output("#{bin}/cinema-engine --version")
  end
end
