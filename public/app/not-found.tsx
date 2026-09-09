import Link from "next/link"

import { SiteFooter } from "@/components/site-footer"
import { SiteNav } from "@/components/site-nav"
import { Button } from "@/components/ui/button"

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col bg-black text-white">
      <SiteNav />
      <main className="mx-auto flex w-full max-w-6xl flex-1 flex-col justify-center px-4 py-24 sm:px-6">
        <p className="font-mono text-[11px] tracking-[0.28em] text-zinc-500 uppercase">404</p>
        <h1 className="mt-4 text-6xl font-semibold tracking-tight uppercase">No signal.</h1>
        <p className="mt-4 max-w-md text-sm text-zinc-400">That page is not on this mix.</p>
        <div className="mt-8">
          <Button nativeButton={false} className="rounded-full px-5" render={<Link href="/" />}>
            Home
          </Button>
        </div>
      </main>
      <SiteFooter />
    </div>
  )
}
