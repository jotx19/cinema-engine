"use client"

import type { ReactNode } from "react"
import { motion } from "motion/react"

import { cn } from "@/lib/utils"

export function BentoCard({
  className,
  children,
  delay = 0,
  id,
}: {
  className?: string
  children: ReactNode
  delay?: number
  id?: string
}) {
  return (
    <motion.div
      id={id}
      initial={{ opacity: 0, y: 18 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-48px" }}
      transition={{ duration: 0.45, delay }}
      className={cn(
        "relative h-full min-h-0 overflow-hidden rounded-2xl border border-white/10 bg-black",
        className
      )}
    >
      <div className="pointer-events-none absolute inset-0 z-[1] bg-[radial-gradient(ellipse_at_top_right,rgba(255,255,255,0.04),transparent_55%)]" />
      {children}
    </motion.div>
  )
}

export function BentoLabel({ children }: { children: ReactNode }) {
  return <p className="text-sm text-zinc-500">{children}</p>
}

export function BentoTitle({ children }: { children: ReactNode }) {
  return <h3 className="text-xl text-white">{children}</h3>
}

export function GradientStat({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <p
      className={cn(
        "bg-gradient-to-br from-violet-400 via-fuchsia-400 to-sky-400 bg-clip-text font-semibold tracking-tight text-transparent",
        className
      )}
    >
      {children}
    </p>
  )
}
