"use client"

import Image from "next/image"
import type { ReactNode } from "react"

import { OpenTerminalButton } from "@/components/open-terminal-button"
import { SiteFooter } from "@/components/site-footer"
import { SiteNav } from "@/components/site-nav"

function Check() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
      <path
        d="M2.5 6.2 4.8 8.5 9.5 3.5"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function Row({
  icon,
  label,
  selected,
  dimmed,
}: {
  icon: ReactNode
  label: string
  selected?: boolean
  dimmed?: boolean
}) {
  return (
    <div
      className={`mx-1 flex items-center gap-2 rounded-[7px] px-2 py-[6px] text-[12px] ${
        selected ? "bg-white/14 text-white" : dimmed ? "text-white/35" : "text-white"
      }`}
    >
      <span className="flex size-[18px] shrink-0 items-center justify-center opacity-90">{icon}</span>
      <span className="min-w-0 flex-1 truncate">{label}</span>
      {selected ? <Check /> : null}
    </div>
  )
}

function MixRuler({ value }: { value: number }) {
  return (
    <div className="relative mt-2 h-4">
      <div className="absolute inset-x-0 top-1/2 flex -translate-y-1/2 items-center gap-[2.5px] px-1">
        {Array.from({ length: 36 }).map((_, i) => (
          <span
            key={i}
            className={`w-[1.5px] flex-1 rounded-full ${
              i / 35 <= value / 100 ? "bg-white/40" : "bg-white/16"
            }`}
            style={{ height: i % 6 === 0 ? 11 : i % 3 === 0 ? 8 : 5 }}
          />
        ))}
      </div>
      <span
        className="absolute top-1/2 h-[16px] w-[9px] -translate-y-1/2 rounded-full bg-[#e8e8ed] shadow-[0_0.5px_2px_rgba(0,0,0,0.45)] ring-[0.5px] ring-black/25"
        style={{ left: `calc(${value}% - 4.5px)` }}
      />
    </div>
  )
}

function MenuBarPanel() {
  return (
    <div className="w-full overflow-hidden rounded-[14px] border border-white/18 bg-black/45 shadow-[0_20px_50px_rgba(0,0,0,0.35)] backdrop-blur-2xl backdrop-saturate-150">
      {/* Header */}
      <div className="px-3 pt-2.5 pb-2">
        <div className="flex items-center justify-between gap-2">
          <p className="text-[11px] font-semibold text-white/55">Cinema Engine</p>
          <div className="flex items-center gap-1">
            <span className="rounded-full bg-[#0a84ff] px-2.5 py-[3px] text-[10px] font-semibold text-white">
              Start
            </span>
            <span className="rounded-full bg-white/10 px-2.5 py-[3px] text-[10px] font-semibold text-white/40">
              Stop
            </span>
          </div>
        </div>

        <div className="mt-2.5 flex items-center gap-2">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" className="shrink-0 text-white/55" aria-hidden="true">
            <path d="M11 5 6 9H3v6h3l5 4V5Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
            <path d="M15.5 8.5a5 5 0 0 1 0 7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
          <div className="relative h-[3px] flex-1 rounded-full bg-white/15">
            <div className="absolute inset-y-0 left-0 w-[78%] rounded-full bg-[#0a84ff]" />
            <span className="absolute top-1/2 left-[78%] size-[10px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[#c7c7cc] shadow-sm ring-[0.5px] ring-black/20" />
          </div>
        </div>
      </div>

      <div className="mx-2.5 h-px bg-white/10" />

      <p className="px-3 pt-2 pb-0.5 text-[11px] font-semibold text-white/45">Output</p>
      <Row
        label="MacBook Air Speakers"
        icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <rect x="3" y="4" width="18" height="13" rx="1.5" stroke="currentColor" strokeWidth="1.5" />
            <path d="M8 20h8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
        }
      />
      <Row
        label="AirPods Pro"
        selected
        icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M11 5 6 9H3v6h3l5 4V5Z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
            <path d="M15.5 8.5a5 5 0 0 1 0 7M18 7a8 8 0 0 1 0 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
        }
      />

      <div className="mx-2.5 my-1.5 h-px bg-white/10" />

      <p className="px-3 pt-0.5 pb-0.5 text-[11px] font-semibold text-white/45">Preset</p>
      <Row
        label="Theatre"
        selected
        icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M3.5 10.5c0-3.2 2.6-5.5 5.2-5.5 1.9 0 3.3 1 3.8 2.4.5-1.4 1.9-2.4 3.8-2.4 2.6 0 5.2 2.3 5.2 5.5 0 4.8-4.2 7.8-9 7.8s-9-3-9-7.8Z" stroke="currentColor" strokeWidth="1.4" />
            <circle cx="8.2" cy="10.5" r="0.9" fill="currentColor" />
            <circle cx="15.8" cy="10.5" r="0.9" fill="currentColor" />
          </svg>
        }
      />
      <Row
        label="Reference"
        icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M12 3v13" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            <circle cx="12" cy="19" r="2.2" stroke="currentColor" strokeWidth="1.5" />
            <path d="M8.5 6.5c0-2 1.6-3.5 3.5-3.5s3.5 1.5 3.5 3.5" stroke="currentColor" strokeWidth="1.5" />
          </svg>
        }
      />
      <Row
        label="Night"
        icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M14.5 5.5A7 7 0 1 0 19 15a8 8 0 0 1-4.5-9.5Z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
          </svg>
        }
      />

      <div className="mx-2.5 my-1.5 h-px bg-white/10" />

      <p className="px-3 pt-0.5 pb-0.5 text-[11px] font-semibold text-white/45">Mix</p>
      <div className="space-y-2.5 px-3 pb-2">
        {[
          {
            label: "Width",
            value: 80,
            icon: (
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M4 12h16M7 9 4 12l3 3M17 9l3 3-3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            ),
          },
          {
            label: "Dialogue",
            value: 60,
            icon: (
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <circle cx="9" cy="8" r="3" stroke="currentColor" strokeWidth="1.4" />
                <path d="M3.5 19c1.4-3 3.8-4.5 5.5-4.5S14 16 15.5 19" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
                <path d="M16.5 9c1 .8 1.7 2 1.7 3.4" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
              </svg>
            ),
          },
          {
            label: "Room",
            value: 40,
            icon: (
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path d="M4 20V10l8-5 8 5v10" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" />
                <path d="M9 20v-6h6v6" stroke="currentColor" strokeWidth="1.4" />
              </svg>
            ),
          },
        ].map((row) => (
          <div key={row.label}>
            <div className="flex items-center justify-between text-[12px] text-white">
              <span className="flex items-center gap-1.5 text-white/90">
                <span className="text-white/70">{row.icon}</span>
                {row.label}
              </span>
              <span className="text-[11px] text-white/45 tabular-nums">{row.value}</span>
            </div>
            <MixRuler value={row.value} />
          </div>
        ))}
      </div>

      <div className="mx-2.5 my-1.5 h-px bg-white/10" />

      <p className="px-3 pt-0.5 pb-0.5 text-[11px] font-semibold text-white/45">Spatial Audio</p>
      <Row
        dimmed
        label="Not Available"
        icon={
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M5 10v4a4 4 0 0 0 4 4h1V6H9a4 4 0 0 0-4 4ZM19 10v4a4 4 0 0 1-4 4h-1V6h1a4 4 0 0 1 4 4Z" stroke="currentColor" strokeWidth="1.4" />
          </svg>
        }
      />

      <div className="mx-2.5 my-1.5 h-px bg-white/10" />
      <div className="px-3 py-2.5 text-[12px] text-white/90">Quit Cinema Engine…</div>
    </div>
  )
}

function WidgetPreview() {
  return (
    <figure className="relative mx-auto w-full max-w-[320px] lg:mx-0 lg:ml-auto">
      {/* Top-right desktop crop — finished on top/right, bleeds left/bottom */}
      <div className="relative aspect-[3/4] overflow-hidden rounded-tr-[18px]">
        {/* Warm wallpaper — extends past crop so edges feel cut */}
        <div
          className="absolute -inset-[25%]"
          style={{
            background:
              "radial-gradient(110% 90% at 10% 10%, #ffe08a 0%, transparent 50%), radial-gradient(90% 80% at 90% 25%, #ff9f43 0%, transparent 55%), radial-gradient(100% 100% at 55% 90%, #e85d04 0%, #c2410c 40%, #7c2d12 100%)",
          }}
        />
        <div
          className="absolute inset-0 opacity-35"
          style={{
            background:
              "radial-gradient(ellipse at 70% 35%, rgba(255,255,255,0.4), transparent 55%)",
          }}
        />

        {/* Menu bar — right side of a Mac desktop */}
        <div className="absolute inset-x-0 top-0 z-10 flex h-7 items-center justify-end gap-1.5 bg-black/25 pr-3 text-[10px] text-white backdrop-blur-md">
          <span className="flex size-[18px] items-center justify-center overflow-hidden rounded-[4px] bg-white/20 ring-1 ring-white/35">
            <Image
              src="/brand/cinema-engine-icon.png"
              alt=""
              width={14}
              height={14}
              className="size-[14px] rounded-[4px]"
            />
          </span>
          <span className="font-medium tabular-nums">9:41</span>
        </div>

        {/* Frosted widget hanging from menu bar */}
        <div className="absolute top-8 right-2.5 z-20 w-[88%]">
          <MenuBarPanel />
        </div>
      </div>
    </figure>
  )
}

function InfoCard({
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

export default function Home() {
  return (
    <div className="relative min-h-screen">
      <SiteNav />
      <main className="mx-auto w-full max-w-3xl px-6 pt-24 pb-16 sm:pt-32">
        <section className="mb-14 grid items-start lg:mb-16 lg:grid-cols-[minmax(0,1fr)_300px] lg:gap-8">
          <div className="min-w-0 pt-1 h-90">
            <h1 className="m-0 max-w-[16ch] text-[32px] leading-[1.1] font-medium tracking-[-0.035em] text-[#111] sm:text-[40px] sm:leading-[44px] sm:tracking-[-1.4px]">
              Theatre sound on your AirPods.
            </h1>
            <p className="mt-4 mb-8 max-w-[34ch] text-[17px] leading-[1.4] tracking-[-0.02em] text-[#6f6f6f] sm:text-[19px]">
              Cinema Engine sits between your mac and your audio to give cinema like experince, use for wider image, clearer dialogue,
              a little room, right from the menu bar.
            </p>
            <OpenTerminalButton />
          </div>

          <div className="flex justify-center lg:justify-end">
            <WidgetPreview />
          </div>
        </section>

        <div className="flex flex-col gap-4">
          <InfoCard
            title="How it works"
            rows={[
              {
                label: "Menu bar",
                body: "Lives quietly up top. Start and stop cinema sound without opening a window.",
              },
              {
                label: "BlackHole",
                body: "Routes Mac audio through a virtual driver so Cinema Engine can process it.",
              },
              {
                label: "Mix",
                body: "Width, dialogue, room, and bass. Tuned live while you watch.",
              },
              {
                label: "Spatial",
                body: "HRTF keeps the image in front of you on AirPods and other headphones.",
              },
              {
                label: "Output",
                body: "Click any playback device to send sound there. Aggregates stay out of the way.",
              },
            ]}
          />

          <InfoCard
            title="Requirements"
            rows={[
              { label: "macOS", body: "13 Ventura or later." },
              { label: "Hardware", body: "Apple silicon Mac." },
              {
                label: "Permissions",
                body: "Microphone access so BlackHole can be opened as a virtual input.",
              },
            ]}
          />

          <InfoCard
            title="Private by design"
            rows={[
              {
                label: "On device",
                body: "Audio stays on your Mac. Nothing is recorded, saved, or uploaded.",
              },
              {
                label: "Open source",
                body: "MIT licensed. Free to use, copy, modify, and sell.",
              },
            ]}
          />
        </div>

        <SiteFooter />
      </main>
    </div>
  )
}
