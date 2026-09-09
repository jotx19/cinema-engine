import { LegalShell } from "@/components/legal-shell"

export const metadata = {
  title: "Privacy · cinema-engine",
}

export default function PrivacyPage() {
  return (
    <LegalShell title="Privacy">
      <p>Last updated 8 September 2026.</p>
      <p>
        cinema-engine runs on your Mac. It does not include an account, analytics, or a network
        backend for personal data.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">Audio</h2>
      <p>
        The engine processes system audio locally (for example Stremio playback routed through
        BlackHole) and plays it to your headphones. Audio is not uploaded.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">Microphone permission</h2>
      <p>
        macOS may ask for Microphone access. That prompt exists because BlackHole appears as an
        audio input device. cinema-engine does not record your Mac microphone or AirPods microphone.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">Files on disk</h2>
      <p>
        Mix settings and runtime state may be stored under <code>~/.cinema-engine/</code> on your
        machine. We do not collect those files.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">This website</h2>
      <p>
        If you host this site yourself, your host’s logs and any fonts loaded from Google (via Next.js
        font optimization) are subject to that provider’s policies.
      </p>
    </LegalShell>
  )
}
