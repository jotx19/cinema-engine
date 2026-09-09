"use client"

import { motion } from "motion/react"

const knobs = [
  { name: "bass", value: 70 },
  { name: "width", value: 80 },
  { name: "dialogue", value: 60 },
  { name: "room", value: 40 },
]

export function MixerPreview({ compact = false }: { compact?: boolean }) {
  return (
    <div
      className={
        compact
          ? "overflow-hidden bg-transparent"
          : "overflow-hidden rounded-2xl border border-white/10 bg-[#050505]"
      }
    >
      {compact ? null : (
        <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
          <p className="font-mono text-[11px] tracking-[0.28em] text-zinc-500 uppercase">
            live mixer
          </p>
          <span className="flex items-center gap-2 font-mono text-[11px] tracking-[0.18em] text-emerald-400 uppercase">
            <span className="size-1.5 animate-pulse rounded-full bg-emerald-400" />
            running
          </span>
        </div>
      )}
      <div className={compact ? "grid gap-6 pt-4 lg:grid-cols-[1.1fr_0.9fr]" : "grid gap-8 p-6 lg:grid-cols-[1.1fr_0.9fr]"}>
        <div className="space-y-5">
          {knobs.map((knob, index) => (
            <div key={knob.name}>
              <div className="mb-2 flex items-baseline justify-between font-mono text-[11px] tracking-[0.2em] uppercase">
                <span className={index === 0 ? "text-white" : "text-zinc-500"}>{knob.name}</span>
                <span className="text-zinc-300">{knob.value}</span>
              </div>
              <div className="h-px bg-white/10">
                <motion.div
                  className="h-px bg-white"
                  initial={{ width: 0 }}
                  whileInView={{ width: `${knob.value}%` }}
                  viewport={{ once: true }}
                  transition={{ duration: 1.1, delay: index * 0.12, ease: "easeOut" }}
                />
              </div>
            </div>
          ))}
        </div>
        <div className="flex h-32 items-end justify-between gap-1 border border-white/8 bg-black px-3 py-3 lg:h-44">
          {Array.from({ length: 28 }).map((_, index) => (
            <motion.span
              key={index}
              className="w-full origin-bottom rounded-sm bg-sky-300/90"
              animate={{ scaleY: [0.2, 0.85 + (index % 5) * 0.03, 0.35, 1, 0.2] }}
              transition={{
                duration: 1.4 + (index % 7) * 0.12,
                repeat: Infinity,
                delay: index * 0.03,
                ease: "easeInOut",
              }}
              style={{ height: `${40 + ((index * 17) % 55)}%` }}
            />
          ))}
        </div>
      </div>
      {compact ? null : (
        <div className="border-t border-white/10 px-4 py-3 font-mono text-[11px] tracking-[0.16em] text-zinc-500 uppercase">
          in blackhole 2ch · out headphones · preset theatre
        </div>
      )}
    </div>
  )
}
