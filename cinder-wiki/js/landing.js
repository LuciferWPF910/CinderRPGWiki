/**
 * CinderRPG Wiki - Landing page
 * Talks to the MediaWiki API on the same domain for search, stats and page lists.
 */
(function () {
    'use strict';

    /* ================= CONFIG ================= */
    const CONFIG = {
        // Where wiki pages live. Change to '/wiki/' once short URLs are set up.
        articlePath: '/index.php/',
        api: '/api.php',
        // Staff-curated "Popular" list: a normal wiki page containing a bulleted list of links.
        // "Project:" works whatever the wiki's name is.
        popularPage: 'Project:Landing/Popular',
        listSize: 8,
        suggestions: 8,
    };

    /* ================= HELPERS ================= */
    const $ = (sel, root = document) => root.querySelector(sel);
    const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

    function pageUrl(title) {
        return CONFIG.articlePath + encodeURIComponent(title.replace(/ /g, '_')).replace(/%2F/g, '/').replace(/%3A/g, ':');
    }

    function searchUrl(query) {
        return '/index.php?title=Special:Search&fulltext=1&search=' + encodeURIComponent(query);
    }

    async function api(params, signal) {
        const qs = new URLSearchParams({ format: 'json', formatversion: '2', ...params });
        const res = await fetch(CONFIG.api + '?' + qs.toString(), { credentials: 'same-origin', signal });
        if (!res.ok) throw new Error('API ' + res.status);
        const data = await res.json();
        if (data.error) throw new Error(data.error.info || 'API error');
        return data;
    }

    function el(tag, attrs = {}, children = []) {
        const node = document.createElement(tag);
        for (const [k, v] of Object.entries(attrs)) {
            if (v == null) continue;
            if (k === 'class') node.className = v;
            else if (k === 'text') node.textContent = v;
            else node.setAttribute(k, v);
        }
        for (const c of [].concat(children)) if (c) node.append(c);
        return node;
    }

    function timeAgo(iso) {
        const secs = Math.max(1, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
        const units = [['year', 31536000], ['month', 2592000], ['week', 604800], ['day', 86400], ['hour', 3600], ['minute', 60]];
        for (const [name, size] of units) {
            const n = Math.floor(secs / size);
            if (n >= 1) return n + ' ' + name + (n > 1 ? 's' : '') + ' ago';
        }
        return 'just now';
    }

    const fmt = new Intl.NumberFormat('en-GB');

    /* ================= LINKS ================= */
    function wireLinks() {
        $$('[data-page]').forEach(a => { a.href = pageUrl(a.dataset.page); });
        const year = $('#year');
        if (year) year.textContent = new Date().getFullYear();
    }

    /* ================= ACCOUNT ================= */
    async function loadAccount() {
        try {
            const data = await api({ action: 'query', meta: 'userinfo' });
            const user = data.query.userinfo;
            if (!user || user.anon) {
                const back = '&returnto=' + encodeURIComponent('Main_Page');
                $('#account-link').href = '/index.php?title=Special:UserLogin' + back;
                return;
            }
            $('#account-name').textContent = user.name;
            $('#account-link').href = pageUrl('User:' + user.name);
            const cta = $('#contribute-primary');
            if (cta) {
                cta.textContent = 'Create a page';
                cta.href = pageUrl('Special:WantedPages');
            }
        } catch (_) { /* leave the static "Log in" link */ }
    }

    /* ================= STATS ================= */
    async function loadStats() {
        try {
            const data = await api({ action: 'query', meta: 'siteinfo', siprop: 'statistics' });
            const s = data.query.statistics;
            $$('[data-stat]').forEach(node => {
                const v = s[node.dataset.stat];
                if (typeof v === 'number') node.textContent = fmt.format(v);
            });
            $('#wiki-stats').classList.add('is-loaded');
        } catch (_) {
            $('#wiki-stats').hidden = true;
        }
    }

    /* ================= SEARCH ================= */
    function initSearch() {
        const form = $('#hero-search');
        const input = $('#hero-search-input');
        const list = $('#hero-search-results');
        if (!form || !input || !list) return;

        let items = [];
        let active = -1;
        let timer = null;
        let controller = null;

        function close() {
            list.hidden = true;
            list.innerHTML = '';
            items = [];
            active = -1;
            input.setAttribute('aria-expanded', 'false');
            input.removeAttribute('aria-activedescendant');
        }

        function setActive(i) {
            const opts = $$('.search-result', list);
            opts.forEach(o => o.classList.remove('is-active'));
            active = i;
            if (i >= 0 && opts[i]) {
                opts[i].classList.add('is-active');
                input.setAttribute('aria-activedescendant', opts[i].id);
                opts[i].scrollIntoView({ block: 'nearest' });
            } else {
                input.removeAttribute('aria-activedescendant');
            }
        }

        function render(query, pages) {
            list.innerHTML = '';
            items = pages.map(p => ({ href: pageUrl(p.title), title: p.title, desc: p.desc, thumb: p.thumb }));
            items.push({ href: searchUrl(query), title: 'Search all pages for “' + query + '”', full: true });

            items.forEach((item, i) => {
                const thumb = item.full
                    ? el('span', { class: 'sr-thumb sr-thumb--icon' }, el('i', { class: 'ph ph-magnifying-glass', 'aria-hidden': 'true' }))
                    : item.thumb
                        ? el('img', { class: 'sr-thumb', src: item.thumb, alt: '', loading: 'lazy' })
                        : el('span', { class: 'sr-thumb sr-thumb--icon' }, el('i', { class: 'ph ph-file-text', 'aria-hidden': 'true' }));
                const text = el('span', { class: 'sr-text' }, [
                    el('span', { class: 'sr-title', text: item.title }),
                    item.desc ? el('span', { class: 'sr-desc', text: item.desc }) : null,
                ]);
                const a = el('a', { href: item.href, tabindex: '-1' }, [thumb, text]);
                const li = el('li', {
                    class: 'search-result' + (item.full ? ' search-result--full' : ''),
                    id: 'sr-' + i, role: 'option',
                }, a);
                li.addEventListener('mouseenter', () => setActive(i));
                list.append(li);
            });

            list.hidden = false;
            input.setAttribute('aria-expanded', 'true');
            setActive(-1);
        }

        async function suggest(query) {
            if (controller) controller.abort();
            controller = new AbortController();
            try {
                const data = await api({
                    action: 'query',
                    generator: 'prefixsearch',
                    gpssearch: query,
                    gpslimit: String(CONFIG.suggestions),
                    gpsnamespace: '0',
                    prop: 'pageimages|extracts',
                    piprop: 'thumbnail',
                    pithumbsize: '80',
                    pilimit: String(CONFIG.suggestions),
                    exintro: '1',
                    explaintext: '1',
                    exchars: '90',
                    exlimit: String(CONFIG.suggestions),
                    redirects: '1',
                }, controller.signal);
                const pages = (data.query && data.query.pages ? data.query.pages : [])
                    .sort((a, b) => (a.index || 0) - (b.index || 0))
                    .map(p => ({
                        title: p.title,
                        desc: p.extract ? p.extract.replace(/\s+/g, ' ').trim() : '',
                        thumb: p.thumbnail ? p.thumbnail.source : null,
                    }));
                if (input.value.trim() === query) render(query, pages);
            } catch (err) {
                if (err.name !== 'AbortError' && input.value.trim() === query) render(query, []);
            }
        }

        input.addEventListener('input', () => {
            const q = input.value.trim();
            clearTimeout(timer);
            if (!q) { close(); return; }
            timer = setTimeout(() => suggest(q), 140);
        });

        input.addEventListener('keydown', e => {
            if (list.hidden) return;
            if (e.key === 'ArrowDown') { e.preventDefault(); setActive((active + 1) % items.length); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active <= 0 ? items.length - 1 : active - 1); }
            else if (e.key === 'Escape') { close(); }
            else if (e.key === 'Enter' && active >= 0) { e.preventDefault(); window.location.href = items[active].href; }
        });

        input.addEventListener('focus', () => { if (input.value.trim() && items.length) { list.hidden = false; input.setAttribute('aria-expanded', 'true'); } });
        document.addEventListener('click', e => { if (!form.contains(e.target)) close(); });

        // Enter with nothing selected: MediaWiki's "go" jumps straight to an exact match, otherwise shows results.
        form.addEventListener('submit', e => {
            if (!input.value.trim()) { e.preventDefault(); input.focus(); }
        });

        // Press "/" anywhere to jump to search.
        document.addEventListener('keydown', e => {
            const t = e.target;
            const typing = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable);
            if (e.key === '/' && !typing && !e.ctrlKey && !e.metaKey && !e.altKey) {
                e.preventDefault();
                input.focus();
                input.select();
            }
        });
    }

    /* ================= PAGE LISTS (tabs) ================= */
    const listCache = {};

    // Adds intro text and thumbnails to a list of titles in one request.
    async function enrich(titles) {
        if (!titles.length) return {};
        try {
            const data = await api({
                action: 'query',
                titles: titles.join('|'),
                prop: 'pageimages|extracts',
                piprop: 'thumbnail',
                pithumbsize: '96',
                pilimit: 'max',
                exintro: '1',
                explaintext: '1',
                exchars: '140',
                exlimit: String(Math.min(titles.length, 20)),
                redirects: '1',
            });
            const out = {};
            for (const p of (data.query.pages || [])) {
                out[p.title] = {
                    missing: !!p.missing,
                    desc: p.extract ? p.extract.replace(/\s+/g, ' ').trim() : '',
                    thumb: p.thumbnail ? p.thumbnail.source : null,
                };
            }
            // Map redirect sources onto their targets so lookups by the original title still work.
            for (const r of (data.query.redirects || [])) if (out[r.to]) out[r.from] = out[r.to];
            for (const n of (data.query.normalized || [])) if (out[n.to]) out[n.from] = out[n.to];
            return out;
        } catch (_) {
            return {};
        }
    }

    // Popular: staff-curated list on Project:Landing/Popular, falling back to the most linked-to pages.
    async function getPopular() {
        let entries = [];
        try {
            const data = await api({
                action: 'query', prop: 'revisions', titles: CONFIG.popularPage,
                rvprop: 'content', rvslots: 'main',
            });
            const page = data.query.pages[0];
            const text = page && !page.missing && page.revisions ? page.revisions[0].slots.main.content : '';
            const re = /\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]/g;
            let m;
            while ((m = re.exec(text)) && entries.length < CONFIG.listSize) {
                const title = m[1].trim().replace(/_/g, ' ');
                if (/^(category|file|image):/i.test(title)) continue;
                entries.push({ title, label: (m[2] || '').trim() || title });
            }
        } catch (_) { /* fall through */ }

        if (!entries.length) {
            try {
                const data = await api({ action: 'query', list: 'querypage', qppage: 'Mostlinked', qplimit: '30' });
                entries = (data.query.querypage.results || [])
                    .filter(r => r.ns === 0)
                    .slice(0, CONFIG.listSize)
                    .map(r => ({ title: r.title, label: r.title }));
            } catch (_) { /* nothing */ }
        }

        const info = await enrich(entries.map(e => e.title));
        return entries
            .filter(e => !(info[e.title] && info[e.title].missing))
            .map(e => ({ ...e, ...(info[e.title] || {}), meta: null }));
    }

    async function getRecent(type) {
        const data = await api({
            action: 'query', list: 'recentchanges',
            rcnamespace: '0', rctype: type, rcshow: '!bot',
            rcprop: 'title|timestamp|user', rclimit: '50',
        });
        const seen = new Set();
        const entries = [];
        for (const rc of data.query.recentchanges) {
            if (seen.has(rc.title)) continue;
            seen.add(rc.title);
            entries.push({
                title: rc.title, label: rc.title,
                meta: (type === 'new' ? 'Created ' : 'Edited ') + timeAgo(rc.timestamp) + (rc.user ? ' by ' + rc.user : ''),
            });
            if (entries.length >= CONFIG.listSize) break;
        }
        const info = await enrich(entries.map(e => e.title));
        return entries
            .filter(e => !(info[e.title] && info[e.title].missing))
            .map(e => ({ ...e, desc: (info[e.title] || {}).desc, thumb: (info[e.title] || {}).thumb }));
    }

    const loaders = {
        popular: getPopular,
        recent: () => getRecent('edit|new'),
        new: () => getRecent('new'),
    };

    const emptyText = {
        popular: 'No pages yet. Once articles link to each other, the most important ones show up here. Staff can also curate this list on the Project:Landing/Popular page.',
        recent: 'No edits yet. Be the first to write something!',
        new: 'No new pages yet.',
    };

    function renderList(tab, entries) {
        const list = $('#page-list');
        list.innerHTML = '';
        list.setAttribute('aria-busy', 'false');

        if (!entries.length) {
            list.append(el('li', { class: 'page-empty' }, [
                el('i', { class: 'ph ph-feather', 'aria-hidden': 'true' }),
                el('span', { text: emptyText[tab] }),
            ]));
            return;
        }

        entries.forEach((e, i) => {
            const thumb = e.thumb
                ? el('img', { class: 'pl-thumb', src: e.thumb, alt: '', loading: 'lazy' })
                : el('span', { class: 'pl-thumb pl-thumb--icon' }, el('i', { class: 'ra ra-scroll-unfurled', 'aria-hidden': 'true' }));
            const body = el('span', { class: 'pl-body' }, [
                el('span', { class: 'pl-title', text: e.label }),
                e.desc ? el('span', { class: 'pl-desc', text: e.desc }) : null,
                e.meta ? el('span', { class: 'pl-meta', text: e.meta }) : null,
            ]);
            const item = el('li', { class: 'page-item', style: '--i:' + i },
                el('a', { href: pageUrl(e.title) }, [
                    tab === 'popular' ? el('span', { class: 'pl-rank', text: String(i + 1) }) : null,
                    thumb, body,
                    el('i', { class: 'ph ph-caret-right pl-arrow', 'aria-hidden': 'true' }),
                ]));
            list.append(item);
        });
    }

    async function showTab(tab) {
        const list = $('#page-list');
        $$('.tab').forEach(t => {
            const on = t.dataset.tab === tab;
            t.classList.toggle('is-active', on);
            t.setAttribute('aria-selected', on ? 'true' : 'false');
            t.tabIndex = on ? 0 : -1;
        });
        $('#tabpanel').setAttribute('aria-labelledby', 'tab-' + tab);

        if (listCache[tab]) { renderList(tab, listCache[tab]); return; }

        list.setAttribute('aria-busy', 'true');
        list.innerHTML = '<li class="page-skeleton"></li>'.repeat(4);
        try {
            const entries = await loaders[tab]();
            listCache[tab] = entries;
            if ($('.tab.is-active').dataset.tab === tab) renderList(tab, entries);
        } catch (_) {
            list.innerHTML = '';
            list.append(el('li', { class: 'page-empty' }, [
                el('i', { class: 'ph ph-plugs', 'aria-hidden': 'true' }),
                el('span', { text: 'Couldn’t reach the wiki right now. Try refreshing.' }),
            ]));
        }
    }

    function initTabs() {
        const tabs = $$('.tab');
        tabs.forEach((t, i) => {
            t.addEventListener('click', () => showTab(t.dataset.tab));
            t.addEventListener('keydown', e => {
                if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
                const next = tabs[(i + (e.key === 'ArrowRight' ? 1 : tabs.length - 1)) % tabs.length];
                next.focus();
                showTab(next.dataset.tab);
            });
        });
        showTab('popular');
    }

    /* ================= NAV (mobile) ================= */
    function initNav() {
        const btn = $('.nav-toggle');
        const nav = $('.nav');
        if (!btn || !nav) return;

        const closeAll = () => {
            nav.classList.remove('open');
            document.body.classList.remove('nav-open');
            btn.setAttribute('aria-expanded', 'false');
            $$('.has-dropdown').forEach(d => d.classList.remove('touch-open'));
        };

        btn.addEventListener('click', e => {
            e.stopPropagation();
            const open = !nav.classList.contains('open');
            nav.classList.toggle('open', open);
            document.body.classList.toggle('nav-open', open);
            btn.setAttribute('aria-expanded', String(open));
        });

        $$('.has-dropdown').forEach(dd => {
            dd.querySelector('.nav-link').addEventListener('click', e => {
                e.preventDefault();
                e.stopPropagation();
                $$('.has-dropdown').forEach(o => { if (o !== dd) o.classList.remove('touch-open'); });
                dd.classList.toggle('touch-open');
            });
        });

        document.addEventListener('click', e => {
            if (nav.classList.contains('open') && !nav.contains(e.target) && !btn.contains(e.target)) closeAll();
            if (!e.target.closest('.has-dropdown')) $$('.has-dropdown').forEach(d => d.classList.remove('touch-open'));
        });
        document.addEventListener('keydown', e => { if (e.key === 'Escape') closeAll(); });
    }

    /* ================= MODALS ================= */
    function initModals() {
        $$('.open-modal').forEach(btn => {
            const modal = document.getElementById(btn.dataset.modal);
            if (!modal) return;
            btn.addEventListener('click', e => {
                e.preventDefault();
                modal.style.display = 'flex';
                void modal.offsetHeight;
                modal.classList.add('modal-open');
                document.body.style.overflow = 'hidden';
            });
        });

        $$('.modal').forEach(modal => {
            const close = () => {
                modal.classList.remove('modal-open');
                document.body.style.overflow = '';
                setTimeout(() => { modal.style.display = 'none'; }, 300);
            };
            modal.querySelector('.modal-close')?.addEventListener('click', close);
            modal.querySelector('.modal-overlay')?.addEventListener('click', close);
            document.addEventListener('keydown', e => { if (e.key === 'Escape' && modal.style.display === 'flex') close(); });
        });
    }

    /* ================= TITLE ANIMATION ================= */
    function initTitleAnimation() {
        const title = document.getElementById('arcane-title');
        if (!title) return;
        const canvas = title.querySelector('.magic-particles');
        const textSpan = title.querySelector('.arcane-text');
        if (!canvas || !textSpan) return;

        // Split text into letters (also used by the CSS float animation)
        const text = textSpan.textContent;
        textSpan.innerHTML = '';
        text.split('').forEach(ch => {
            textSpan.append(el('span', { class: 'arcane-letter', text: ch === ' ' ? ' ' : ch }));
        });
        const letters = textSpan.querySelectorAll('.arcane-letter');

        const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        if (typeof gsap === 'undefined' || reduceMotion) {
            canvas.style.display = 'none';
            return;
        }

        const ctx = canvas.getContext('2d');
        const particles = Array.from({ length: 50 }, () => {
            const p = {
                reset() {
                    this.x = Math.random() * canvas.width;
                    this.y = Math.random() * canvas.height;
                    this.vx = (Math.random() - 0.5) * 1.5;
                    this.vy = (Math.random() - 0.5) * 1.5;
                    this.size = Math.random() * 3 + 1;
                    this.opacity = Math.random() * 0.5 + 0.3;
                    this.hue = Math.random() * 15 + 40;
                },
            };
            p.reset();
            return p;
        });

        let animating = false;
        function frame() {
            if (!animating) return;
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            for (const p of particles) {
                p.x += p.vx; p.y += p.vy;
                if (p.x < 0) p.x = canvas.width; if (p.x > canvas.width) p.x = 0;
                if (p.y < 0) p.y = canvas.height; if (p.y > canvas.height) p.y = 0;
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
                ctx.fillStyle = `hsla(${p.hue}, 80%, 70%, ${p.opacity})`;
                ctx.shadowBlur = 15;
                ctx.shadowColor = `hsla(${p.hue}, 80%, 70%, 0.8)`;
                ctx.fill();
            }
            requestAnimationFrame(frame);
        }

        gsap.set(canvas, { opacity: 0 });
        gsap.set(letters, { opacity: 0, y: 20, filter: 'blur(4px)' });

        gsap.timeline({ delay: 0.3, onStart: () => { animating = true; frame(); } })
            .to(canvas, { opacity: 1, duration: 1, ease: 'power2.out' })
            .to(letters, { opacity: 1, y: 0, filter: 'blur(0px)', duration: 0.6, stagger: 0.05, ease: 'power2.out' }, '-=0.3')
            .to(letters, { textShadow: '0 0 20px rgba(200,150,70,0.8), 0 0 40px rgba(180,130,50,0.5)', duration: 0.8, stagger: 0.05, ease: 'power2.inOut' }, '-=0.5')
            .to(letters, { textShadow: '0 0 15px rgba(191,160,111,0.5), 0 0 30px rgba(180,130,50,0.25)', duration: 1, ease: 'power2.out' })
            .to(canvas, {
                opacity: 0, duration: 1.5, ease: 'power2.inOut',
                onComplete: () => { animating = false; canvas.style.display = 'none'; },
            }, '-=0.5')
            .to(letters, {
                textShadow: '0 0 25px rgba(200,150,70,0.7), 0 0 50px rgba(180,130,50,0.4), 0 0 70px rgba(191,160,111,0.25)',
                duration: 2, ease: 'sine.inOut', repeat: -1, yoyo: true,
                stagger: { each: 0.1, from: 'start', repeat: -1 },
            });
    }

    /* ================= BOOT ================= */
    function boot() {
        wireLinks();
        initNav();
        initModals();
        initSearch();
        initTabs();
        loadStats();
        loadAccount();
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
    window.addEventListener('load', initTitleAnimation);
})();
