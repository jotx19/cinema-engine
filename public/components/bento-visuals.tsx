"use client"

import type { ReactNode } from "react"
import { motion } from "motion/react"

import { cn } from "@/lib/utils"

function SpeakerRing({
  className,
  delay = 0,
  size = 56,
}: {
  className?: string
  delay?: number
  size?: number
}) {
  return (
    <motion.div
      className={cn("absolute", className)}
      style={{ width: size, height: size }}
      animate={{ scale: [1, 1.08, 1], opacity: [0.75, 1, 0.75] }}
      transition={{ duration: 2.8, repeat: Infinity, delay, ease: "easeInOut" }}
    >
      <span
        className="absolute inset-[-18%] rounded-full"
        style={{
          background:
            "radial-gradient(circle, rgba(56,189,248,0.0) 38%, rgba(56,189,248,0.22) 58%, rgba(56,189,248,0) 72%)",
        }}
      />
      <span className="absolute inset-0 rounded-full border-[3px] border-sky-300 shadow-[0_0_22px_6px_rgba(56,189,248,0.45)]" />
      <span className="absolute inset-[18%] rounded-full bg-[#05070b] shadow-[inset_0_0_12px_rgba(56,189,248,0.35)]" />
    </motion.div>
  )
}

export function SpatialListener() {
  return (
    <div className="relative h-full min-h-[280px] w-full overflow-hidden bg-black">
      <SpeakerRing className="top-[6%] left-1/2 -translate-x-1/2" delay={0} size={58} />
      <SpeakerRing className="top-[28%] left-[8%]" delay={0.4} size={52} />
      <SpeakerRing className="top-[28%] right-[8%]" delay={0.8} size={52} />
      <SpeakerRing className="bottom-[10%] left-[16%]" delay={1.1} size={48} />
      <SpeakerRing className="bottom-[10%] right-[16%]" delay={1.5} size={48} />

      <svg
        viewBox="0 0 240 240"
        className="absolute top-[38%] left-1/2 h-[42%] max-h-[190px] w-[42%] -translate-x-1/2"
        aria-hidden
      >
        <defs>
          <radialGradient id="tabletGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#7dd3fc" />
            <stop offset="55%" stopColor="#38bdf8" />
            <stop offset="100%" stopColor="#0ea5e9" />
          </radialGradient>
          <radialGradient id="spill" cx="50%" cy="45%" r="55%">
            <stop offset="0%" stopColor="rgba(56,189,248,0.35)" />
            <stop offset="100%" stopColor="rgba(56,189,248,0)" />
          </radialGradient>
        </defs>
        <ellipse cx="120" cy="148" rx="70" ry="48" fill="url(#spill)" />
        <ellipse cx="120" cy="168" rx="42" ry="22" fill="#0b0b0d" />
        <path
          d="M78 142c8-22 24-34 42-34s34 12 42 34c2 8-6 16-18 18H96c-12-2-20-10-18-18Z"
          fill="#141416"
        />
        <ellipse cx="120" cy="108" rx="24" ry="26" fill="#101012" />
        <ellipse cx="120" cy="104" rx="20" ry="18" fill="#1c1c20" />
        <path d="M86 138c8 10 16 16 34 16" stroke="#1a1a1e" strokeWidth="10" strokeLinecap="round" />
        <path d="M154 138c-8 10-16 16-34 16" stroke="#1a1a1e" strokeWidth="10" strokeLinecap="round" />
        <rect x="96" y="132" width="48" height="34" rx="5" fill="url(#tabletGlow)" />
        <rect x="100" y="136" width="40" height="26" rx="3" fill="#0ea5e9" opacity="0.55" />
      </svg>
    </div>
  )
}

export function SpatialHorizon({
  title = "Cinema sound",
  subtitle,
  children,
}: {
  title?: string
  subtitle?: string
  children?: ReactNode
}) {
  return (
    <div className="relative isolate min-h-[420px] overflow-hidden bg-black sm:min-h-[520px]">
      <CornerRings className="-top-28 -left-28" />
      <CornerRings className="-top-28 -right-28" />
      <CornerRings className="-bottom-28 -left-28" />
      <CornerRings className="-bottom-28 -right-28" />

      <PerspectiveDots className="top-0" />
      <PerspectiveDots className="bottom-0 rotate-180" />

      <div className="absolute inset-0 flex flex-col items-center justify-center px-6 text-center">
        <p className="mb-4 font-mono text-[11px] tracking-[0.38em] text-zinc-500 uppercase">
          Spatial mix · HRTF · macOS
        </p>
        <h1 className="text-5xl font-semibold tracking-tight text-white sm:text-7xl">{title}</h1>
        {subtitle ? (
          <p className="mt-5 max-w-md text-sm leading-6 text-zinc-400 sm:text-base">{subtitle}</p>
        ) : null}
        {children ? <div className="mt-8 flex flex-wrap items-center justify-center gap-3">{children}</div> : null}
      </div>
    </div>
  )
}

export function HeroSpatialLoops() {
  return (
    <div className="pointer-events-none absolute inset-0 z-[5] overflow-hidden">
      <WifiCorner className="top-0 left-0 -translate-x-1/2 -translate-y-1/2" />
      <WifiCorner className="top-0 right-0 translate-x-1/2 -translate-y-1/2" delay={0.35} />
      <WifiCorner className="bottom-0 left-0 -translate-x-1/2 translate-y-1/2" delay={0.7} />
      <WifiCorner className="right-0 bottom-0 translate-x-1/2 translate-y-1/2" delay={1.05} />
    </div>
  )
}

function CornerRings({ className }: { className?: string }) {
  return <WifiCorner className={cn("size-72", className)} />
}

function WifiCorner({
  className,
  delay = 0,
}: {
  className?: string
  delay?: number
}) {
  return (
    <div className={cn("absolute size-[20rem] sm:size-[24rem]", className)}>
      {[0, 1, 2, 3].map((ring) => (
        <motion.span
          key={ring}
          className="absolute inset-0 rounded-full will-change-transform"
          style={{
            background:
              "radial-gradient(circle, transparent 68%, rgba(255,255,255,0.12) 70%, rgba(255,255,255,0.8) 71.5%, rgba(255,255,255,0.12) 73%, transparent 75.5%)",
          }}
          initial={{ scale: 0.08, opacity: 0 }}
          animate={{ scale: [0.08, 0.42, 1], opacity: [0, 0.7, 0] }}
          transition={{
            duration: 3.6,
            repeat: Infinity,
            delay: delay + ring * 0.7,
            times: [0, 0.16, 1],
            ease: "easeOut",
          }}
        />
      ))}
    </div>
  )
}

function PerspectiveDots({ className }: { className?: string }) {
  const rows = 9
  const cols = 21

  return (
    <div
      className={cn("pointer-events-none absolute right-0 left-0 h-[42%] overflow-hidden", className)}
      style={{ perspective: "900px" }}
    >
      <div
        className="absolute inset-x-[-8%] origin-bottom"
        style={{
          height: "160%",
          transform: "rotateX(68deg) translateY(8%)",
          transformOrigin: "50% 100%",
        }}
      >
        <div
          className="grid h-full"
          style={{
            gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
            gridTemplateRows: `repeat(${rows}, minmax(0, 1fr))`,
          }}
        >
          {Array.from({ length: rows * cols }).map((_, index) => {
            const row = Math.floor(index / cols)
            const t = row / (rows - 1)
            const size = 2 + t * 5
            const opacity = 0.08 + t * 0.42
            return (
              <span key={index} className="flex items-center justify-center">
                <span
                  className="rounded-full bg-zinc-300"
                  style={{ width: size, height: size, opacity }}
                />
              </span>
            )
          })}
        </div>
      </div>
    </div>
  )
}

export function BassDriver() {
  return (
    <div className="relative mx-auto flex h-40 w-40 items-center justify-center">
      {[160, 120, 80, 44].map((size, index) => (
        <motion.span
          key={size}
          className="absolute rounded-full border border-sky-400/40"
          style={{ width: size, height: size }}
          animate={{ rotate: index % 2 === 0 ? 360 : -360, opacity: [0.35, 0.9, 0.35] }}
          transition={{ duration: 14 + index * 4, repeat: Infinity, ease: "linear" }}
        />
      ))}
      <motion.span
        className="absolute size-8 rounded-full bg-sky-400 shadow-[0_0_24px_rgba(56,189,248,0.7)]"
        animate={{ scale: [0.85, 1.12, 0.85] }}
        transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
      />
    </div>
  )
}

export function PresetRipple() {
  return (
    <div className="relative mx-auto mt-2 flex h-36 w-36 items-center justify-center">
      {[1, 2, 3].map((ring) => (
        <motion.span
          key={ring}
          className="absolute size-24 rounded-full border border-sky-400/50"
          animate={{ scale: [0.45, 1.4], opacity: [0.55, 0] }}
          transition={{ duration: 2.4, repeat: Infinity, delay: ring * 0.45, ease: "easeOut" }}
        />
      ))}
      <span className="relative z-10 size-10 rounded-full bg-sky-400 shadow-[0_0_30px_rgba(56,189,248,0.55)]" />
    </div>
  )
}

export function Waveform() {
  const bars = [22, 38, 18, 52, 30, 64, 26, 48, 20, 58, 34, 44]
  return (
    <div className="flex h-16 items-end gap-1">
      {bars.map((height, index) => (
        <motion.span
          key={index}
          className="w-1.5 origin-bottom rounded-full bg-sky-400"
          style={{ height }}
          animate={{ scaleY: [0.35, 1, 0.5, 0.9, 0.35] }}
          transition={{ duration: 1.5 + (index % 4) * 0.15, repeat: Infinity, delay: index * 0.05 }}
        />
      ))}
    </div>
  )
}
