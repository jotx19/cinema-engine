"use client"

import { Check, Copy } from "lucide-react"
import { useState } from "react"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

export function CopyBlock({
  label,
  code,
  className,
}: {
  label: string
  code: string
  className?: string
}) {
  const [copied, setCopied] = useState(false)

  async function copy() {
    await navigator.clipboard.writeText(code)
    setCopied(true)
    toast.success("Copied")
    window.setTimeout(() => setCopied(false), 1600)
  }

  return (
    <div className={cn("overflow-hidden rounded-xl border border-white/10 bg-black/40", className)}>
      <div className="flex items-center justify-between border-b border-white/10 px-4 py-2">
        <p className="text-xs text-zinc-500">{label}</p>
        <Button size="sm" variant="ghost" onClick={copy} className="h-7 gap-1.5 text-zinc-300">
          {copied ? <Check className="size-3.5" /> : <Copy className="size-3.5" />}
          {copied ? "Copied" : "Copy"}
        </Button>
      </div>
      <pre className="overflow-x-auto p-4 font-mono text-[13px] leading-7 text-zinc-200">
        {code}
      </pre>
    </div>
  )
}
