-- Module:Map
-- Interactive maps and region cards.
--
--   {{Map|image=map_shard1.png|
--   {{Map marker|chest|52.5|51.5}}
--   {{Map marker|boss|7|12.5|name=Ogre King|text=Drops the Ogre Club.}}
--   }}
--
--   {{Region cards|
--   {{Region card|name=Locfel|tags=Town|level=Level 1|colour=green|text=...|more=...}}
--   }}
--
-- Marker positions are percentages of the map picture: x from the left edge,
-- y from the top. Logged-in editors get an "Add marker" button on every map
-- that shows the code for wherever they click.
-- Zoom, pan, filters, fullscreen and pinned popups come from
-- MediaWiki:CinderKit.js; without it the map still shows every marker, with
-- popups on hover. Marker types live in Module:Map/types.

local p = {}

-- ============================================================
--  Settings
-- ============================================================
local CSS          = 'Template:Map/styles.css'
local TYPES        = require('Module:Map/types')
local DEFAULT_SIZE = 26     -- marker size in pixels
local MIN_SIZE     = 12
local MAX_SIZE     = 64
local EDGE_PCT     = 18     -- popups near an edge open the other way

-- Region card colours (old site palette) and tag colours.
local CARD_COLOURS = {
	green = true, teal = true, orange = true, pink = true, cyan = true, lime = true,
	red = true, blue = true, purple = true, gold = true, grey = true,
}
local TAGS = {
	town = 'town', starting = 'town', startingzone = 'town', village = 'town',
	exploration = 'explore', explore = 'explore', wilds = 'explore',
	dungeon = 'dungeon', crypt = 'dungeon',
	boss = 'boss', bosses = 'boss',
	resources = 'resource', resource = 'resource', gathering = 'resource',
	endgame = 'endgame', pvp = 'pvp', pvpzone = 'pvp',
	quest = 'quest', quests = 'quest',
}
-- Default symbol for a card's first tag (HTML entities keep this file ASCII).
local TAG_SYMBOLS = {
	town = '&#8962;', explore = '&#10022;', dungeon = '&#9876;', boss = '&#9760;',
	resource = '&#9874;', endgame = '&#9819;', pvp = '&#9876;', quest = '&#10070;',
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

local function key(v)
	return v and string.lower((string.gsub(v, '[%s_%-]', ''))) or ''
end

local function yes(v)
	v = key(v)
	return v == 'yes' or v == 'y' or v == 'true' or v == '1' or v == 'on'
end

local function styles(frame)
	local ok, tag = pcall(function ()
		return frame:extensionTag('templatestyles', '', { src = CSS })
	end)
	return ok and tag or ''
end

local function errorText(msg)
	return '<strong class="error">' .. mw.text.nowiki(msg) .. '</strong>'
end

local function hex(c)
	if type(c) ~= 'string' then
		return nil
	end
	c = mw.text.trim(c)
	if string.sub(c, 1, 1) ~= '#' then
		c = '#' .. c
	end
	return string.match(c, '^#%x%x%x%x%x%x$') and string.upper(c) or nil
end

-- A file name safe to put in [[File:...]], or nil.
local function fileName(name)
	if not has(name) then
		return nil
	end
	name = string.gsub(name, '^[Ff]ile:', '')
	name = string.gsub(name, '^[Ii]mage:', '')
	if string.find(name, '[%[%]{}|<>#]') then
		return nil
	end
	return name
end

local function number(v)
	local n = tonumber(v)
	if n and n == n and n ~= math.huge and n ~= -math.huge then
		return n
	end
	return nil
end

-- Percent as short text: 52.50 -> "52.5".
local function pct(n)
	local s = string.format('%.3f', n)
	s = string.gsub(s, '0+$', '')
	return (string.gsub(s, '%.$', ''))
end

local function typeOf(name)
	local k = key(name)
	k = TYPES.aliases[k] or k
	return k, TYPES.types[k]
end

-- ============================================================
--  Map
-- ============================================================
function p.map(frame)
	local args = getArgs(frame)
	local image = fileName(args.image)
	if not image then
		return errorText('Map needs image= with an uploaded file name.')
	end
	local root = mw.html.create('div'):addClass('cw-map')
	if yes(args.pixel) then
		root:addClass('cw-map-pixel')
	end
	local size = number(args.size)
	if size then
		size = math.max(MIN_SIZE, math.min(MAX_SIZE, math.floor(size)))
		root:attr('data-size', tostring(size))
	end
	local maxw = args.width and string.match(args.width, '^(%d+)p?x?$')
	if maxw then
		root:css('max-width', maxw .. 'px')
	end
	-- Optional world coordinates of the picture's corners, for the X/Z in popups.
	local x1, z1, x2, z2 = number(args.x1), number(args.z1), number(args.x2), number(args.z2)
	if x1 and z1 and x2 and z2 and x1 ~= x2 and z1 ~= z2 then
		root:attr('data-world', table.concat({ x1, z1, x2, z2 }, ','))
	end
	if has(args.hidden) then
		local list = {}
		for part in mw.text.gsplit(args.hidden, ',', true) do
			local t = typeOf(part)
			if t ~= '' then
				list[#list + 1] = t
			end
		end
		root:attr('data-hidden', table.concat(list, ','))
	end
	if has(args.title) then
		root:tag('div'):addClass('cw-map-title'):wikitext(args.title)
	end
	local stage = root:tag('div'):addClass('cw-map-view'):tag('div'):addClass('cw-map-stage')
	stage:tag('div'):addClass('cw-map-img'):wikitext('[[File:' .. image .. '|link=|alt=' .. mw.text.nowiki(args.title or 'Map') .. ']]')
	local markers = stage:tag('div'):addClass('cw-map-markers')
	if has(args[1]) then
		markers:newline():wikitext(args[1]):newline()
	end
	if has(args.caption) then
		root:tag('div'):addClass('cw-map-caption'):wikitext(args.caption)
	end
	return styles(frame) .. tostring(root)
end

-- ============================================================
--  Marker
-- ============================================================
function p.marker(frame)
	local args = getArgs(frame)
	local x = number(args[2] or args.x)
	local y = number(args[3] or args.y)
	if not x or not y then
		return errorText('Map marker needs a type, then x and y as numbers from 0 to 100.')
	end
	x = math.max(0, math.min(100, x))
	y = math.max(0, math.min(100, y))
	local tkey, t = typeOf(args[1] or args.type)
	if tkey == '' then
		tkey = 'poi'
		t = TYPES.types.poi
	end
	t = t or {}
	local label = args.label or t.label or (string.upper(string.sub(tkey, 1, 1)) .. string.sub(tkey, 2))
	local icon = fileName(args.icon) or t.icon
	local node = mw.html.create('div'):addClass('cw-map-mk')
		:attr('data-type', tkey)
		:attr('data-label', label)
		:attr('data-x', pct(x)):attr('data-y', pct(y))
		:attr('title', args.name or label)
		:css('left', pct(x) .. '%'):css('top', pct(y) .. '%')
	if y < EDGE_PCT then
		node:addClass('cw-map-pop-below')
	end
	if x < EDGE_PCT then
		node:addClass('cw-map-pop-left')
	elseif x > 100 - EDGE_PCT then
		node:addClass('cw-map-pop-right')
	end
	if icon then
		node:wikitext('[[File:' .. icon .. '|24px|link=|alt=' .. mw.text.nowiki(label) .. ']]')
	else
		node:tag('span'):addClass('cw-map-dot'):css('background-color', hex(args.colour or args.color) or t.colour or '#BFA06F')
	end
	local pop = node:tag('div'):addClass('cw-map-pop')
	pop:tag('div'):addClass('cw-map-pop-name'):wikitext(args.name or label)
	if args.name and args.name ~= label then
		pop:tag('div'):addClass('cw-map-pop-type'):wikitext(label)
	end
	if has(args.text) then
		pop:tag('div'):addClass('cw-map-pop-text'):wikitext(args.text)
	end
	if has(args.link) then
		pop:tag('div'):addClass('cw-map-pop-link'):wikitext('[[' .. args.link .. '|More &rarr;]]')
	end
	return tostring(node)
end

-- ============================================================
--  Region cards
-- ============================================================
function p.regionCards(frame)
	local args = getArgs(frame)
	local node = mw.html.create('div'):addClass('cw-regions')
	if has(args[1]) then
		node:newline():wikitext(args[1]):newline()
	end
	return styles(frame) .. tostring(node)
end

function p.regionCard(frame)
	local args = getArgs(frame)
	local name = args.name or args[1]
	if not has(name) then
		return errorText('Region card needs name=.')
	end
	local colour = key(args.colour or args.color)
	if not CARD_COLOURS[colour] then
		colour = 'gold'
	end
	local card = mw.html.create('div'):addClass('cw-region cw-rc-' .. colour)

	local tags, firstTag = {}, nil
	if has(args.tags or args.tag) then
		for part in mw.text.gsplit(args.tags or args.tag, ',', true) do
			part = mw.text.trim(part)
			if part ~= '' then
				local cls = TAGS[key(part)] or 'other'
				firstTag = firstTag or cls
				tags[#tags + 1] = '<span class="cw-region-tag cw-rt-' .. cls .. '">' .. mw.text.nowiki(part) .. '</span>'
			end
		end
	end

	local icon = card:tag('div'):addClass('cw-region-icon')
	local iconFile = fileName(args.icon)
	if iconFile then
		icon:wikitext('[[File:' .. iconFile .. '|28px|link=|alt=]]')
	else
		icon:wikitext(TAG_SYMBOLS[firstTag or ''] or '&#10070;')
	end

	local body = card:tag('div'):addClass('cw-region-body')
	local title = has(args.link) and ('[[' .. args.link .. '|' .. name .. ']]') or name
	body:tag('div'):addClass('cw-region-name'):wikitext(title)
	if #tags > 0 or has(args.level) then
		local meta = body:tag('div'):addClass('cw-region-meta')
		meta:wikitext(table.concat(tags))
		if has(args.level) then
			meta:tag('span'):addClass('cw-region-level'):wikitext(args.level)
		end
	end
	if has(args.text) then
		body:tag('div'):addClass('cw-region-text'):wikitext(args.text)
	end
	if has(args.more) then
		local more = card:tag('div'):addClass('cw-region-more')
		more:tag('div'):addClass('cw-region-more-name'):wikitext(name)
		more:tag('div'):wikitext(args.more)
	end
	return tostring(card)
end

return p
