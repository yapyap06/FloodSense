/** @type {import('next').NextConfig} */
const nextConfig = {
  // NOTE: Add `output: "export"` only when building for Firebase Hosting production deploy
  // For dev, do NOT use static export (it breaks dynamic routes and hot reload)
  images: { unoptimized: true },
};

module.exports = nextConfig;
