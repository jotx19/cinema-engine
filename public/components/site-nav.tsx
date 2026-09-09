"use client";
import { SiteLogo } from "@/components/site-logo";
import { Button } from "@/components/ui/button";
import { Github01Icon, AppleIcon } from "@hugeicons/core-free-icons";
import { HugeiconsIcon } from "@hugeicons/react";

const buttonClass = "h-11 gap-2 rounded-xl px-3 text-sm";

export function SiteNav() {
  return (
    <header className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center p-4 sm:p-5">
      <div className="pointer-events-auto relative flex h-15 w-[70vw] min-w-[min(100%,30rem)] max-w-5xl items-center justify-between gap-3 rounded-xl bg-white/8 px-3 shadow-[0_8px_32px_rgba(0,0,0,0.35)] backdrop-blur-xl sm:h-18 sm:px-4">
        <SiteLogo size={48} />

        <div className="flex shrink-0 items-center gap-1.5">
          <Button
            nativeButton={false}
            className={buttonClass}
            render={
              <a
                href="https://github.com/jotx19/cinema-engine"
                target="_blank"
                rel="noreferrer"
              />
            }
          >
            <HugeiconsIcon
              icon={Github01Icon}
              size={18}
              strokeWidth={1.75}
              className="fill-current"
            />
          </Button>
          <Button type="button" disabled className={buttonClass}>
            <HugeiconsIcon
              icon={AppleIcon}
              size={16}
              strokeWidth={1.75}
              className="fill-current"
            />
            <p className="hidden md:block">
              Download for Mac
            </p>
          </Button>
        </div>
      </div>
    </header>
  );
}
