// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://revvy02.github.io',
	base: '/rodeo/',
	integrations: [
		starlight({
			title: 'rodeo',
			logo: {
				src: './src/assets/logo.png',
				replacesTitle: true,
			},
			customCss: ['./src/styles/custom.css'],
			components: {
				ThemeSelect: './src/components/EmptyThemeSelect.astro',
			},
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/revvy02/rodeo' },
			],
			sidebar: [
				{
					label: 'Getting started',
					items: [
						{ label: 'Installation', link: '/getting-started/installation/' },
						{ label: 'CLI usage', link: '/getting-started/cli-usage/' },
						{ label: 'Directives', link: '/getting-started/directives/' },
						{ label: 'Bundling', link: '/getting-started/bundling/' },
						{ label: 'Client usage', link: '/getting-started/client-usage/' },
						{ label: 'Runtime usage', link: '/getting-started/runtime-usage/' },
						{ label: 'Remote usage', link: '/getting-started/remote-usage/' },
					],
				},
				{ label: 'CLI reference', link: '/cli/' },
				{ label: 'Luau API', items: [{ autogenerate: { directory: 'api' } }] },
				{ label: '@rodeo runtime', items: [{ autogenerate: { directory: 'runtime' } }] },
			],
		}),
	],
});
