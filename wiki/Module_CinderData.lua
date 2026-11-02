-- Module:CinderData
-- Draws item, tab, spell, class and system pages from the Data: pages the
-- CinderWiki sync writes. Articles only call the templates below, so stats
-- update by themselves after every sync.
--
--   {{Item|id=ashenblade}}            infobox for one item
--   {{ItemTable|tab=cinderblocks}}    sortable table of a tab
--   {{ItemGrid|tab=cinderweaponry}}   card grid of a tab
--   {{Spell|key=FireBolt}}            spell infobox
--   {{SpellTable}}                    every spell
--   {{ClassList}}                     every class and subclass
--   {{ClassPage|key=SAMURAI}}         one class or subclass
--   {{SystemDoc|id=damage-ledger}}    one documented system
--
-- Data from mw.loadJsonData is read-only: use pairs/ipairs on it, never # or
-- the table library (copy it into a plain table first).

local p = {}

-- ============================================================
--  Settings (titles must match CinderWiki PageBuilder)
-- ============================================================
local ITEM_PREFIX    = 'Data:Item/'
local TAB_PREFIX     = 'Data:Tab/'
local SPELLS_PAGE    = 'Data:Spells'
local CLASSES_PAGE   = 'Data:Classes'
local SYSTEM_PREFIX  = 'Data:System/'
local CLASS_PREFIX   = 'Class/'
local STYLES         = 'Template:CinderData/styles.css'
local CAT_NO_DATA    = 'Pages missing mod data'
local CATEGORY_NAMESPACES = { [0] = true }  -- only articles go in tracking categories
local DECIMALS       = 2     -- stats shown with at most this many decimals
local TICKS          = 20    -- game ticks per second
local DEFAULT_STACK  = 64    -- stack size not worth a column
local MAX_SPELL_ITEMS = 400  -- item pages read for spell names on one page

-- Rarity order (weapon and bauble rarity keys), lowest first.
local RARITY_RANK = {
	COMMON = 1, UNCOMMON = 2, RARE = 3, SUPER_RARE = 4, LEGENDARY = 5, MYTHIC = 6, WORLD = 7,
}

-- Spell tiers: display name, colour (same as the weapon rarity of that tier), order.
local SPELL_TIERS = {
	TIER_1   = { 'Tier 1', '#AAAAAA', 1 },
	TIER_2   = { 'Tier 2', '#55FF55', 2 },
	TIER_3   = { 'Tier 3', '#6688FF', 3 },
	TIER_4   = { 'Tier 4', '#55FFFF', 4 },
	TIER_5   = { 'Tier 5', '#FFFF55', 5 },
	TIER_S   = { 'Super Tier', '#FF5555', 6 },
	TIER_W   = { 'World Tier', '#D98CFF', 7 },
	TIER_TBD = { 'Not decided', '#AAAAAA', 8 },
}

-- Spell element frame colours.
local ELEMENT_COLOURS = {
	PYROMANCY = '#FF6633', HYDROMANCY = '#3399FF', ELECTROMANCY = '#FFEE55', GEOMANCY = '#B08050',
	AEROMANCY = '#CCF5FF', CRYOMANCY = '#99DDFF', THEOMANCY = '#FFDD88', DEMONANCY = '#CC3333',
	NECROMANCY = '#77BB55', GOLEMANCY = '#9999AA',
}

local SPELL_TYPES = {
	PROJECTILE = 'Projectile', AOE = 'Area of effect', CONJURATION = 'Conjuration',
	SUMMONING = 'Summoning', UTILITY = 'Utility',
}

local ARMOUR_SLOTS = { head = 'Helmet', chest = 'Chestplate', legs = 'Leggings', feet = 'Boots' }
local HARVEST_LEVELS = { [0] = 'Any', [1] = 'Stone', [2] = 'Iron', [3] = 'Diamond' }

-- ============================================================
--  Helpers
-- ============================================================
local loadJson = mw.loadJsonData or function (title)
	-- Older MediaWiki without mw.loadJsonData
	local t = mw.title.new(title)
	local text = t and t:getContent()
	if not text then
		error('missing page ' .. title)
	end
	return mw.text.jsonDecode(text)
end

local cache = {}

-- The JSON on a page as a (read-only) table, or nil if missing or broken.
local function load(title)
	if cache[title] == nil then
		local ok, data = pcall(loadJson, title)
		cache[title] = (ok and type(data) == 'table') and data or false
	end
	return cache[title] or nil
end

local function trim(s)
	return mw.text.trim(s or '')
end

local function esc(s)
	return mw.text.nowiki(tostring(s))
end

local function isNum(v)
	return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

local function isText(v)
	return type(v) == 'string' and v ~= ''
end

-- Number with at most DECIMALS decimals, no trailing zeros.
local function fmt(n)
	if not isNum(n) then
		return '?'
	end
	local s = string.format('%.' .. DECIMALS .. 'f', n)
	if string.find(s, '.', 1, true) then
		s = string.gsub(s, '0+$', '')
		s = string.gsub(s, '%.$', '')
	end
	if s == '-0' then
		s = '0'
	end
	return s
end

-- Ticks as seconds: 30 -> "1.5s".
local function seconds(ticks)
	return fmt(ticks / TICKS) .. 's'
end

-- Plain copy of a read-only list.
local function copyList(list)
	local out = {}
	if type(list) == 'table' then
		for _, v in ipairs(list) do
			out[#out + 1] = v
		end
	end
	return out
end

-- "SUPER_RARE" -> "Super Rare"
local function titleCase(s)
	if not isText(s) then
		return nil
	end
	s = string.lower(string.gsub(s, '_', ' '))
	return (string.gsub(s, '(%a)([%w]*)', function (a, b) return string.upper(a) .. b end))
end

-- "FireBolt" -> "Fire Bolt"
local function splitCamel(s)
	return (string.gsub(s, '(%l)(%u)', '%1 %2'))
end

-- A "#RRGGBB" colour, or nil if it is anything else.
local function colour(c)
	if type(c) == 'string' and string.match(c, '^#%x%x%x%x%x%x$') then
		return c
	end
	return nil
end

-- Page titles we link to come from registry paths: plain characters only.
local function safeTarget(t)
	return isText(t) and string.match(t, '^[%w_%.%-/ ]+$') ~= nil
end

local function link(target, text)
	if not safeTarget(target) then
		return esc(text)
	end
	return '[[' .. target .. '|' .. esc(text) .. ']]'
end

-- "cinderextras2:spellfirebolt" -> "spellfirebolt"
local function itemPath(id)
	if not isText(id) then
		return nil
	end
	local colon = string.find(id, ':', 1, true)
	return colon and string.sub(id, colon + 1) or id
end

local function classLink(key, text)
	if not isText(key) then
		return esc(text)
	end
	return link(CLASS_PREFIX .. string.lower(key), text)
end

local function inArticle()
	local title = mw.title.getCurrentTitle()
	return title and CATEGORY_NAMESPACES[title.namespace] or false
end

local function category(name)
	return inArticle() and ('[[Category:' .. name .. ']]') or ''
end

-- Arguments from the #invoke, falling back to the template call.
local function getArgs(frame)
	local args = {}
	local parent = frame:getParent()
	if parent then
		for k, v in pairs(parent.args) do
			args[k] = trim(v)
		end
	end
	for k, v in pairs(frame.args) do
		if trim(v) ~= '' then
			args[k] = trim(v)
		end
	end
	return args
end

-- TemplateStyles tag (nothing if the extension is missing).
local function styles(frame)
	local ok, tag = pcall(function ()
		return frame:extensionTag('templatestyles', '', { src = STYLES })
	end)
	return ok and tag or ''
end

local function displayTitle(frame, text)
	if not isText(text) or not inArticle() then
		return ''
	end
	local ok, out = pcall(function ()
		return frame:callParserFunction('DISPLAYTITLE', esc(text), 'noerror')
	end)
	return ok and out or ''
end

local function missing(frame, what)
	return styles(frame) .. tostring(mw.html.create('div'):addClass('cw-missing')
		:wikitext('The ' .. what .. ' for this page will appear after the next wiki sync. If it never does, '
			.. 'the entry may have been removed from the game.'))
		.. category(CAT_NO_DATA)
end

local function rarityRank(key)
	return RARITY_RANK[key] or 0
end

-- ============================================================
--  Tooltip box (infoboxes)
-- ============================================================
-- Rows are collected per section and only drawn if the section has any.
local Box = {}
Box.__index = Box

local function newBox(frameColour)
	local self = setmetatable({}, Box)
	self.root = mw.html.create('div'):addClass('cw-tip')
	if frameColour then
		self.root:css('border-color', frameColour)
	end
	return self
end

function Box:title(text, textColour)
	local t = self.root:tag('div'):addClass('cw-tip-title'):wikitext(esc(text))
	if textColour then
		t:css('color', textColour)
	end
end

function Box:line(class, wikitext, textColour)
	if not isText(wikitext) then
		return
	end
	local l = self.root:tag('div'):addClass(class):wikitext(wikitext)
	if textColour then
		l:css('color', textColour)
	end
end

-- rows: list of { label, wikitext }; nil values are skipped.
function Box:section(heading, rows)
	local shown = {}
	for _, r in ipairs(rows) do
		if isText(r[2]) then
			shown[#shown + 1] = r
		end
	end
	if #shown == 0 then
		return
	end
	if heading then
		self.root:tag('div'):addClass('cw-tip-head'):wikitext(heading)
	end
	for _, r in ipairs(shown) do
		local row = self.root:tag('div'):addClass('cw-tip-row')
		row:tag('span'):addClass('cw-tip-label'):wikitext(r[1])
		row:tag('span'):addClass('cw-tip-value'):wikitext(r[2])
	end
end

function Box:html()
	return tostring(self.root)
end

-- Text coloured letter by letter across a gradient (event names).
local function gradientText(text, colours)
	local list = {}
	for _, c in ipairs(copyList(colours)) do
		if colour(c) then
			list[#list + 1] = c
		end
	end
	if #list == 0 then
		return esc(text)
	end
	local len = mw.ustring.len(text)
	local out = {}
	for i = 1, len do
		local idx = math.min(#list, math.floor((i - 1) * #list / len) + 1)
		out[#out + 1] = '<span style="color:' .. list[idx] .. '">' .. esc(mw.ustring.sub(text, i, i)) .. '</span>'
	end
	return table.concat(out)
end

-- ============================================================
--  Item stats
-- ============================================================
local function armourSlot(slot)
	return isText(slot) and (ARMOUR_SLOTS[slot] or titleCase(slot)) or nil
end

local function hardness(h)
	if not isNum(h) then
		return nil
	end
	return h < 0 and 'Unbreakable' or fmt(h)
end

local function toolText(block)
	if not isText(block.tool) then
		return nil
	end
	local lvl = block.harvestLevel
	local prefix = isNum(lvl) and (HARVEST_LEVELS[lvl] or ('Level ' .. fmt(lvl))) or 'Any'
	return esc(prefix .. ' ' .. block.tool)
end

-- Saturation the food restores (the game's modifier x hunger x 2).
local function saturation(food)
	if isNum(food.hunger) and isNum(food.saturation) then
		return food.hunger * food.saturation * 2
	end
	return nil
end

local function numText(v, suffix)
	return isNum(v) and (fmt(v) .. (suffix or '')) or nil
end

local function positive(v, suffix)
	return isNum(v) and v > 0 and (fmt(v) .. (suffix or '')) or nil
end

-- Rarity of an item entry: name, key, colour (weapon first, then bauble).
local function rarityOf(v)
	local src = type(v.weapon) == 'table' and v.weapon.rarity and v.weapon
		or type(v.bauble) == 'table' and v.bauble.rarity and v.bauble or nil
	if not src then
		return nil
	end
	return src.rarity, src.rarityKey, colour(src.rarityColour)
end

-- "Rare Katana", "Ring", "Helmet"...
local function subtitle(v)
	local rarity = rarityOf(v)
	local kind
	if type(v.weapon) == 'table' and isText(v.weapon.type) then
		kind = v.weapon.type
	elseif type(v.bauble) == 'table' and isText(v.bauble.slot) then
		kind = v.bauble.slot
	elseif type(v.armour) == 'table' then
		kind = armourSlot(v.armour.slot)
	elseif type(v.food) == 'table' then
		kind = 'Food'
	elseif type(v.block) == 'table' then
		kind = 'Block'
	end
	if rarity and kind then
		return rarity .. ' ' .. kind
	end
	return rarity or kind
end

local function weaponLines(box, w)
	local reqs = {}
	for _, r in ipairs(copyList(w.requirements)) do
		if type(r) == 'table' and isText(r.text) then
			reqs[#reqs + 1] = 'Requires ' .. classLink(r.subclassKey, r.text)
		end
	end
	if w.needsWorldPerk then
		reqs[#reqs + 1] = 'Requires World Perk'
	end
	for _, r in ipairs(reqs) do
		box:line('cw-tip-req', r)
	end
	if isText(w.event) then
		box:line('cw-tip-event', gradientText(w.event, w.eventGradient))
	end
end

local function effectRows(w)
	local statuses, specials = {}, {}
	for _, fx in ipairs(copyList(w.effects)) do
		if type(fx) == 'table' and isText(fx.name) then
			if fx.kind == 'STATUS' then
				statuses[#statuses + 1] = esc(fx.name)
			else
				specials[#specials + 1] = esc(fx.name)
			end
		end
	end
	return {
		{ 'Inflicts', #statuses > 0 and table.concat(statuses, ', ') or nil },
		{ 'Special', #specials > 0 and table.concat(specials, ', ') or nil },
	}
end

local function meleeRows(v)
	local m = type(v.melee) == 'table' and v.melee or {}
	local w = type(v.weapon) == 'table' and v.weapon or {}
	local damage = m.attackDamage
	if not isNum(damage) and type(v.ranged) ~= 'table' then
		damage = w.baseDamage
	end
	return {
		{ 'Damage', numText(damage) },
		{ 'Attack speed', numText(m.attackSpeed, ' per second') },
		{ 'Ability', isText(w.ability) and esc(w.ability) or nil },
	}
end

local function rangedRows(r)
	local shots = isNum(r.projectiles) and r.projectiles > 1 and r.projectiles or nil
	local damage = numText(r.damage)
	if damage and shots then
		damage = damage .. ' &times; ' .. fmt(shots)
	end
	local rows = {
		{ 'Damage', damage },
		{ 'Volley damage', shots and numText(r.volleyDamage) or nil },
		{ 'Pierce', positive(r.pierce, ' per hit') },
		{ 'Between shots', isNum(r.fireCooldown) and r.fireCooldown > 0 and seconds(r.fireCooldown) or nil },
		{ 'Burst', isNum(r.burstSize) and r.burstSize > 1 and (fmt(r.burstSize) .. ' shots') or nil },
		{ 'Magazine', positive(r.magazine) },
		{ 'Reload', isNum(r.reload) and r.reload > 0 and seconds(r.reload) or nil },
		{ 'Damage per second', numText(r.sustainedDps) },
		{ 'Accuracy', numText(r.accuracyRating, '/100') },
		{ 'Recoil', numText(r.recoilRating, '/100') },
	}
	if isNum(r.adsDamage) and r.adsDamage >= 0 then
		local aimed = fmt(r.adsDamage)
		if isNum(r.adsProjectiles) and r.adsProjectiles > 1 then
			aimed = aimed .. ' &times; ' .. fmt(r.adsProjectiles)
		end
		rows[#rows + 1] = { 'Aimed damage', aimed }
		rows[#rows + 1] = { 'Aimed accuracy', numText(r.adsAccuracyRating, '/100') }
	end
	if isNum(r.autoFireInterval) and r.autoFireInterval > 0 then
		rows[#rows + 1] = { 'Auto fire', 'every ' .. seconds(r.autoFireInterval) }
	end
	return rows
end

local function baubleRows(b)
	local rows = { { 'Slot', isText(b.slot) and esc(b.slot) or nil } }
	for _, e in ipairs(copyList(b.effects)) do
		if isText(e) then
			rows[#rows + 1] = { 'Effect', esc(e) }
		end
	end
	return rows
end

local function variantNames(variants)
	if #variants < 2 then
		return nil
	end
	local seen, names = {}, {}
	for _, v in ipairs(variants) do
		if isText(v.name) and not seen[v.name] then
			seen[v.name] = true
			names[#names + 1] = esc(v.name)
		end
	end
	return #names > 1 and table.concat(names, ', ') or nil
end

-- Stack size worth showing: not the usual 64, and not 1 on gear (always 1).
local function stackText(v)
	local n = v.stackSize
	if not isNum(n) or n == DEFAULT_STACK then
		return nil
	end
	local gear = type(v.weapon) == 'table' or type(v.armour) == 'table' or type(v.bauble) == 'table'
		or type(v.ranged) == 'table' or isNum(v.maxDamage)
	if n == 1 and gear then
		return nil
	end
	return fmt(n)
end

-- The whole item infobox for one item (all its variants).
local function itemBox(data)
	local variants = copyList(data.variants)
	local v = variants[1]
	local name = isText(v.name) and v.name or data.id
	local _, _, rColour = rarityOf(v)
	local sub = subtitle(v)
	local box = newBox(rColour)
	box:title(name, rColour or '#FFFFFF')
	box:line('cw-tip-sub', isText(sub) and esc(sub) or nil, rColour)

	local w = type(v.weapon) == 'table' and v.weapon or nil
	if w then
		weaponLines(box, w)
	end
	if w or type(v.melee) == 'table' then
		box:section('Combat', meleeRows(v))
	end
	if type(v.ranged) == 'table' then
		box:section('Ranged', rangedRows(v.ranged))
	end
	if w then
		box:section(nil, effectRows(w))
	end
	if type(v.bauble) == 'table' then
		box:section('Bauble', baubleRows(v.bauble))
		if isText(v.bauble.description) then
			box:line('cw-tip-desc', esc(v.bauble.description))
		end
	end
	if type(v.armour) == 'table' then
		local a = v.armour
		box:section('Armour', {
			{ 'Slot', armourSlot(a.slot) },
			{ 'Armour', numText(a.armour) },
			{ 'Toughness', positive(a.toughness) },
			{ 'Material', titleCase(a.material) },
		})
	end
	if type(v.food) == 'table' then
		local f = v.food
		box:section('Food', {
			{ 'Hunger', isNum(f.hunger) and (fmt(f.hunger) .. ' (' .. fmt(f.hunger / 2) .. ' shanks)') or nil },
			{ 'Saturation', numText(saturation(f)) },
		})
	end
	if type(v.block) == 'table' then
		local b = v.block
		box:section('Block', {
			{ 'Hardness', hardness(b.hardness) },
			{ 'Blast resistance', numText(b.blastResistance) },
			{ 'Tool', toolText(b) },
			{ 'Light', positive(b.light) },
		})
	end

	local doc = type(v.doc) == 'table' and v.doc or {}
	box:section('Details', {
		{ 'Obtained', isText(doc.obtaining) and esc(doc.obtaining) or (w and isText(w.source) and esc(w.source) or nil) },
		{ 'Bonus EXP', w and isNum(w.expBonus) and ('+' .. fmt(w.expBonus) .. '%') or nil },
		{ 'Durability', positive(v.maxDamage) },
		{ 'Stack size', stackText(v) },
		{ 'Variants', variantNames(variants) },
		{ 'Formerly', isText(doc.renamedFrom) and esc(doc.renamedFrom) or nil },
	})
	if isText(doc.lore) then
		box:line('cw-tip-lore', esc(doc.lore))
	end
	for _, n in ipairs(copyList(doc.notes)) do
		if isText(n) then
			box:line('cw-tip-note', esc(n))
		end
	end
	return box:html(), name
end

function p.item(frame)
	local args = getArgs(frame)
	local id = args.id or ''
	local data = id ~= '' and load(ITEM_PREFIX .. id) or nil
	if not data or type(data.variants) ~= 'table' or not data.variants[1] then
		return missing(frame, 'stats')
	end
	local html, name = itemBox(data)
	return styles(frame) .. displayTitle(frame, name) .. html
end

-- ============================================================
--  Tab tables and grids
-- ============================================================
-- Each column: label, value(row) -> text or nil, optional sort(row),
-- optional default (a column where every row shows the default is left out),
-- optional varies (left out unless at least two rows differ).
local function block(r) return type(r.block) == 'table' and r.block or {} end
local function food(r) return type(r.food) == 'table' and r.food or {} end
local function armour(r) return type(r.armour) == 'table' and r.armour or {} end
local function melee(r) return type(r.melee) == 'table' and r.melee or {} end
local function weapon(r) return type(r.weapon) == 'table' and r.weapon or {} end

local function damageOf(r)
	local d = melee(r).attackDamage
	return isNum(d) and d or weapon(r).baseDamage
end

local TABLE_COLUMNS = {
	{ label = 'Type', value = function (r) return isText(weapon(r).type) and esc(weapon(r).type) or nil end },
	{ label = 'Rarity',
		value = function (r)
			local name, _, c = rarityOf(r)
			if not name then
				return nil
			end
			return c and ('<span style="color:' .. c .. '">' .. esc(name) .. '</span>') or esc(name)
		end,
		sort = function (r)
			local _, key = rarityOf(r)
			return rarityRank(key)
		end },
	{ label = 'Slot', value = function (r)
		local b = type(r.bauble) == 'table' and r.bauble.slot
		return isText(b) and esc(b) or armourSlot(armour(r).slot)
	end },
	{ label = 'Damage', value = function (r) return numText(damageOf(r)) end, sort = damageOf },
	{ label = 'Attack speed', value = function (r) return numText(melee(r).attackSpeed) end,
		sort = function (r) return melee(r).attackSpeed end },
	{ label = 'Armour', value = function (r) return numText(armour(r).armour) end,
		sort = function (r) return armour(r).armour end },
	{ label = 'Toughness', value = function (r) return numText(armour(r).toughness) end, default = '0',
		sort = function (r) return armour(r).toughness end },
	{ label = 'Hunger', value = function (r) return numText(food(r).hunger) end,
		sort = function (r) return food(r).hunger end },
	{ label = 'Saturation', value = function (r) return numText(saturation(food(r))) end,
		sort = function (r) return saturation(food(r)) end },
	{ label = 'Hardness', value = function (r) return hardness(block(r).hardness) end,
		sort = function (r)
			local h = block(r).hardness
			return isNum(h) and (h < 0 and 1e12 or h) or nil
		end },
	{ label = 'Blast resistance', value = function (r) return numText(block(r).blastResistance) end,
		sort = function (r) return block(r).blastResistance end },
	{ label = 'Tool', value = function (r) return toolText(block(r)) end },
	{ label = 'Light', value = function (r) return positive(block(r).light) end,
		sort = function (r) return block(r).light end },
	{ label = 'Durability', value = function (r) return positive(r.maxDamage) end,
		sort = function (r) return r.maxDamage end },
	{ label = 'Stack', value = function (r) return numText(r.stackSize) end, default = tostring(DEFAULT_STACK), varies = true,
		sort = function (r) return r.stackSize end },
}

local function tabRows(args)
	local key = args.tab or ''
	local data = key ~= '' and load(TAB_PREFIX .. key) or nil
	if not data then
		return nil
	end
	return copyList(data.items), data
end

-- Name cell text: spells link to their spell page, other table items have no page.
local function rowName(r)
	local name = isText(r.name) and r.name or (r.id or '?')
	if isText(r.spellKey) then
		return link(r.id, name)
	end
	return "'''" .. esc(name) .. "'''"
end

function p.itemTable(frame)
	local args = getArgs(frame)
	local rows = tabRows(args)
	if not rows then
		return missing(frame, 'item list')
	end
	if #rows == 0 then
		return styles(frame) .. "''No items yet.''"
	end
	local columns = {}
	for _, col in ipairs(TABLE_COLUMNS) do
		local useful, first, differs = false, nil, false
		for _, r in ipairs(rows) do
			local text = col.value(r)
			if text and text ~= col.default then
				useful = true
			end
			if first == nil then
				first = text or false
			elseif (text or false) ~= first then
				differs = true
			end
		end
		if useful and (differs or not col.varies) then
			columns[#columns + 1] = col
		end
	end
	local tbl = mw.html.create('table'):addClass('wikitable sortable cw-table')
	local head = tbl:tag('tr')
	head:tag('th'):wikitext('Name')
	for _, col in ipairs(columns) do
		head:tag('th'):wikitext(col.label)
	end
	local anchored = {}
	for _, r in ipairs(rows) do
		local tr = tbl:tag('tr')
		-- The first row of an item takes the item's ID as anchor (redirects point at it).
		local anchor = r.id
		if not isText(anchor) or anchored[anchor] then
			anchor = r.key
		end
		if isText(anchor) and not anchored[anchor] then
			anchored[anchor] = true
			tr:attr('id', anchor)
		end
		tr:tag('td'):wikitext(rowName(r))
		for _, col in ipairs(columns) do
			local td = tr:tag('td')
			local text = col.value(r)
			if text then
				td:wikitext(text)
				if col.sort then
					local s = col.sort(r)
					if isNum(s) then
						td:attr('data-sort-value', tostring(s))
					end
				end
			else
				td:addClass('cw-none'):attr('data-sort-value', '-1e15'):wikitext('&ndash;')
			end
		end
	end
	return styles(frame) .. tostring(tbl)
end

-- Group of a grid card: weapon type, bauble slot, armour slot, or none.
local function gridGroup(r)
	if isText(weapon(r).type) then
		return weapon(r).type
	end
	if type(r.bauble) == 'table' and isText(r.bauble.slot) then
		return r.bauble.slot
	end
	return armourSlot(armour(r).slot)
end

local function card(r)
	local rName, _, rColour = rarityOf(r)
	local div = mw.html.create('div'):addClass('cw-card')
	if rColour then
		div:css('border-left-color', rColour)
	end
	local name = isText(r.name) and r.name or r.id
	div:tag('div'):addClass('cw-card-name'):wikitext(link(r.id, name))
	local bits = {}
	if rName then
		bits[#bits + 1] = rColour and ('<span style="color:' .. rColour .. '">' .. esc(rName) .. '</span>') or esc(rName)
	end
	local d = damageOf(r)
	if isNum(d) then
		bits[#bits + 1] = fmt(d) .. ' damage'
	end
	if isNum(armour(r).armour) then
		bits[#bits + 1] = fmt(armour(r).armour) .. ' armour'
	end
	if #bits > 0 then
		div:tag('div'):addClass('cw-card-sub'):wikitext(table.concat(bits, ' &middot; '))
	end
	return div
end

function p.itemGrid(frame)
	local args = getArgs(frame)
	local rows = tabRows(args)
	if not rows then
		return missing(frame, 'item list')
	end
	-- One card per item (variants share a page).
	local seen, items = {}, {}
	for _, r in ipairs(rows) do
		if isText(r.id) and not seen[r.id] then
			seen[r.id] = true
			items[#items + 1] = r
		end
	end
	if #items == 0 then
		return styles(frame) .. "''No items yet.''"
	end
	local groups, order = {}, {}
	for _, r in ipairs(items) do
		local g = gridGroup(r) or ''
		if not groups[g] then
			groups[g] = {}
			order[#order + 1] = g
		end
		table.insert(groups[g], r)
	end
	table.sort(order, function (a, b)
		if a == '' or b == '' then
			return b == ''
		end
		return a < b
	end)
	local root = mw.html.create('div'):addClass('cw-grid-wrap')
	root:tag('div'):addClass('cw-count'):wikitext(#items .. (#items == 1 and ' item' or ' items'))
	for _, g in ipairs(order) do
		local list = groups[g]
		table.sort(list, function (a, b)
			local _, ka = rarityOf(a)
			local _, kb = rarityOf(b)
			local ra, rb = rarityRank(ka), rarityRank(kb)
			if ra ~= rb then
				return ra < rb
			end
			return tostring(a.name or a.id) < tostring(b.name or b.id)
		end)
		if #order > 1 then
			root:tag('div'):addClass('cw-group'):wikitext(g == '' and 'Other' or esc(g))
		end
		local grid = root:tag('div'):addClass('cw-grid')
		for _, r in ipairs(list) do
			grid:node(card(r))
		end
	end
	return styles(frame) .. tostring(root)
end

-- ============================================================
--  Spells
-- ============================================================
local function spellTier(key)
	return SPELL_TIERS[key] or { titleCase(key) or '?', nil, 99 }
end

-- Display name of a spell: its item's name, else the key split into words.
local function spellName(s)
	local path = itemPath(s.itemId)
	local data = path and load(ITEM_PREFIX .. path) or nil
	local v = data and type(data.variants) == 'table' and data.variants[1] or nil
	if v and isText(v.name) then
		return v.name
	end
	return isText(s.key) and splitCamel(s.key) or '?'
end

local function findSpell(key)
	local all = load(SPELLS_PAGE)
	if not all or not isText(key) then
		return nil
	end
	local want = string.lower(key)
	for _, s in ipairs(all) do
		if type(s) == 'table' and isText(s.key) and string.lower(s.key) == want then
			return s
		end
	end
	return nil
end

local function spellRows(s)
	return {
		{ 'Element', titleCase(s.element) },
		{ 'School', titleCase(s.school) },
		{ 'Type', SPELL_TYPES[s.type] or titleCase(s.type) },
		{ 'Mana cost', numText(s.manaCost) },
		{ 'Damage', positive(s.baseDamage) },
		{ 'Uses before burnout', positive(s.uses) },
		{ 'Charge time', positive(s.chargeSeconds, 's') },
		{ 'Burnout', positive(s.burnoutSeconds, 's') },
		{ 'Cooldown', positive(s.cooldownSeconds, 's') },
	}
end

function p.spell(frame)
	local args = getArgs(frame)
	local s = findSpell(args.key)
	if not s then
		return missing(frame, 'spell stats')
	end
	local tier = spellTier(s.tier)
	local name = spellName(s)
	local box = newBox(ELEMENT_COLOURS[s.element] or tier[2])
	box:title(name, tier[2] or '#FFFFFF')
	box:line('cw-tip-sub', esc(tier[1] .. ' spell'), tier[2])
	box:section('Spell', spellRows(s))
	return styles(frame) .. displayTitle(frame, name) .. box:html()
end

function p.spellTable(frame)
	local all = load(SPELLS_PAGE)
	if not all then
		return missing(frame, 'spell list')
	end
	local spells = {}
	for _, s in ipairs(all) do
		if type(s) == 'table' then
			spells[#spells + 1] = s
		end
	end
	if #spells == 0 then
		return styles(frame) .. "''No spells yet.''"
	end
	local names = {}
	for i, s in ipairs(spells) do
		names[s] = i <= MAX_SPELL_ITEMS and spellName(s) or (isText(s.key) and splitCamel(s.key) or '?')
	end
	table.sort(spells, function (a, b)
		local ta, tb = spellTier(a.tier)[3], spellTier(b.tier)[3]
		if ta ~= tb then
			return ta < tb
		end
		return names[a] < names[b]
	end)
	local tbl = mw.html.create('table'):addClass('wikitable sortable cw-table')
	local head = tbl:tag('tr')
	for _, h in ipairs({ 'Spell', 'Tier', 'Element', 'School', 'Type', 'Mana', 'Damage', 'Uses', 'Charge', 'Burnout', 'Cooldown' }) do
		head:tag('th'):wikitext(h)
	end
	local function cell(tr, text, sort)
		local td = tr:tag('td')
		if text then
			td:wikitext(text)
			if isNum(sort) then
				td:attr('data-sort-value', tostring(sort))
			end
		else
			td:addClass('cw-none'):attr('data-sort-value', '-1e15'):wikitext('&ndash;')
		end
	end
	for _, s in ipairs(spells) do
		local tr = tbl:tag('tr')
		local tier = spellTier(s.tier)
		local path = itemPath(s.itemId)
		cell(tr, path and link(path, names[s]) or esc(names[s]))
		cell(tr, tier[2] and ('<span style="color:' .. tier[2] .. '">' .. esc(tier[1]) .. '</span>') or esc(tier[1]), tier[3])
		cell(tr, titleCase(s.element))
		cell(tr, titleCase(s.school))
		cell(tr, SPELL_TYPES[s.type] or titleCase(s.type))
		cell(tr, numText(s.manaCost), s.manaCost)
		cell(tr, positive(s.baseDamage), s.baseDamage)
		cell(tr, positive(s.uses), s.uses)
		cell(tr, positive(s.chargeSeconds, 's'), s.chargeSeconds)
		cell(tr, positive(s.burnoutSeconds, 's'), s.burnoutSeconds)
		cell(tr, positive(s.cooldownSeconds, 's'), s.cooldownSeconds)
	end
	return styles(frame) .. tostring(tbl)
end

-- ============================================================
--  Classes
-- ============================================================
function p.classList(frame)
	local all = load(CLASSES_PAGE)
	if not all then
		return missing(frame, 'class list')
	end
	local root = mw.html.create('div'):addClass('cw-grid cw-classes')
	local any = false
	for _, a in ipairs(all) do
		if type(a) == 'table' and isText(a.name) then
			any = true
			local c = root:tag('div'):addClass('cw-card cw-class')
			c:tag('div'):addClass('cw-card-name'):wikitext(classLink(a.key, a.name))
			local list = c:tag('ul')
			for _, s in ipairs(copyList(a.subclasses)) do
				if type(s) == 'table' and isText(s.name) then
					list:tag('li'):wikitext(classLink(s.key, s.name))
				end
			end
		end
	end
	if not any then
		return styles(frame) .. "''No classes yet.''"
	end
	return styles(frame) .. tostring(root)
end

-- The archetype (and subclass, if the key is one) for a class key.
local function findClass(key)
	local all = load(CLASSES_PAGE)
	if not all or not isText(key) then
		return nil
	end
	local want = string.lower(string.gsub(key, ' ', '_'))
	for _, a in ipairs(all) do
		if type(a) == 'table' then
			if isText(a.key) and string.lower(a.key) == want then
				return a, nil
			end
			for _, s in ipairs(copyList(a.subclasses)) do
				if type(s) == 'table' and isText(s.key) and string.lower(s.key) == want then
					return a, s
				end
			end
		end
	end
	return nil
end

function p.classPage(frame)
	local args = getArgs(frame)
	local archetype, sub = findClass(args.key)
	if not archetype then
		return missing(frame, 'class details')
	end
	local name = sub and sub.name or archetype.name
	local box = newBox(nil)
	box:title(name, '#FFFFFF')
	local rows = {}
	if sub then
		box:line('cw-tip-sub', 'Subclass')
		rows[#rows + 1] = { 'Class', classLink(archetype.key, archetype.name) }
		local others = {}
		for _, s in ipairs(copyList(archetype.subclasses)) do
			if type(s) == 'table' and s.key ~= sub.key and isText(s.name) then
				others[#others + 1] = classLink(s.key, s.name)
			end
		end
		rows[#rows + 1] = { 'Other subclasses', #others > 0 and table.concat(others, ', ') or nil }
	else
		box:line('cw-tip-sub', 'Class')
		local subs = {}
		for _, s in ipairs(copyList(archetype.subclasses)) do
			if type(s) == 'table' and isText(s.name) then
				subs[#subs + 1] = classLink(s.key, s.name)
			end
		end
		rows[#rows + 1] = { 'Subclasses', #subs > 0 and table.concat(subs, ', ') or nil }
	end
	box:section(nil, rows)
	return styles(frame) .. displayTitle(frame, name) .. box:html()
end

-- ============================================================
--  Systems
-- ============================================================
-- Value with its unit, the same way {{V}} shows it.
local function withUnit(text, unit)
	if not isText(unit) then
		return text
	end
	local first = string.sub(unit, 1, 1)
	if unit == '%' or unit == 'x' or first == '/' then
		return text .. unit
	end
	return text .. ' ' .. unit
end

-- Plain text into paragraphs (blank lines split them), escaped.
local function paragraphs(node, text)
	for _, para in ipairs(mw.text.split(text, '\n%s*\n')) do
		para = trim(para)
		if para ~= '' then
			node:tag('p'):wikitext((string.gsub(esc(para), '\n', '<br>')))
		end
	end
end

function p.systemDoc(frame)
	local args = getArgs(frame)
	local id = args.id or ''
	local d = id ~= '' and load(SYSTEM_PREFIX .. id) or nil
	if not d then
		return missing(frame, 'system details')
	end
	local root = mw.html.create('div'):addClass('cw-system')
	if isText(d.summary) then
		paragraphs(root:tag('div'):addClass('cw-summary'), d.summary)
	end
	for _, s in ipairs(copyList(d.sections)) do
		if type(s) == 'table' then
			if isText(s.title) then
				root:tag('div'):addClass('cw-group'):wikitext(esc(s.title))
			end
			if isText(s.body) then
				paragraphs(root, s.body)
			end
		end
	end
	local formulas = copyList(d.formulas)
	if #formulas > 0 then
		root:tag('div'):addClass('cw-group'):wikitext('Formulas')
		local tbl = root:tag('table'):addClass('wikitable cw-table')
		local head = tbl:tag('tr')
		head:tag('th'):wikitext('Name')
		head:tag('th'):wikitext('Formula')
		for _, f in ipairs(formulas) do
			if type(f) == 'table' then
				local tr = tbl:tag('tr')
				tr:tag('td'):wikitext(esc(f.name or ''))
				tr:tag('td'):tag('code'):wikitext(esc(f.expression or ''))
			end
		end
	end
	local values = copyList(d.values)
	if #values > 0 then
		root:tag('div'):addClass('cw-group'):wikitext('Current values')
		local tbl = root:tag('table'):addClass('wikitable cw-table')
		local head = tbl:tag('tr')
		head:tag('th'):wikitext('Value')
		head:tag('th'):wikitext('Now')
		head:tag('th'):wikitext('Use in an article')
		for _, v in ipairs(values) do
			if type(v) == 'table' then
				local tr = tbl:tag('tr')
				tr:tag('td'):wikitext(esc(v.label or ''))
				tr:tag('td'):wikitext(isNum(v.value) and esc(withUnit(fmt(v.value), v.unit)) or "''unreadable''")
				local code = tr:tag('td')
				if isText(v.var) then
					code:tag('code'):wikitext(esc('{{V|' .. v.var .. '}}'))
				end
			end
		end
	end
	return styles(frame) .. displayTitle(frame, d.title) .. tostring(root)
end

return p
