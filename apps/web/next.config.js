/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: ["@mindfield/logic", "@mindfield/ui"],
  output: "standalone",
};

module.exports = nextConfig;
