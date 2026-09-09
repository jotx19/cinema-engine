import { LegalShell } from "@/components/legal-shell"

export const metadata = {
  title: "Terms of use · cinema-engine",
}

export default function TermsPage() {
  return (
    <LegalShell title="Terms of use">
      <p>Last updated 8 September 2026.</p>
      <p>
        cinema-engine is software you run on your own Mac. By downloading, installing, or using it,
        you agree to these terms.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">What you may do</h2>
      <p>
        The project is licensed under the MIT License. You may use, copy, modify, merge, publish,
        distribute, sublicense, and sell copies, provided you keep the copyright notice. See{" "}
        <a className="text-white underline" href="/license">
          License
        </a>
        .
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">What you must not do</h2>
      <p>
        Do not use cinema-engine to capture, process, or redistribute another person’s audio without
        their consent. Do not bypass macOS privacy prompts or install the software on a machine you
        do not control.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">Audio routing</h2>
      <p>
        While the engine runs, macOS system output is pointed at BlackHole so Stremio and other apps
        can be processed. Quitting restores the previous output when the process exits cleanly. You
        are responsible for your playback volume. High levels can damage hearing.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">No warranty</h2>
      <p>
        The software is provided “as is”, without warranty of any kind. The authors are not liable
        for device damage, hearing injury, lost audio, or routing that is left on BlackHole after a
        crash.
      </p>
      <h2 className="pt-4 text-lg font-medium text-white">Third-party software</h2>
      <p>
        BlackHole is a separate MIT-licensed driver. Optional MIT KEMAR HRTF files are a separate
        academic dataset and are not shipped in this project.
      </p>
    </LegalShell>
  )
}
