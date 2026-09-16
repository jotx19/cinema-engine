import type { Metadata } from "next"
import Link from "next/link"

import { InstallCommand } from "@/components/install-command"
import { SiteFooter } from "@/components/site-footer"
import { SiteNav } from "@/components/site-nav"

export const metadata: Metadata = {
  title: "Install · Cinema Engine",
  description:
    "Install Cinema Engine on macOS — one Terminal command, BlackHole, and the menu bar widget.",
}

function Card({
  title,
  rows,
}: {
  title: string
  rows: { label: string; body: string }[]
}) {
  return (
    <section className="overflow-hidden rounded-[20px] bg-white">
      <div className="px-6 pt-6 pb-3">
        <h2 className="m-0 text-[13px] font-medium tracking-[0.02em] text-[#6f6f6f] uppercase">
          {title}
        </h2>
      </div>
      <dl className="m-0">
        {rows.map((row, index) => (
          <div
            key={row.label}
            className={`grid grid-cols-1 gap-1 px-6 py-4 sm:grid-cols-[140px_1fr] sm:gap-4 ${
              index < rows.length - 1 ? "border-b border-[#efefef]" : ""
            }`}
          >
            <dt className="text-[#111]">{row.label}</dt>
            <dd className="m-0 text-[#6f6f6f]">{row.body}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}

export default function InstallPage() {
  return (
    <div className="relative min-h-screen bg-[#f5f5f5] text-[#111]">
      <SiteNav />
      <main className="mx-auto w-full max-w-[640px] px-6 pt-24 pb-16 sm:pt-32">
        <Link
          href="/"
          className="text-[13px] tracking-[-0.005em] text-[#6f6f6f] no-underline hover:text-[#111]"
        >
          ← Back
        </Link>

        <h1 className="mt-6 m-0 max-w-[14ch] text-[32px] leading-[1.1] font-medium tracking-[-0.035em] text-[#111] sm:text-[40px] sm:leading-[44px] sm:tracking-[-1.4px]">
          How to install
        </h1>
        <p className="mt-4 mb-8 max-w-[40ch] text-[17px] leading-[1.4] tracking-[-0.02em] text-[#6f6f6f] sm:text-[19px]">
          One Terminal command installs BlackHole and the Cinema Engine menu bar widget.
        </p>

        <InstallCommand />

        <p className="mt-4 mb-10 text-[13px] leading-5 text-[#6f6f6f]">
          Paste into Terminal, press Return, and enter your admin password when asked (BlackHole,
          first install only).
        </p>

        <div className="flex flex-col gap-4">
          <Card
            title="Prerequisites"
            rows={[
              { label: "macOS", body: "13 Ventura or later." },
              { label: "Hardware", body: "Apple silicon Mac." },
              {
                label: "Password",
                body: "One admin password the first time BlackHole is installed.",
              },
              {
                label: "Permissions",
                body: "Microphone access so BlackHole can be opened as a virtual input — not your hardware mic.",
              },
            ]}
          />

          <Card
            title="After install"
            rows={[
              {
                label: "Menu bar",
                body: "Look for the Cinema Engine icon in the top-right menu bar.",
              },
              {
                label: "Start",
                body: "Click the icon, then Start. Cinema sound routes through BlackHole to your headphones.",
              },
              {
                label: "Gatekeeper",
                body: "First launch: right-click the app → Open if macOS warns about an unidentified developer.",
              },
              {
                label: "Download only",
                body: "If you grabbed the zip from the homepage, still run the install command once so BlackHole is present.",
              },
            ]}
          />

          <Card
            title="What the script does"
            rows={[
              {
                label: "BlackHole",
                body: "Installs the virtual audio driver used to capture Mac system audio.",
              },
              {
                label: "Widget",
                body: "Builds and places Cinema Engine.app in Applications (or updates it).",
              },
              {
                label: "On device",
                body: "Nothing is uploaded. Audio stays on your Mac.",
              },
            ]}
          />

          <section className="overflow-hidden rounded-[20px] bg-white">
            <div className="px-6 pt-6 pb-3">
              <h2 className="m-0 text-[13px] font-medium tracking-[0.02em] text-[#6f6f6f] uppercase">
                Build from source
              </h2>
            </div>
            <div className="space-y-4 px-6 pb-6 text-[15px] leading-7 text-[#6f6f6f]">
              <p className="m-0">
                Prefer cloning the repo yourself:
              </p>
              <pre className="overflow-x-auto rounded-xl bg-[#111] px-4 py-3 font-mono text-[12px] leading-6 text-white/80">
                {`git clone https://github.com/jotx19/cinema-engine.git
cd cinema-engine
./install.sh`}
              </pre>
              <p className="m-0">
                Package the app only:
              </p>
              <pre className="overflow-x-auto rounded-xl bg-[#111] px-4 py-3 font-mono text-[12px] leading-6 text-white/80">
                {`./scripts/package-mac-app.sh
open "dist/Cinema Engine.app"`}
              </pre>
            </div>
          </section>
        </div>

        <SiteFooter />
      </main>
    </div>
  )
}
