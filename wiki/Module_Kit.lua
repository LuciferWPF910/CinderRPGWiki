-- Module:Kit
-- The Cinder design kit: banners, boxes, callouts, columns, buttons, badges,
-- dividers, quotes, stat bars, steps, collapsible sections, tabs, infoboxes,
-- keys, coordinates, spoilers, Minecraft-coloured text and hover hints.
-- Every template in [[:Category:Design kit]] is a thin wrapper around one
-- function here. Live examples and code: [[Project:Design kit]].
--
-- Colours: components follow the page theme ({{Theme|frost}}), can take their
-- own theme (theme=frost) or any colour (colour=#55ccff). Themes are CSS
-- pages, Template:Theme/<name>.css; add a name to THEMES to add a theme.

local p = {}

-- ============================================================
--  Settings
-- ============================================================
local KIT_CSS      = 'Template:Kit/styles.css'
local THEME_PREFIX = 'Template:Theme/'
local SHOWCASE     = 'Project:Design kit'

-- Theme names (must match the Template:Theme/<name>.css pages).
local THEMES = {
	gold = true, ember = true, frost = true, verdant = true, arcane = true,
	blood = true, abyss = true, holy = true, shadow = true, plague = true,
}

local MAX_INFOBOX_ROWS = 40
local MAX_TABS         = 10
local MAX_COLUMNS      = 4
local MAX_KEYS         = 6
local TINT_ALPHA       = 0.16   -- background tint made from a custom colour

-- Rarity pills: colour and display name (same colours as the game).
local RARITIES = {
	common     = { '#AAAAAA', 'Common' },
	uncommon   = { '#55FF55', 'Uncommon' },
	rare       = { '#6688FF', 'Rare' },
	superrare  = { '#55FFFF', 'Super Rare' },
	legendary  = { '#FFFF55', 'Legendary' },
	mythic     = { '#FF5555', 'Mythic' },
	world      = { '#D98CFF', 'World Tier' },
	worldtier  = { '#D98CFF', 'World Tier' },
}

-- Minecraft colour codes and names.
local MC_COLOURS = {
	['0'] = '#000000', ['1'] = '#0000AA', ['2'] = '#00AA00', ['3'] = '#00AAAA',
	['4'] = '#AA0000', ['5'] = '#AA00AA', ['6'] = '#FFAA00', ['7'] = '#AAAAAA',
	['8'] = '#555555', ['9'] = '#5555FF', a = '#55FF55', b = '#55FFFF',
	c = '#FF5555', d = '#FF55FF', e = '#FFFF55', f = '#FFFFFF',
}
local MC_NAMES = {
	black = '0', dark_blue = '1', dark_green = '2', dark_aqua = '3', dark_red = '4',
	dark_purple = '5', gold = '6', gray = '7', grey = '7', dark_gray = '8', dark_grey = '8',
	blue = '9', green = 'a', aqua = 'b', red = 'c', light_purple = 'd', pink = 'd',
	yellow = 'e', white = 'f',
}
local SECTION_SIGN = '\194\167'  -- the section sign Minecraft uses for codes

-- Callout types: CSS class and symbol (HTML entities keep this file ASCII).
local CALLOUTS = {
	tip     = { 'tip', '&#10022;', 'Tip' },
	note    = { 'note', '&#9998;', 'Note' },
	info    = { 'info', '&#8505;', 'Info' },
	warning = { 'warning', '&#9888;', 'Warning' },
	danger  = { 'danger', '&#9760;', 'Danger' },
	lore    = { 'lore', '&#10086;', 'Lore' },
	success = { 'success', '&#10004;', 'Done' },
}

-- ============================================================
--  Helpers
-- ============================================================
local function trim(s)
	return s and mw.text.trim(s) or nil
end

local function has(s)
	return s ~= nil and s ~= ''
end

-- Template arguments (parent first, then #invoke arguments), blanks removed.
local function getArgs(frame)
	local args = {}
	local parent = frame:getParent()
	if parent then
		for k, v in pairs(parent.args) do
			args[k] = trim(v)
		end
	end
	for k, v in pairs(frame.args) do
		args[k] = trim(v)
	end
	for k, v in pairs(args) do
		if v == '' then
			args[k] = nil
		end
	end
	return args
end

local function yes(v)
	v = v and string.lower(v) or ''
	return v == 'yes' or v == 'y' or v == 'true' or v == '1' or v == 'on'
end

local function key(v)
	return v and string.lower((string.gsub(v, '[%s_%-]', ''))) or ''
end

local function styles(frame)
	local ok, tag = pcall(function ()
		return frame:extensionTag('templatestyles', '', { src = KIT_CSS })
	end)
	return ok and tag or ''
end

local function errorText(msg)
	return '<strong class="error">' .. mw.text.nowiki(msg) .. ' See [[' .. SHOWCASE .. ']].</strong>'
end

-- "#abc" or "#aabbcc" -> "#aabbcc", anything else -> nil.
local function hex(c)
	if type(c) ~= 'string' then
		return nil
	end
	c = mw.text.trim(c)
	if string.sub(c, 1, 1) ~= '#' then
		c = '#' .. c
	end
	if string.match(c, '^#%x%x%x%x%x%x$') then
		return string.upper(c)
	end
	if string.match(c, '^#%x%x%x$') then
		local r, g, b = string.sub(c, 2, 2), string.sub(c, 3, 3), string.sub(c, 4, 4)
		return string.upper('#' .. r .. r .. g .. g .. b .. b)
	end
	return nil
end

local function tint(c, alpha)
	local r = tonumber(string.sub(c, 2, 3), 16)
	local g = tonumber(string.sub(c, 4, 5), 16)
	local b = tonumber(string.sub(c, 6, 7), 16)
	return string.format('rgba(%d, %d, %d, %s)', r, g, b, tostring(alpha or TINT_ALPHA))
end

-- Size like "300px", "40%" or "20em"; nil for anything else.
local function size(v)
	if type(v) ~= 'string' then
		return nil
	end
	v = mw.text.trim(v)
	if string.match(v, '^%d+$') then
		return v .. 'px'
	end
	if string.match(v, '^%d+%.?%d*px$') or string.match(v, '^%d+%.?%d*%%$') or string.match(v, '^%d+%.?%d*em$') then
		return v
	end
	return nil
end

-- Colour context for one component: theme class and optional custom colour.
local function colourOf(args)
	local t = key(args.theme)
	return {
		class = 'cw-t-' .. (THEMES[t] and t or 'page'),
		colour = hex(args.colour or args.color),
	}
end

-- Marks a node as using the accent in one way; a custom colour is applied inline.
local ACCENT_CSS = {
	bt = 'border-top-color', bl = 'border-left-color', bb = 'border-bottom-color',
	border = 'border-color', bg = 'background-color', text = 'color',
}
local function accent(node, kind, ctx)
	node:addClass('cw-a-' .. kind)
	if ctx.colour then
		if kind == 'tint' then
			node:css('background-color', tint(ctx.colour))
		else
			node:css(ACCENT_CSS[kind], ctx.colour)
		end
	end
	return node
end

-- Root element of a component.
local function root(tag, class, ctx)
	return mw.html.create(tag):addClass('cw-k ' .. class .. ' ' .. ctx.class)
end

-- Wikitext block content: on its own lines so lists, tables and headings work.
local function block(node, text)
	if has(text) then
		node:newline():wikitext(text):newline()
	end
	return node
end

local function fileLink(name, opts)
	if not has(name) then
		return nil
	end
	name = string.gsub(name, '^[Ff]ile:', '')
	name = string.gsub(name, '^[Ii]mage:', '')
	if string.find(name, '[%[%]{}|<>]') then
		return nil
	end
	return '[[File:' .. name .. '|' .. opts .. ']]'
end

local function done(frame, node)
	return styles(frame) .. tostring(node)
end

-- ============================================================
--  Theme (page colours)
-- ============================================================
function p.theme(frame)
	local args = getArgs(frame)
	local t = key(args[1] or args.theme)
	if not THEMES[t] then
		return errorText('Unknown theme "' .. (args[1] or '') .. '".')
	end
	local ok, tag = pcall(function ()
		return frame:extensionTag('templatestyles', '', { src = THEME_PREFIX .. t .. '.css' })
	end)
	return styles(frame) .. (ok and tag or '')
end

-- ============================================================
--  Banner
-- ============================================================
function p.banner(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-banner', ctx)
	accent(node, 'bb', ctx)
	local h = size(args.height)
	if h then
		node:css('min-height', h)
	end
	if key(args.align) == 'left' then
		node:addClass('cw-k-banner-left')
	end
	local img = fileLink(args.image, '1600px|link=|alt=')
	if img then
		node:tag('div'):addClass('cw-k-banner-img'):wikitext(img)
	end
	local inner = node:tag('div'):addClass('cw-k-banner-inner')
	if has(args.kicker) then
		accent(inner:tag('div'):addClass('cw-k-banner-kicker'), 'text', ctx):wikitext(args.kicker)
	end
	inner:tag('div'):addClass('cw-k-banner-title'):wikitext(args.title or args[1] or mw.title.getCurrentTitle().text)
	if has(args.subtitle or args[2]) then
		inner:tag('div'):addClass('cw-k-banner-sub'):wikitext(args.subtitle or args[2])
	end
	accent(inner:tag('div'):addClass('cw-k-banner-rule'), 'bg', ctx)
	return done(frame, node)
end

-- ============================================================
--  Box
-- ============================================================
function p.box(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-box', ctx)
	accent(node, 'bt', ctx)
	local float = key(args.float)
	if float == 'right' or float == 'left' then
		node:addClass('cw-k-float-' .. float)
	end
	local w = size(args.width)
	if w then
		node:css('width', w)
	end
	if has(args.title) then
		local head = accent(node:tag('div'):addClass('cw-k-box-head'), 'tint', ctx)
		local icon = fileLink(args.icon, '24x24px|link=|alt=')
		if icon then
			head:tag('span'):addClass('cw-k-box-icon'):wikitext(icon)
		end
		head:wikitext(args.title)
	end
	block(node:tag('div'):addClass('cw-k-box-body'), args[1] or args.text)
	return done(frame, node)
end

-- ============================================================
--  Callout (tip, note, info, warning, danger, lore, success)
-- ============================================================
function p.callout(frame)
	local args = getArgs(frame)
	local kind = CALLOUTS[key(args.type)] or CALLOUTS.note
	local node = mw.html.create('div'):addClass('cw-k cw-k-callout cw-k-callout-' .. kind[1])
	node:tag('div'):addClass('cw-k-callout-icon'):wikitext(kind[2])
	local body = node:tag('div'):addClass('cw-k-callout-body')
	if has(args.title) then
		body:tag('div'):addClass('cw-k-callout-title'):wikitext(args.title)
	end
	block(body:tag('div'), args[1] or args.text)
	return done(frame, node)
end

-- ============================================================
--  Columns (2 to 4, stack on phones)
-- ============================================================
function p.columns(frame)
	local args = getArgs(frame)
	local node = mw.html.create('div'):addClass('cw-k cw-k-cols')
	local count = 0
	for i = 1, MAX_COLUMNS do
		local text = args[i] or args['col' .. i]
		if has(text) then
			count = count + 1
			block(node:tag('div'):addClass('cw-k-col'), text)
		end
	end
	if count == 0 then
		return errorText('Columns needs at least one column.')
	end
	node:addClass('cw-k-cols-' .. count)
	return done(frame, node)
end

-- ============================================================
--  Button
-- ============================================================
function p.button(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local target = args[1] or args.link
	if not has(target) then
		return errorText('Button needs a page or web address.')
	end
	local label = args[2] or args.label or target
	local style = key(args.style)
	if style ~= 'outline' and style ~= 'ghost' then
		style = 'solid'
	end
	local node = root('span', 'cw-k-btn cw-k-btn-' .. style, ctx)
	if style == 'solid' then
		accent(node, 'bg', ctx)
	end
	if style ~= 'ghost' then
		accent(node, 'border', ctx)
	end
	local sz = key(args.size)
	if sz == 'small' or sz == 'large' then
		node:addClass('cw-k-btn-' .. sz)
	end
	local link
	if string.match(target, '^https?://') then
		link = '[' .. target .. ' ' .. label .. ']'
	else
		link = '[[' .. target .. '|' .. label .. ']]'
	end
	node:wikitext(link)
	return done(frame, node)
end

-- ============================================================
--  Badge and Rarity
-- ============================================================
function p.badge(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local text = args[1] or args.text
	if not has(text) then
		return errorText('Badge needs some text.')
	end
	local node = root('span', 'cw-k-badge', ctx)
	accent(node, 'border', ctx)
	accent(node, 'tint', ctx)
	node:wikitext(text)
	return done(frame, node)
end

function p.rarity(frame)
	local args = getArgs(frame)
	local name = args[1] or args.rarity
	local r = RARITIES[key(name)]
	if not r then
		return errorText('Unknown rarity "' .. (name or '') .. '".')
	end
	local node = mw.html.create('span'):addClass('cw-k cw-k-rarity'):css('color', r[1])
	node:wikitext(args[2] or args.text or r[2])
	return done(frame, node)
end

-- ============================================================
--  Divider and Quote
-- ============================================================
function p.divider(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-divider', ctx)
	accent(node:tag('span'):addClass('cw-k-divider-line'), 'bg', ctx)
	accent(node:tag('span'):addClass('cw-k-divider-mark'), 'text', ctx):wikitext(args[1] or args.text or '&#10070;')
	accent(node:tag('span'):addClass('cw-k-divider-line'), 'bg', ctx)
	return done(frame, node)
end

function p.quote(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local text = args[1] or args.text
	if not has(text) then
		return errorText('Quote needs some text.')
	end
	local node = root('div', 'cw-k-quote', ctx)
	accent(node, 'bl', ctx)
	block(node:tag('div'):addClass('cw-k-quote-text'), text)
	local who, src = args[2] or args.author, args[3] or args.source
	if has(who) or has(src) then
		local cite = node:tag('div'):addClass('cw-k-quote-cite')
		cite:wikitext('&mdash; ' .. (who or ''))
		if has(src) then
			cite:wikitext((has(who) and ', ' or '') .. "''" .. src .. "''")
		end
	end
	return done(frame, node)
end

-- ============================================================
--  Stat bar
-- ============================================================
function p.statBar(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local value = tonumber(args.value or args[2])
	local max = tonumber(args.max or args[3]) or 100
	if not value or max <= 0 then
		return errorText('Stat bar needs a number value (and a max above 0).')
	end
	local pct = math.max(0, math.min(100, value / max * 100))
	local node = root('div', 'cw-k-stat', ctx)
	local top = node:tag('div'):addClass('cw-k-stat-top')
	top:tag('span'):addClass('cw-k-stat-label'):wikitext(args.label or args[1] or '')
	top:tag('span'):addClass('cw-k-stat-value'):wikitext(args.text or (mw.text.nowiki(tostring(args.value or args[2])) .. ' / ' .. mw.text.nowiki(tostring(args.max or args[3] or 100))))
	local fill = node:tag('div'):addClass('cw-k-stat-track'):tag('div'):addClass('cw-k-stat-fill')
	fill:css('width', string.format('%.1f%%', pct))
	accent(fill, 'bg', ctx)
	return done(frame, node)
end

-- ============================================================
--  Step (numbered guide steps)
-- ============================================================
function p.step(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-step', ctx)
	local n = args.n or args.number
	accent(node:tag('div'):addClass('cw-k-step-num'), 'bg', ctx):wikitext(n and mw.text.nowiki(n) or '&bull;')
	local body = node:tag('div'):addClass('cw-k-step-body')
	if has(args.title) then
		body:tag('div'):addClass('cw-k-step-title'):wikitext(args.title)
	end
	block(body:tag('div'), args[1] or args.text)
	return done(frame, node)
end

-- ============================================================
--  Collapse (uses MediaWiki's built-in collapsible sections)
-- ============================================================
function p.collapse(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-collapse mw-collapsible', ctx)
	if not yes(args.open) then
		node:addClass('mw-collapsed')
	end
	accent(node, 'bl', ctx)
	node:tag('div'):addClass('cw-k-collapse-head'):wikitext(args.title or 'Show more')
	block(node:tag('div'):addClass('mw-collapsible-content cw-k-collapse-body'), args[1] or args.text)
	return done(frame, node)
end

-- ============================================================
--  Tabs (MediaWiki:CinderKit.js turns these into tabs; without
--  JavaScript every panel shows one after another with its label)
-- ============================================================
function p.tabs(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-tabs', ctx)
	local count = 0
	for i = 1, MAX_TABS do
		local label, text = args['tab' .. i] or args['label' .. i], args['content' .. i]
		if has(label) and has(text) then
			count = count + 1
			local panel = node:tag('div'):addClass('cw-k-tab-panel'):attr('data-label', label)
			accent(panel:tag('div'):addClass('cw-k-tab-fallback'), 'bb', ctx):wikitext(label)
			block(panel:tag('div'):addClass('cw-k-tab-body'), text)
		end
	end
	if count == 0 then
		return errorText('Tabs needs tab1 and content1 (up to ' .. MAX_TABS .. ').')
	end
	return done(frame, node)
end

-- ============================================================
--  Infobox (characters, places, factions, anything)
-- ============================================================
function p.infobox(frame)
	local args = getArgs(frame)
	local ctx = colourOf(args)
	local node = root('div', 'cw-k-infobox', ctx)
	accent(node, 'bt', ctx)
	local w = size(args.width)
	if w then
		node:css('width', w)
	end
	if key(args.float) == 'left' then
		node:addClass('cw-k-infobox-left')
	end
	accent(node:tag('div'):addClass('cw-k-infobox-title'), 'tint', ctx)
		:wikitext(args.title or mw.title.getCurrentTitle().text)
	if has(args.subtitle) then
		node:tag('div'):addClass('cw-k-infobox-sub'):wikitext(args.subtitle)
	end
	local img = fileLink(args.image, (size(args.imagesize) or '260px') .. '|alt=' .. mw.text.nowiki(args.title or ''))
	if img then
		local fig = node:tag('div'):addClass('cw-k-infobox-img'):wikitext(img)
		if has(args.caption) then
			fig:tag('div'):addClass('cw-k-infobox-caption'):wikitext(args.caption)
		end
	end
	local tbl = node:tag('div'):addClass('cw-k-infobox-rows')
	for i = 1, MAX_INFOBOX_ROWS do
		if has(args['header' .. i]) then
			accent(tbl:tag('div'):addClass('cw-k-infobox-header'), 'bb', ctx):wikitext(args['header' .. i])
		end
		local label, data = args['label' .. i], args['data' .. i]
		if has(data) then
			local row = tbl:tag('div'):addClass('cw-k-infobox-row')
			if has(label) then
				row:tag('div'):addClass('cw-k-infobox-label'):wikitext(label)
			else
				row:addClass('cw-k-infobox-full')
			end
			block(row:tag('div'):addClass('cw-k-infobox-data'), data)
		end
	end
	if has(args.below) then
		block(node:tag('div'):addClass('cw-k-infobox-below'), args.below)
	end
	return done(frame, node)
end

-- ============================================================
--  Small inline tools
-- ============================================================
function p.key(frame)
	local args = getArgs(frame)
	local parts = {}
	for i = 1, MAX_KEYS do
		if has(args[i]) then
			parts[#parts + 1] = '<kbd class="cw-k-key">' .. mw.text.nowiki(args[i]) .. '</kbd>'
		end
	end
	if #parts == 0 then
		return errorText('Key needs a key name.')
	end
	return styles(frame) .. '<span class="cw-k cw-k-keys">' .. table.concat(parts, '<span class="cw-k-plus">+</span>') .. '</span>'
end

function p.coords(frame)
	local args = getArgs(frame)
	local x, y, z = args[1] or args.x, args[2] or args.y, args[3] or args.z
	if not (has(x) and has(z)) then
		return errorText('Coords needs at least x and z.')
	end
	local text = 'X ' .. x .. (has(y) and (', Y ' .. y) or '') .. ', Z ' .. z
	local tp = '/tp ' .. x .. ' ' .. (has(y) and y or '~') .. ' ' .. z
	local node = mw.html.create('span'):addClass('cw-k cw-k-coords'):attr('title', tp)
	node:tag('span'):addClass('cw-k-coords-pin'):wikitext('&#8982;')
	node:wikitext(mw.text.nowiki(text))
	if has(args.world or args[4]) then
		node:tag('span'):addClass('cw-k-coords-world'):wikitext(mw.text.nowiki(args.world or args[4]))
	end
	return done(frame, node)
end

function p.spoiler(frame)
	local args = getArgs(frame)
	local text = args[1] or args.text
	if not has(text) then
		return errorText('Spoiler needs some text.')
	end
	local node = mw.html.create('span'):addClass('cw-k cw-k-spoiler'):attr('title', 'Spoiler: hover or tap to reveal')
	node:wikitext(text)
	return done(frame, node)
end

function p.hover(frame)
	local args = getArgs(frame)
	local text, tip = args[1] or args.text, args[2] or args.tip
	if not has(text) then
		return errorText('Hover needs some text.')
	end
	local node = mw.html.create('span'):addClass('cw-k cw-k-hover')
	if has(tip) then
		node:attr('title', tip)
	end
	node:wikitext(text)
	return done(frame, node)
end

-- Minecraft text: {{MC|gold|Text}}, {{MC|6|Text}}, or codes inside one
-- value: {{MC|&6Gold &lbold &rplain}} (also the section sign).
local function mcSpan(colour, fmt, text)
	local s = mw.html.create('span')
	if colour then
		s:css('color', colour)
	end
	if fmt.l then s:css('font-weight', 'bold') end
	if fmt.o then s:css('font-style', 'italic') end
	local deco = {}
	if fmt.n then deco[#deco + 1] = 'underline' end
	if fmt.m then deco[#deco + 1] = 'line-through' end
	if #deco > 0 then
		s:css('text-decoration', table.concat(deco, ' '))
	end
	s:wikitext(mw.text.nowiki(text))
	return tostring(s)
end

local function mcCodes(text)
	text = string.gsub(text, SECTION_SIGN, '&')
	local out, colour, fmt = {}, MC_COLOURS.f, {}
	local pos = 1
	while pos <= #text do
		local a, b, code = string.find(text, '&([0-9a-fk-orA-FK-OR])', pos)
		local chunk = string.sub(text, pos, (a or (#text + 1)) - 1)
		if chunk ~= '' then
			out[#out + 1] = mcSpan(colour, fmt, chunk)
		end
		if not a then
			break
		end
		code = string.lower(code)
		if MC_COLOURS[code] then
			colour, fmt = MC_COLOURS[code], {}
		elseif code == 'r' then
			colour, fmt = MC_COLOURS.f, {}
		elseif code ~= 'k' then
			fmt[code] = true
		end
		pos = b + 1
	end
	return table.concat(out)
end

function p.mc(frame)
	local args = getArgs(frame)
	local plain = yes(args.plain)
	local inner
	if has(args[2]) then
		local c = key(args[1])
		local colour = MC_COLOURS[MC_NAMES[c] or c] or hex(args[1])
		inner = mcSpan(colour, {}, args[2])
	elseif has(args[1]) then
		inner = mcCodes(args[1])
	else
		return errorText('MC needs some text.')
	end
	return styles(frame) .. '<span class="cw-k cw-k-mc' .. (plain and ' cw-k-mc-plain' or '') .. '">' .. inner .. '</span>'
end

return p
