import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import {themes as prismThemes} from 'prism-react-renderer';

const repository = process.env.GITHUB_REPOSITORY ?? 'YOUR_GITHUB_USERNAME/fitr';
const [owner, project] = repository.split('/');
const siteUrl = process.env.DOCUSAURUS_URL ?? `https://${owner}.github.io`;
const baseUrl = process.env.DOCUSAURUS_BASE_URL ?? `/${project}/docs/`;
const repositoryUrl = `https://github.com/${owner}/${project}`;
const websiteUrl = `https://${owner}.github.io/${project}/`;

const config: Config = {
  title: 'Fitr',
  tagline: 'Train on your rhythm.',
  favicon: 'img/favicon.png',

  url: siteUrl,
  baseUrl,
  organizationName: owner,
  projectName: project,
  trailingSlash: false,
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl: `${repositoryUrl}/tree/main/apps/docs/`,
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/og.png',
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'Fitr',
      logo: {
        alt: 'Fitr',
        src: 'img/logo.svg',
      },
      items: [
        {to: '/product/vision', label: 'Product', position: 'left'},
        {to: '/technology/architecture', label: 'Technology', position: 'left'},
        {to: '/roadmap', label: 'Roadmap', position: 'left'},
        {href: websiteUrl, label: 'Website', position: 'right'},
        {href: repositoryUrl, label: 'GitHub', position: 'right'},
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Product',
          items: [
            {label: 'Vision', to: '/product/vision'},
            {label: 'Features', to: '/product/features'},
            {label: 'Progression model', to: '/product/progression'},
          ],
        },
        {
          title: 'Build',
          items: [
            {label: 'Architecture', to: '/technology/architecture'},
            {label: 'API reference', to: '/technology/api'},
            {label: 'Development', to: '/technology/development'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'Roadmap', to: '/roadmap'},
            {label: 'Decisions', to: '/decisions'},
            {label: 'Website', href: websiteUrl},
          ],
        },
      ],
      copyright: `Fitr · ${new Date().getFullYear()} · Built with SwiftUI, Bun and SQLite.`,
    },
    prism: {
      theme: prismThemes.dracula,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'swift', 'sql', 'json'],
    },
    docs: {
      sidebar: {
        hideable: true,
        autoCollapseCategories: false,
      },
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
