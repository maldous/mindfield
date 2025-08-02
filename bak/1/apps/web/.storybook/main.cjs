const path = require("path");

const config = {
  stories: [
    "../src/**/*.stories.@(js|jsx|mjs|ts|tsx)",
    "../../../core/ui/src/**/*.stories.@(js|jsx|mjs|ts|tsx)",
  ],
  addons: ["@storybook/addon-links", "@storybook/addon-docs"],
  framework: {
    name: "@storybook/nextjs",
    options: {},
  },
  docs: {
    autodocs: "tag",
  },
  webpackFinal: async (config) => {
    config.resolve = config.resolve || {};
    config.resolve.alias = {
      ...config.resolve.alias,
      "react-native$": "react-native-web",
      "@mindfield/ui": path.resolve(__dirname, "../../../core/ui/src"),
      "@mindfield/logic": path.resolve(__dirname, "../../../core/logic/src"),
    };

    config.resolve.modules = [
      ...(config.resolve.modules || []),
      path.resolve(__dirname, "../../../packages"),
      path.resolve(__dirname, "../../../node_modules"),
    ];

    return config;
  },
};

module.exports = config;
