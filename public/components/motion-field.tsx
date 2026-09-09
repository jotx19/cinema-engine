"use client"

import { motion } from "motion/react"

const bars = [18, 42, 28, 64, 36, 80, 22, 58, 44, 72, 30, 90, 24, 50, 66, 38, 20, 76]

export function MotionField() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      <div className="absolute inset-0 bg-[linear-gradient(to_right,rgba(255,255,255,0.045)_1px,transparent_1px),linear-gradient(to_bottom,rgba(255,255,255,0.045)_1px,transparent_1px)] bg-size-[72px_72px] [mask-image:radial-gradient(ellipse_at_center,black_35%,transparent_80%)]" />

      <motion.p
        className="absolute top-10 left-[-8%] font-sans text-[18vw] leading-[0.8] font-semibold tracking-[-0.08em] text-white/[0.045] uppercase select-none"
        animate={{ x: ["0%", "-6%", "0%"] }}
        transition={{ duration: 18, repeat: Infinity, ease: "easeInOut" }}
      >
        cinema
      </motion.p>
      <motion.p
        className="absolute right-[-12%] bottom-8 font-sans text-[16vw] leading-[0.8] font-semibold tracking-[-0.08em] text-white/[0.04] uppercase select-none"
        animate={{ x: ["0%", "5%", "0%"] }}
        transition={{ duration: 22, repeat: Infinity, ease: "easeInOut" }}
      >
        engine
      </motion.p>

      <motion.div
        className="absolute -left-24 top-20 size-[460px] rounded-full border border-white/10"
        animate={{ rotate: 360 }}
        transition={{ duration: 48, repeat: Infinity, ease: "linear" }}
      >
        <span className="absolute top-0 left-1/2 size-2 -translate-x-1/2 rounded-full bg-white" />
      </motion.div>
      <motion.div
        className="absolute -right-20 bottom-6 size-[340px] rounded-full border border-white/8"
        animate={{ rotate: -360 }}
        transition={{ duration: 36, repeat: Infinity, ease: "linear" }}
      />
      <motion.div
        className="absolute top-1/3 right-1/4 size-3 rounded-full bg-white/80"
        animate={{ y: [0, -18, 0], opacity: [0.4, 1, 0.4] }}
        transition={{ duration: 4.2, repeat: Infinity, ease: "easeInOut" }}
      />

      <div className="absolute right-6 bottom-24 flex h-44 items-end gap-1.5 opacity-80 sm:right-16">
        {bars.map((height, index) => (
          <motion.span
            key={index}
            className="w-1 origin-bottom rounded-full bg-white"
            animate={{ scaleY: [0.28, 1, 0.4, 0.92, 0.28] }}
            transition={{
              duration: 1.7 + (index % 6) * 0.18,
              repeat: Infinity,
              delay: index * 0.04,
              ease: "easeInOut",
            }}
            style={{ height }}
          />
        ))}
      </div>
    </div>
  )
}

export function Marquee({ reverse = false }: { reverse?: boolean }) {
  const text = "STREMIO  ·  SYSTEM AUDIO  ·  BLACKHOLE  ·  CINEMA DSP  ·  AIRPODS  ·  HRTF  ·  "
  return (
    <div className="relative overflow-hidden border-y border-white/10 py-3">
      <motion.div
        className="flex whitespace-nowrap font-mono text-[11px] tracking-[0.42em] text-zinc-500 uppercase"
        animate={{ x: reverse ? ["-50%", "0%"] : ["0%", "-50%"] }}
        transition={{ duration: reverse ? 26 : 22, repeat: Infinity, ease: "linear" }}
      >
        <span className="pr-8">{text.repeat(8)}</span>
        <span className="pr-8">{text.repeat(8)}</span>
      </motion.div>
    </div>
  )
}
