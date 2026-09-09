"use client"

import { BentoCard } from "@/components/bento-card"
import { HeroSpatialLoops } from "@/components/bento-visuals"
import { InstallCommand } from "@/components/install-command"
import { MediaFill } from "@/components/media-fill"
import { OpenTerminalButton } from "@/components/open-terminal-button"
import { SiteFooter } from "@/components/site-footer"
import { SiteNav } from "@/components/site-nav"
import { HugeiconsIcon } from "@hugeicons/react"
import { AppleIcon, HugeiconsFreeIcons, Lock, LockComputerFreeIcons, LockedIcon, LockOpen, LockSync01FreeIcons } from "@hugeicons/core-free-icons"

export default function Home() {
  return (
    <div className="bg-black">
      <SiteNav />
      <section className="relative h-svh overflow-hidden bg-black">
        <HeroSpatialLoops />
        <div className="relative z-10 flex justify-center px-4 pt-[18vh] sm:pt-[20vh]">
          <div id="install" className="flex w-full max-w-3xl flex-col items-center">
            <h1 className="text-5xl tracking-tight text-white sm:text-7xl">Cinema <span className="mask-linear-from-neutral-950 font-extralight text-6xl">X </span><span className="text-5xl tracking-tight text-white sm:text-6xl font-serif italic">Engine</span></h1>
            <p className="md:mt-5 md:mb-8 mt-2 mb-10 max-w-md text-center text-sm text-white/70 tracking-tight sm:text-base">
              Stream audio like a theatre, on your device.
            </p>
            <InstallCommand />
            <OpenTerminalButton />
          </div>
        </div>
      </section>

      <section className="relative z-10 -mt-[180px] px-4 pb-20 sm:px-6 lg:-mt-[180px]">
        <div className="mx-auto w-full max-w-4xl">
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-12 sm:grid-rows-[220px_220px_220px]">
            <BentoCard className="h-[220px] sm:col-span-8 sm:row-start-1 sm:h-full">
              <div className="relative z-[2] font-try font-black flex h-full items-center justify-center px-6">
                <p className="text-2xl tracking-tight inline-flex items-center md:gap-3 gap-2 text-white leading-none sm:text-4xl">Support <span><HugeiconsIcon icon={AppleIcon} size={30} strokeWidth={1.75} className="fill-current" />
                </span> silicon</p>
              </div>
            </BentoCard>

            <BentoCard className="h-[220px] sm:col-span-4 sm:row-start-1 sm:h-full" delay={0.05}>
              <MediaFill type="gif" src="/media/dots.gif" alt="HRTF spatial field" />
            </BentoCard>

            <BentoCard className="h-[220px] sm:col-span-4 sm:row-start-2 sm:h-full" delay={0.08}>
              <MediaFill type="image" src="/media/earbuds.jpg" alt="AirPods" />
            </BentoCard>

            <BentoCard className="h-[220px] sm:col-span-8 sm:row-start-2 sm:h-full" delay={0.1}>
              <MediaFill type="video" src="/media/purple.mp4" poster="/media/purple.jpg" />
            </BentoCard>

            <BentoCard className="h-[220px] sm:col-span-4 sm:row-start-3 sm:h-full" delay={0.12}>
              <MediaFill type="video" src="/media/airpods-pro.mp4" poster="/media/airpods-pro.jpg" />
            </BentoCard>

            <BentoCard className="h-[220px] sm:col-span-4 sm:row-start-3 sm:h-full" delay={0.14}>
              <MediaFill type="image" src="/media/airpods.jpg" alt="AirPods" />
            </BentoCard>

            <BentoCard className="h-[220px] sm:col-span-4 sm:row-start-3 sm:h-full" delay={0.16}>
              <div className="relative z-[2] flex h-full flex-col justify-between p-4">
                <p className="text-[12px] font-try font-black text-zinc-500">Least latency streaming</p>
                <p className="bg-gradient-to-br font-try from-violet-300 via-fuchsia-300 to-sky-300 bg-clip-text text-center text-6xl leading-none tracking-tight text-transparent sm:text-6xl">40ms
                </p>
                <p className="self-end text-right inline-flex items-center gap-1 font-try text-sm leading-5 text-zinc-500">
                  Locked to picture
                  <HugeiconsIcon icon={LockedIcon} size={16} strokeWidth={1.75} className="mt-0.5" />
                </p>
              </div>
            </BentoCard>
          </div>

          {/* <p className="mx-auto mt-12 max-w-2xl text-center text-xs leading-6 text-zinc-600">
            Microphone permission is only so BlackHole can be opened as a virtual input.{" "}
            <a className="underline decoration-white/20 hover:text-zinc-400" href="/terms">
              Terms of use
            </a>
            {" · "}
            <a className="underline decoration-white/20 hover:text-zinc-400" href="/privacy">
              Privacy
            </a>
            {" · "}
            <a className="underline decoration-white/20 hover:text-zinc-400" href="/license">
              License
            </a>
          </p> */}
        </div>
      </section>

      <SiteFooter />
    </div>
  )
}
