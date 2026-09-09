import type { ReactNode } from "react"
import type { Metadata } from "next"

import { Toaster } from "@/components/ui/sonner"

import "./globals.css"

export const metadata: Metadata = {
  title: "Cinema Engine",
  description:
    "Cinema sound for Stremio or any other Mac audio output. Terminal mixer for AirPods.",
  icons: {
    icon: [{ url: "/brand/logo.png", type: "image/png" }],
    apple: [{ url: "/brand/logo.png" }],
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode
}>) {
  return (
    <html lang="en" className="dark h-full antialiased">
      <body className="min-h-full bg-black font-sans text-zinc-100">{children}
        <Toaster />
      </body>
    </html>
  )
}
