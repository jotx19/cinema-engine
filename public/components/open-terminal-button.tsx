"use client"

import { HugeiconsIcon } from "@hugeicons/react"
import { AppleIcon, ComputerTerminal01Icon } from "@hugeicons/core-free-icons"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"

function downloadInstaller() {
  const link = document.createElement("a")
  link.href = "/install-cinema-engine.command"
  link.download = "install-cinema-engine.command"
  document.body.appendChild(link)
  link.click()
  link.remove()
  toast.success("Open the downloaded file to install in Terminal")
}

const buttonClass = "h-11 gap-2 rounded-xl px-5 text-sm"

export function OpenTerminalButton() {
  return (
    <div className="mt-5 flex flex-wrap items-center justify-center gap-3">
      <div className="hidden md:block">
      <Button type="button" onClick={downloadInstaller} className={buttonClass}>
        <HugeiconsIcon icon={ComputerTerminal01Icon} size={16} strokeWidth={1.75} />
        Install in Terminal
      </Button>
      </div>
      <Button type="button" disabled className={buttonClass}>
        <HugeiconsIcon icon={AppleIcon} size={16} strokeWidth={1.75} className="fill-current" />
        Download for Mac
      </Button>
    </div>
  )
}
