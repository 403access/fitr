import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  main: [
    'intro',
    {
      type: 'category',
      label: 'Product',
      collapsed: false,
      items: [
        'product/vision',
        'product/features',
        'product/progression',
        'product/design',
      ],
    },
    {
      type: 'category',
      label: 'Technology',
      collapsed: false,
      items: [
        'technology/architecture',
        'technology/data-model',
        'technology/api',
        'technology/ios-app',
        'technology/animations',
        'technology/development',
        'technology/deployment',
      ],
    },
    'roadmap',
    'decisions',
    'changelog',
  ],
};

export default sidebars;
