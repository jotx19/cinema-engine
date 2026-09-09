"use client"

export function MediaFill({
  src,
  type,
  poster,
  alt = "",
}: {
  src: string
  type: "image" | "gif" | "video"
  poster?: string
  alt?: string
}) {
  if (type === "video") {
    return (
      <video
        className="absolute inset-0 h-full w-full object-cover"
        src={src}
        poster={poster}
        autoPlay
        muted
        loop
        playsInline
      />
    )
  }

  return (
    <img
      src={src}
      alt={alt}
      className="absolute inset-0 h-full w-full object-cover"
    />
  )
}
