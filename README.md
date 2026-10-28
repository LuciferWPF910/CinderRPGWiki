# CinderRPG Wiki – Landing Page

This repo is the landing page for **https://wiki.bighatstudios.com/**.

The wiki itself runs on MediaWiki. All articles, guides, images and patch notes
live there and are edited on the wiki, not in this repo. This page sits in front
of it and pulls search, stats and page lists live from the wiki's API.

## Files

| Path | Purpose |
|---|---|
| `index.html` | The landing page |
| `cinder-wiki/css/global.css` | Shared header, nav, buttons, footer, modals |
| `cinder-wiki/css/home.css` | Hero title and the six cards |
| `cinder-wiki/css/landing.css` | Search, stats, Explore tabs, quick links |
| `cinder-wiki/js/landing.js` | Search suggestions, stats, page lists, menu, modals, title animation |
| `cinder-wiki/images/` | Logo and favicon |

## Editing tips

- **Card and menu links** use `data-page="Page Title"`, which points at that wiki page.
- **Popular tab:** edit the wiki page `Project:Landing/Popular`. It's a bulleted list of
  links, shown in the order written. No code change needed.
- **Short URLs:** if the wiki moves to `/wiki/Page`, change `articlePath` at the top of
  `cinder-wiki/js/landing.js`.
- After changing CSS or JS, bump the `?v=` number in `index.html` so browsers fetch the new version.

## Deploying

The server serves this repo from `/var/www/cinder-landing`. After merging to main:

```bash
cd /var/www/cinder-landing && sudo git pull
```

Please push updates to **FrostsBranch** before merging to main.
Use the Discord to report bugs, spelling mistakes or errors.
