"use client"

import Image from "next/image"
import Link from "next/link"
import { toast } from "sonner"

function downloadMacApp() {
  const link = document.createElement("a")
  link.href = "/CinemaEngine-macOS.zip"
  link.download = "CinemaEngine-macOS.zip"
  document.body.appendChild(link)
  link.click()
  link.remove()
  toast.success("Downloaded. Unzip and open Cinema Engine.app")
}

function DownloadButton({ className = "" }: { className?: string }) {
  return (
    <button
      type="button"
      onClick={downloadMacApp}
      className={`inline-flex shrink-0 items-center gap-1.5 rounded-xl bg-[#111] font-medium tracking-[-0.015em] text-white transition-[opacity,transform] hover:opacity-[0.88] active:scale-[0.98] ${className}`}
    >
      <svg
        width="13"
        height="13"
        viewBox="0 0 24 24"
        fill="currentColor"
        aria-hidden="true"
        className="-mt-px"
      >
        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
      </svg>
      Download for Mac
    </button>
  )
}

export function SiteNav() {
  return (
    <div className="absolute inset-x-0 top-0 z-20 px-4 pt-5 sm:px-8 sm:pt-7">
      {/* Mobile */}
      <div className="flex items-center justify-between gap-3 sm:hidden">
        <Link
          href="/"
          className="inline-flex min-w-0 items-center gap-1.5 tracking-[-0.02em] text-[#111] no-underline"
        >
          <Image
            src="/brand/logo.png"
            alt=""
            width={20}
            height={20}
            className="h-5 w-5 shrink-0 rounded-[4px]"
            priority
          />
          <span className="truncate text-[14px]">Cinema Engine</span>
        </Link>
        <DownloadButton className="h-8 gap-1.5 px-3 text-[12px]" />
      </div>

      {/* Desktop */}
      <div className="hidden items-center justify-between gap-4 sm:flex">
        <div className="flex items-center gap-x-3">
          <Link
            href="/"
            className="inline-flex items-center gap-1.5 tracking-[-0.02em] text-[#111] no-underline"
          >
            <Image
              src="/brand/logo.png"
              alt=""
              width={20}
              height={20}
              className="h-5 w-5 shrink-0 rounded-[4px]"
              priority
            />
            <span className="text-[15px]">Cinema Engine</span>
          </Link>
          <span className="text-[13px] text-[#6f6f6f]">macOS</span>
          <a
            href="https://github.com/jotx19/cinema-engine"
            target="_blank"
            rel="noreferrer"
            className="inline-flex h-7 items-center gap-1.5 rounded-full bg-white px-3 text-[13px] tracking-[-0.01em] text-[#111] no-underline transition-transform hover:-translate-y-px active:scale-[0.98]"
          >
            GitHub
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
              <path
                d="M2.5 6h7M6.5 3 9.5 6l-3 3"
                stroke="currentColor"
                strokeWidth="1.4"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </a>
        </div>
        <DownloadButton className="h-9 gap-2 px-3.5 text-[13px]" />
      </div>
    </div>
  )
}
