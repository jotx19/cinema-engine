"use client"

import { HugeiconsIcon } from "@hugeicons/react"
import Link from "next/link"
import { GithubIcon, Menu01Icon, ScrollTextIcon } from "@hugeicons/core-free-icons"

import { SiteLogo } from "@/components/site-logo"
import { Button } from "@/components/ui/button"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"

export function SiteNav() {
  return (
    <header className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center p-4 sm:p-5">
      <div className="pointer-events-auto relative flex h-11 w-[70vw] min-w-[min(100%,20rem)] max-w-5xl items-center justify-between gap-3 rounded-xl bg-white/8 px-3 shadow-[0_8px_32px_rgba(0,0,0,0.35)] backdrop-blur-xl sm:h-18 sm:px-4">
        <SiteLogo size={66} />

        <div className="flex shrink-0 items-center gap-1.5">
          <Button
            nativeButton={false}
            size="sm"
            className="hidden h-13 gap-1.5 rounded-lg px-5.5 text-[17px] md:inline-flex"
            render={
              <a href="https://github.com/jotx19/cinema-engine" target="_blank" rel="noreferrer" />
            }
          >
            GitHub
            {/* <HugeiconsIcon icon={GithubIcon} size={18} strokeWidth={1.75} /> */}
          </Button>

          <Sheet>
            <SheetTrigger
              render={
                <Button
                  variant="ghost"
                  size="icon"
                  className="size-8 md:hidden"
                  aria-label="Open menu"
                />
              }
            >
              <HugeiconsIcon icon={Menu01Icon} size={16} strokeWidth={1.75} />
            </SheetTrigger>
            <SheetContent side="right" className="border-white/10 bg-black">
              <SheetHeader>
                <SheetTitle className="text-xs text-white">cinema-engine</SheetTitle>
              </SheetHeader>
              <div className="mt-8 flex flex-col gap-4 px-4">
                <Link
                  href="https://github.com/jotx19/cinema-engine"
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-2 text-xs text-white"
                >
                  <HugeiconsIcon icon={GithubIcon} size={14} strokeWidth={1.75} />
                  GitHub
                </Link>
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  )
}
