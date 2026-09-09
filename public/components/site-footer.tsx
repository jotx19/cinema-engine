import Image from "next/image"
import Link from "next/link"

export function SiteFooter() {
  return (
    <footer className="border-t border-white/10 bg-black">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-8 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-white/70 hover:text-white">
          <Image src="/brand/logo.png" alt="" width={20} height={20} className="rounded-sm" />
          Cinengine
        </Link>
        <div className="flex flex-wrap gap-5 text-sm text-white/40">
          <Link href="/terms" className="hover:text-white">
            Terms of use
          </Link>
          <Link href="/privacy" className="hover:text-white">
            Privacy
          </Link>
          <Link href="/license" className="hover:text-white">
            License
          </Link>
          <a href="https://github.com/jotx19/cinema-engine" className="hover:text-white">
            GitHub
          </a>
        </div>
      </div>
    </footer>
  )
}
