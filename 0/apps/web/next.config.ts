import { NextConfig } from "next";

const nextConfig: NextConfig = {
    reactStrictMode: true,
    transpilePackages: ["@mindfield/logic", "@mindfield/ui"],
    output: "standalone",
};

export default nextConfig;
