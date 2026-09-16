"use client"

import { Copy01Icon, Tick02Icon } from "@hugeicons/core-free-icons"
import { HugeiconsIcon } from "@hugeicons/react"
import { useState } from "react"
import { toast } from "sonner"

import { curlInstall } from "@/lib/commands"

export function InstallCommand() {
  const [copied, setCopied] = useState(false)

  async function copyInstall() {
    await navigator.clipboard.writeText(curlInstall)
    setCopied(true)
    toast.success("Copied")
    window.setTimeout(() => setCopied(false), 1600)
  }

  return (
    <div className="flex w-full items-center gap-3 overflow-hidden rounded-[20px] border border-[#efefef] bg-white px-4 py-4">
      <span className="shrink-0 select-none font-mono text-[13px] text-[#b0b0b0]">$</span>
      <div className="min-w-0 flex-1 overflow-x-auto overscroll-x-contain [-webkit-overflow-scrolling:touch]">
        <code className="block w-max max-w-none font-mono text-[13px] leading-6 whitespace-nowrap text-[#6f6f6f]">
          <span className="text-[#111]">curl</span>{" "}
          <span className="text-[#9a9a9a]">-fsSL</span>{" "}
          <span className="text-[#111]">
            https://raw.githubusercontent.com/jotx19/cinema-engine/main/install.sh
          </span>{" "}
          <span className="text-[#b0b0b0]">|</span> <span className="text-[#111]">bash</span>
        </code>
      </div>
      <button
        type="button"
        onClick={copyInstall}
        className={`inline-flex size-8 shrink-0 items-center justify-center rounded-xl border transition-colors ${
          copied
            ? "border-[#111]/15 text-[#111]"
            : "border-[#efefef] text-[#6f6f6f] hover:border-[#e0e0e0] hover:text-[#111]"
        }`}
        aria-label={copied ? "Copied" : "Copy"}
      >
        <HugeiconsIcon
          icon={copied ? Tick02Icon : Copy01Icon}
          size={14}
          strokeWidth={1.75}
        />
      </button>
    </div>
  )
}
