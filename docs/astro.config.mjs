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
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/revvy02/rodeo' },
			],
			sidebar: [
				{ label: 'Getting started', link: '/' },
				{ label: 'CLI reference', link: '/cli/' },
				{ label: 'Luau API', items: [{ autogenerate: { directory: 'api' } }] },
				{ label: '@rodeo runtime', items: [{ autogenerate: { directory: 'runtime' } }] },
			],
		}),
	],
});
