"use client"

import { Check, Copy } from "lucide-react"
import { useState } from "react"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"
import { brewInstall, curlInstall, sourceInstall } from "@/lib/commands"
import { cn } from "@/lib/utils"

const tabs = [
  {
    id: "curl",
    label: "curl",
    command: curlInstall,
    highlight: "raw.githubusercontent.com/jotx19/cinema-engine/main/install.sh",
  },
  {
    id: "brew",
    label: "brew",
    command: brewInstall,
    highlight: "github.com/jotx19/cinema-engine",
  },
  {
    id: "source",
    label: "source",
    command: sourceInstall,
    highlight: "github.com/jotx19/cinema-engine.git",
  },
] as const

export function InstallCommand() {
  const [active, setActive] = useState<(typeof tabs)[number]["id"]>("curl")
  const [copied, setCopied] = useState(false)
  const tab = tabs.find((item) => item.id === active) ?? tabs[0]

  async function copy() {
    await navigator.clipboard.writeText(tab.command)
    setCopied(true)
    toast.success("Copied")
    window.setTimeout(() => setCopied(false), 1600)
  }

  const start = tab.command.indexOf(tab.highlight)
  const before = start >= 0 ? tab.command.slice(0, start) : tab.command
  const after = start >= 0 ? tab.command.slice(start + tab.highlight.length) : ""

  return (
    <div className="w-full overflow-hidden rounded-2xl border border-white/10 bg-[#0d0d0d]">
      <div className="flex items-center gap-6 border-b border-white/10 px-5">
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setActive(item.id)}
            className={cn(
              "relative py-3 text-sm transition-colors",
              active === item.id ? "text-white" : "text-zinc-500 hover:text-zinc-300"
            )}
          >
            {item.label}
            {active === item.id ? (
              <span className="absolute inset-x-0 -bottom-px h-px bg-white" />
            ) : null}
          </button>
        ))}
      </div>
      <div className="flex items-center gap-4 px-5 py-4">
        <p className="min-w-0 flex-1 overflow-x-auto font-mono text-sm leading-6 whitespace-nowrap">
          <span className="text-zinc-400">{before}</span>
          {start >= 0 ? <span className="text-white">{tab.highlight}</span> : null}
          <span className="text-zinc-400">{after}</span>
        </p>
        <Button
          size="icon-sm"
          variant="ghost"
          onClick={copy}
          aria-label="Copy command"
          className="size-8 shrink-0 text-zinc-500 hover:text-white"
        >
          {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
        </Button>
      </div>
    </div>
  )
}
