import type { ReactNode } from "react"
import type { Metadata } from "next"

import { Toaster } from "@/components/ui/sonner"

import "./globals.css"

export const metadata: Metadata = {
  title: "Cinema Engine",
  description:
    "Theatre sound for your streaming app and headphones. Menu bar cinema mix for AirPods.",
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
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full bg-[#f5f5f5] font-sans text-[#111]">{children}
        <Toaster />
      </body>
    </html>
  )
}
