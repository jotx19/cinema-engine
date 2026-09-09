import Image from "next/image"
import Link from "next/link"

import { cn } from "@/lib/utils"

export function SiteLogo({
  className,
  size = 28,
  withWordmark = false,
}: {
  className?: string
  size?: number
  withWordmark?: boolean
}) {
  return (
    <Link
      href="/"
      className={cn("inline-flex items-center gap-2", className)}
      aria-label="cinema-engine home"
    >
      <Image
        src="/brand/logo.png"
        alt=""
        width={size}
        height={size}
        className="rounded-md"
        priority
      />
      {withWordmark ? (
        <span className="text-[11px] tracking-tight text-white">cinema-engine</span>
      ) : null}
    </Link>
  )
}
