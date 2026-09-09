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
    <div className="flex min-h-screen flex-col bg-black text-zinc-200">
      <SiteNav />
      <main className="mx-auto w-full max-w-3xl flex-1 px-4 pt-28 pb-16 sm:px-6">
        <p className="text-sm text-zinc-500">Legal</p>
        <h1 className="mt-3 text-4xl text-white">{title}</h1>
        <div className="mt-10 space-y-5 text-sm leading-7 text-zinc-400">{children}</div>
      </main>
      <SiteFooter />
    </div>
  )
}
