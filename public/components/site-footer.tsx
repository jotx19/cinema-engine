import Link from "next/link"

export function SiteFooter() {
  return (
    <footer className="mt-12 flex flex-wrap items-center justify-between gap-4 border-t border-[#efefef] pt-6 text-[13px] text-[#6f6f6f]">
      <span>© {new Date().getFullYear()} Cinema Engine</span>
      <nav className="flex flex-wrap gap-5">
        <Link href="/install" className="text-inherit no-underline hover:text-[#111]">
          Install
        </Link>
        <Link href="/privacy" className="text-inherit no-underline hover:text-[#111]">
          Privacy
        </Link>
        <Link href="/terms" className="text-inherit no-underline hover:text-[#111]">
          Terms
        </Link>
        <Link href="/license" className="text-inherit no-underline hover:text-[#111]">
          License
        </Link>
        <a
          href="https://github.com/jotx19/cinema-engine"
          className="text-inherit no-underline hover:text-[#111]"
        >
          GitHub
        </a>
      </nav>
    </footer>
  )
}
