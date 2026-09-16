import type { ReactNode } from "react"

import { SiteFooter } from "@/components/site-footer"
import { SiteNav } from "@/components/site-nav"

export function LegalShell({
  title,
  children,
}: {
  title: string
  children: ReactNode
}) {
  return (
    <div className="relative min-h-screen bg-[#f5f5f5] text-[#111]">
      <SiteNav />
      <main className="mx-auto w-full max-w-[640px] px-6 pt-24 pb-16 sm:pt-32">
        <p className="text-[13px] uppercase tracking-[0.02em] text-[#6f6f6f]">Legal</p>
        <h1 className="mt-2 text-[32px] leading-[1.1] font-medium tracking-[-0.035em] text-[#111] sm:text-[40px]">
          {title}
        </h1>
        <div className="mt-8 space-y-5 text-[15px] leading-7 text-[#6f6f6f]">{children}</div>
        <SiteFooter />
      </main>
    </div>
  )
}
