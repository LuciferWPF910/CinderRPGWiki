-- Module:Vars
-- Live values from the Cinder mod, used by {{V|...}} and [[Project:Variables]].
-- The data pages (Data:Vars/..., Data:Item/..., Data:Spells) are written by the
-- CinderWiki sync and cannot be edited by hand.
--
--   {{V|food.slots}}                 the value with its unit
--   {{V|food.keg.duration|unit=no}}  the value without its unit
--   {{V|food.keg.duration|raw=1}}    the exact number from the code
--   {{V|item.ashenblade.damage}}     an item stat, read from Data:Item/ashenblade
--   {{V|item.thatch@2.hardness}}     a stat of one item variant
--   {{V|spell.firebolt.mana}}        a spell stat, read from Data:Spells
--
-- Names ignore capitals. A name that does not exist shows a red message with
-- the closest match, and puts the article in [[Category:Pages with unknown variables]].
--
-- Data from mw.loadJsonData is read-only: use pairs/ipairs on it, never # or
-- the table library.

local p = {}

-- ============================================================
--  Settings (titles must match CinderWiki PageBuilder)
-- ============================================================
local VARS_PREFIX     = 'Data:Vars/'
local VARS_INDEX      = 'Data:Vars'
local ITEM_PREFIX     = 'Data:Item/'
local SPELLS_PAGE     = 'Data:Spells'
local SYSTEM_PREFIX   = 'System/'
local LIST_PAGE       = 'Project:Variables'
local CAT_UNKNOWN     = 'Pages with unknown variables'
local CAT_REMOVED     = 'Pages with removed variables'
local CAT_UNREADABLE  = 'Pages with unreadable variables'
local CATEGORY_NAMESPACES = { [0] = true }  -- only articles go in the tracking categories
local MAX_NAME        = 120   -- longest name accepted
local MAX_CANDIDATES  = 1000  -- names compared when suggesting a fix (keeps typos cheap)
local MAX_ID_PARTS    = 3     -- item IDs containing dots: parts tried
local STAT_DECIMALS   = 2     -- item and spell stats

-- Item stat shortcuts: the first path that exists on the item is used.
local ITEM_SHORTCUTS = {
	damage      = { 'weapon.baseDamage', 'ranged.damage', 'melee.attackDamage' },
	speed       = { 'melee.attackSpeed' },
	dps         = { 'ranged.sustainedDps' },
	magazine    = { 'ranged.magazine' },
	reload      = { 'ranged.reload' },
	projectiles = { 'ranged.projectiles' },
	armour      = { 'armour.armour' },
	armor       = { 'armour.armour' },
	toughness   = { 'armour.toughness' },
	hunger      = { 'food.hunger' },
	saturation  = { 'food.saturation' },
	durability  = { 'maxDamage' },
	stack       = { 'stackSize' },
	rarity      = { 'weapon.rarity', 'bauble.rarity' },
	type        = { 'weapon.type' },
	slot        = { 'bauble.slot', 'armour.slot' },
	hardness    = { 'block.hardness' },
	name        = { 'name' },
}

-- Spell stat shortcuts.
local SPELL_SHORTCUTS = {
	mana     = 'manaCost',
	damage   = 'baseDamage',
	cooldown = 'cooldownSeconds',
	charge   = 'chargeSeconds',
	burnout  = 'burnoutSeconds',
}

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

-- Letters, digits and _ . - @ ~ only (checked on the lower-cased name).
local function validName(s)
	if s == '' or #s > MAX_NAME then
		return false
	end
	for i = 1, #s do
		local b = string.byte(s, i)
		local ok = (b >= 48 and b <= 57) or (b >= 97 and b <= 122) or b == 95 or b == 46 or b == 45 or b == 64 or b == 126
		if not ok then
			return false
		end
	end
	return true
end

-- 'food.keg.duration' -> 'food', 'keg.duration'
local function splitFirst(s)
	local dot = string.find(s, '.', 1, true)
	if not dot then
		return s, nil
	end
	return string.sub(s, 1, dot - 1), string.sub(s, dot + 1)
end

-- Sorted keys of any table (works on read-only data). Keys are compared as
-- text, because the wiki's JSON turns an all-digit key into a number.
local function sortedKeys(t)
	local keys = {}
	if t then
		for k in pairs(t) do
			keys[#keys + 1] = k
		end
	end
	table.sort(keys, function (a, b) return tostring(a) < tostring(b) end)
	return keys
end

-- Number with at most STAT_DECIMALS decimals, no trailing zeros.
local function formatNumber(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return '?'
	end
	local s = string.format('%.' .. STAT_DECIMALS .. 'f', n)
	if string.find(s, '.', 1, true) then
		while string.sub(s, -1) == '0' do
			s = string.sub(s, 1, -2)
		end
		if string.sub(s, -1) == '.' then
			s = string.sub(s, 1, -2)
		end
	end
	if s == '-0' then
		s = '0'
	end
	return s
end

-- A single stat as text, or nil if it is missing or not a single value.
local function formatValue(v, raw)
	local t = type(v)
	if t == 'number' then
		return raw and tostring(v) or formatNumber(v)
	elseif t == 'boolean' then
		return v and 'Yes' or 'No'
	elseif t == 'string' then
		return v
	end
	return nil
end

-- Edit distance, giving up once it is over limit.
local function distance(a, b, limit)
	local la, lb = #a, #b
	if math.abs(la - lb) > limit then
		return limit + 1
	end
	local prev = {}
	for j = 0, lb do
		prev[j] = j
	end
	for i = 1, la do
		local cur = { [0] = i }
		local best = i
		local ca = string.byte(a, i)
		for j = 1, lb do
			local cost = (ca == string.byte(b, j)) and 0 or 1
			local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
			cur[j] = v
			if v < best then
				best = v
			end
		end
		if best > limit then
			return limit + 1
		end
		prev = cur
	end
	return prev[lb]
end

-- 'food.keg.duration' -> 'food.keg.'
local function parentOf(s)
	local last
	local from = 1
	while true do
		local dot = string.find(s, '.', from, true)
		if not dot then
			break
		end
		last = dot
		from = dot + 1
	end
	return last and string.sub(s, 1, last) or ''
end

-- The closest candidate to target, or nil if none is close enough. Names
-- that share target's parent ('food.keg.') are compared first, and at most
-- MAX_CANDIDATES are compared in total.
local function closest(target, candidates)
	local limit = math.max(2, math.floor(#target / 4))
	local parent = parentOf(target)
	local near, far = {}, {}
	for _, c in ipairs(candidates) do
		if parent ~= '' and string.sub(c, 1, #parent) == parent then
			near[#near + 1] = c
		else
			far[#far + 1] = c
		end
	end
	local bestName, bestDist = nil, limit + 1
	local checked = 0
	for _, list in ipairs({ near, far }) do
		for _, c in ipairs(list) do
			checked = checked + 1
			if checked > MAX_CANDIDATES then
				return bestName
			end
			local d = distance(target, c, limit)
			if d < bestDist then
				bestName, bestDist = c, d
			end
		end
	end
	return bestName
end

-- Case-insensitive field lookup (field is lower case).
local function getField(t, field)
	if type(t) ~= 'table' then
		return nil
	end
	local v = t[field]
	if v ~= nil then
		return v
	end
	for k, val in pairs(t) do
		if type(k) == 'string' and string.lower(k) == field then
			return val
		end
	end
	return nil
end

-- 'weapon.baseDamage' on an item entry.
local function getPath(t, path)
	local cur = t
	for _, part in ipairs(mw.text.split(path, '.', true)) do
		cur = getField(cur, string.lower(part))
		if cur == nil then
			return nil
		end
	end
	return cur
end

local function esc(s)
	return mw.text.nowiki(tostring(s))
end

local function attr(s)
	return mw.text.encode(tostring(s))
end

local function category(name)
	local title = mw.title.getCurrentTitle()
	if title and CATEGORY_NAMESPACES[title.namespace] then
		return '[[Category:' .. name .. ']]'
	end
	return ''
end

local function message(text, cat)
	return '<strong class="error cw-var-error">' .. text .. '</strong>' .. category(cat or CAT_UNKNOWN)
end

local function unknown(name, suggestion)
	local text = 'Unknown variable ' .. esc(name) .. '.'
	if suggestion then
		text = text .. ' Did you mean <code>' .. esc(suggestion) .. '</code>?'
	end
	return message(text .. ' See [[' .. LIST_PAGE .. '|the list]].')
end

local function show(name, text, classes, cat)
	local out = '<span class="' .. classes .. '" data-var="' .. attr(name) .. '">' .. esc(text) .. '</span>'
	if cat then
		out = out .. category(cat)
	end
	return out
end

-- ============================================================
--  Mod variables (Data:Vars/<group> and Data:Vars/<group>/<part>)
-- ============================================================

-- Page key of a name: its first two parts when it has three or more
-- ('weapon.ashenblade.damage' -> 'weapon.ashenblade'), else its group
-- ('food.slots' -> 'food'). Same rule as CinderWiki and CE2 WikiVars.
local function pageKey(key)
	local group, rest = splitFirst(key)
	if not rest then
		return group
	end
	local second, more = splitFirst(rest)
	if not more then
		return group
	end
	return group .. '.' .. second
end

-- 'weapon.ashenblade' -> 'Data:Vars/weapon/ashenblade'
local function pageTitle(pk)
	local group, second = splitFirst(pk)
	return VARS_PREFIX .. group .. (second and ('/' .. second) or '')
end

-- entry, resolved key, data page (page is set even when the name is missing)
local function findVar(key)
	local page = load(pageTitle(pageKey(key)))
	if not page then
		return nil, nil, nil
	end
	local vars = page.vars
	local entry = vars and vars[key]
	if entry then
		return entry, key, page
	end
	local target = page.aliases and page.aliases[key]
	if target then
		local tpage = load(pageTitle(pageKey(target)))
		local te = tpage and tpage.vars and tpage.vars[target]
		if te then
			return te, target, page
		end
	end
	return nil, nil, page
end

-- Closest name on one data page, by its proper (capitalised) name.
local function closestOnPage(key, page)
	local candidates = sortedKeys(page.vars)
	for _, a in ipairs(sortedKeys(page.aliases)) do
		candidates[#candidates + 1] = a
	end
	local s = closest(key, candidates)
	local e = s and page.vars and page.vars[s]
	return (e and e.name) or s
end

-- The name is a data page itself ('weapon.kikoku', 'food.keg'): suggest a
-- stat on it (damage if it has one, else the first).
local function suggestOwn(key, index)
	local own = index and index.pages and index.pages[key] and load(pageTitle(key))
	if not own or not own.vars then
		return nil
	end
	local damage = own.vars[key .. '.damage']
	if damage then
		return damage.name or (key .. '.damage')
	end
	local first = sortedKeys(own.vars)[1]
	return first and (own.vars[first].name or first) or nil
end

-- Suggestion when the name's own data page does not exist.
local function suggestElsewhere(key, group, rest, index)
	-- The page part is misspelt ('weapon.ashenblad.damage'): find the
	-- closest page in the group, then the closest name on it.
	local pk = pageKey(key)
	if pk ~= group then
		local pages = {}
		for _, k in ipairs(sortedKeys(index and index.pages)) do
			if string.sub(k, 1, #group + 1) == group .. '.' then
				pages[#pages + 1] = k
			end
		end
		local near = closest(pk, pages)
		if near then
			local fixed = near .. string.sub(key, #pk + 1)
			local npage = load(pageTitle(near))
			return (npage and closestOnPage(fixed, npage)) or fixed
		end
	end
	-- The group is misspelt ('wepon.ashenblade.damage').
	local groups = { 'item', 'spell' }
	for _, g in ipairs(sortedKeys(index and index.groups)) do
		groups[#groups + 1] = g
	end
	table.sort(groups, function (a, b) return tostring(a) < tostring(b) end)
	local g = closest(group, groups)
	return g and (g .. '.' .. rest) or nil
end

local function suggestVar(key, group, rest, page)
	local index = load(VARS_INDEX)
	local s = suggestOwn(key, index)
	if not s then
		if page then
			s = closestOnPage(key, page)
		else
			s = suggestElsewhere(key, group, rest, index)
		end
	end
	-- Never suggest exactly what was typed.
	if s and string.lower(s) == key then
		return nil
	end
	return s
end

local function varValue(name, key, group, rest, opts)
	local e, resolved, page = findVar(key)
	if not e then
		return unknown(name, suggestVar(key, group, rest, page))
	end
	local text
	if opts.raw and e.value ~= nil then
		text = formatValue(e.value, true)
	elseif opts.noUnit then
		text = e.plain or e.display
	else
		text = e.display
	end
	local classes, cat = 'cw-var', nil
	if e.removed then
		classes, cat = 'cw-var cw-var-removed', CAT_REMOVED
	elseif e.error then
		classes, cat = (e.stale and 'cw-var cw-var-stale' or 'cw-var cw-var-error'), CAT_UNREADABLE
	end
	return show(e.name or resolved, text or '?', classes, cat)
end

-- ============================================================
--  Item and spell stats
-- ============================================================
-- Finds the item page for 'ashenblade.damage' (or 'odd.id.damage' when the
-- ID itself contains dots): id, variant key or nil, field, data.
local function findItem(rest)
	local parts = mw.text.split(rest, '.', true)
	local first = parts[1]
	local tries = math.min(MAX_ID_PARTS, #parts - 1)
	for n = 1, tries do
		local id = parts[1]
		for i = 2, n do
			id = id .. '.' .. parts[i]
		end
		local field = parts[n + 1]
		for i = n + 2, #parts do
			field = field .. '.' .. parts[i]
		end
		local variant
		local at = string.find(id, '@', 1, true)
		if at then
			variant = id
			id = string.sub(id, 1, at - 1)
		end
		local data = load(ITEM_PREFIX .. id)
		if data and data.variants then
			return id, variant, field, data
		end
	end
	return first, nil, nil, nil
end

local function itemValue(name, rest, opts)
	local id, variant, field, data = findItem(rest)
	if not string.find(rest, '.', 1, true) then
		return message('Say which stat of ' .. esc(id) .. ' to show, for example <code>' .. esc('item.' .. id .. '.damage') .. '</code>.')
	end
	if not data then
		return message('No item called ' .. esc(id) .. ' on the wiki. Use the ID from the end of its page address.')
	end
	local entry
	for _, v in ipairs(data.variants) do
		if variant then
			if v.key and string.lower(v.key) == variant then
				entry = v
				break
			end
		else
			entry = v
			break
		end
	end
	if not entry then
		return message('Item ' .. esc(id) .. ' has no variant ' .. esc(variant) .. '.')
	end
	local value
	local paths = ITEM_SHORTCUTS[field]
	if paths then
		for _, path in ipairs(paths) do
			value = getPath(entry, path)
			if value ~= nil then
				break
			end
		end
	else
		value = getPath(entry, field)
	end
	local text = formatValue(value, opts.raw)
	if not text then
		local works = {}
		for _, s in ipairs(sortedKeys(ITEM_SHORTCUTS)) do
			for _, path in ipairs(ITEM_SHORTCUTS[s]) do
				if formatValue(getPath(entry, path)) then
					works[#works + 1] = s
					break
				end
			end
		end
		local text2 = 'Item ' .. esc(id) .. ' has no stat ' .. esc(field) .. '.'
		if #works > 0 then
			text2 = text2 .. ' Try: ' .. esc(table.concat(works, ', ')) .. '.'
		end
		return message(text2)
	end
	return show(name, text, 'cw-var', nil)
end

local function spellValue(name, rest, opts)
	local key, field = splitFirst(rest)
	if not field or field == '' then
		return message('Say which stat of ' .. esc(key) .. ' to show, for example <code>' .. esc('spell.' .. key .. '.mana') .. '</code>.')
	end
	local spells = load(SPELLS_PAGE)
	local spell
	local keys = {}
	if spells then
		for _, s in ipairs(spells) do
			if type(s.key) == 'string' then
				local k = string.lower(s.key)
				keys[#keys + 1] = k
				if k == key then
					spell = s
				end
			end
		end
	end
	if not spell then
		table.sort(keys)
		local s = closest(key, keys)
		return unknown(name, s and ('spell.' .. s .. '.' .. field) or nil)
	end
	local text = formatValue(getPath(spell, SPELL_SHORTCUTS[field] or field), opts.raw)
	if not text then
		return message('Spell ' .. esc(key) .. ' has no stat ' .. esc(field) .. '. Try: ' .. esc(table.concat(sortedKeys(SPELL_SHORTCUTS), ', ')) .. '.')
	end
	return show(name, text, 'cw-var', nil)
end

-- ============================================================
--  {{V|...}}
-- ============================================================
local function yes(v)
	v = string.lower(trim(v))
	return v == '1' or v == 'yes' or v == 'y' or v == 'true'
end

local function no(v)
	v = string.lower(trim(v))
	return v == '0' or v == 'no' or v == 'n' or v == 'false'
end

function p._get(rawName, opts)
	opts = opts or {}
	local name = trim(rawName)
	if name == '' then
		return message('No variable name given. Use <code>' .. esc('{{V|name}}') .. '</code>.')
	end
	local key = string.lower(name)
	if not validName(key) then
		return unknown(name, nil)
	end
	local group, rest = splitFirst(key)
	if not rest or rest == '' then
		return unknown(name, nil)
	end
	if group == 'item' then
		return itemValue(name, rest, opts)
	elseif group == 'spell' then
		return spellValue(name, rest, opts)
	end
	return varValue(name, key, group, rest, opts)
end

function p.get(frame)
	local args = frame.args
	if trim(args[1]) == '' then
		local parent = frame:getParent()
		if parent then
			args = parent.args
		end
	end
	return p._get(args[1], { raw = yes(args.raw), noUnit = no(args.unit) })
end

-- ============================================================
--  [[Project:Variables]]: {{#invoke:Vars|list}}
-- ============================================================
local function systemCell(id, known)
	if not id then
		return ''
	end
	if known[id] == nil then
		local t = mw.title.new(SYSTEM_PREFIX .. id)
		known[id] = (t and t.exists) and true or false
	end
	if known[id] then
		return '[[' .. SYSTEM_PREFIX .. id .. '|' .. esc(id) .. ']]'
	end
	return esc(id)
end

local function codeCell(name)
	return '<code class="cw-vars-code">' .. esc('{{V|' .. name .. '}}') .. '</code>'
end

local function rawCell(e)
	if e.value == nil then
		return '?'
	end
	return esc(formatValue(e.value, true) or '?')
end

local function varRows(add, page, keys, known)
	for _, k in ipairs(keys) do
		local e = page.vars[k]
		local name = e.name or k
		local shows = esc(e.display or '?')
		if e.error then
			shows = shows .. (e.stale and " ''(last value; could not be read)''" or " ''(could not be read)''")
		end
		add('|-')
		add('| ' .. esc(name) .. ' || ' .. shows .. ' || ' .. rawCell(e) .. ' || ' .. systemCell(e.system, known)
			.. ' || ' .. esc(e.desc or '') .. ' || ' .. codeCell(name))
	end
end

local function itemHelp(add)
	add('== Item and spell stats ==')
	add('Any item or spell stat can be shown without being listed above. Use the item ID (the end of its page address) or the spell key:')
	add('* <code>' .. esc('{{V|item.ashenblade.damage}}') .. '</code>')
	add('* <code>' .. esc('{{V|spell.firebolt.mana}}') .. '</code>')
	add('* For one variant of an item, add <code>@</code> and the variant: <code>' .. esc('{{V|item.thatch@2.hardness}}') .. '</code>')
	add('* Any field on the item\'s data page works too, for example <code>' .. esc('{{V|item.ashenblade.ranged.reload}}') .. '</code>')
	add('{| class="wikitable"')
	add('! Item stat !! Reads (first one the item has)')
	for _, s in ipairs(sortedKeys(ITEM_SHORTCUTS)) do
		add('|-')
		add('| <code>' .. s .. '</code> || ' .. esc(table.concat(ITEM_SHORTCUTS[s], ', ')))
	end
	add('|}')
	add('{| class="wikitable"')
	add('! Spell stat !! Reads')
	for _, s in ipairs(sortedKeys(SPELL_SHORTCUTS)) do
		add('|-')
		add('| <code>' .. s .. '</code> || ' .. esc(SPELL_SHORTCUTS[s]))
	end
	add('|}')
end

-- Every variable on the given data pages, as one table (plus removed and old names).
local function groupTables(add, pages, known)
	local current, removed, aliases = {}, {}, {}
	for _, page in ipairs(pages) do
		for _, k in ipairs(sortedKeys(page.vars)) do
			local row = { key = k, page = page }
			if page.vars[k].removed then
				removed[#removed + 1] = row
			else
				current[#current + 1] = row
			end
		end
		for _, a in ipairs(sortedKeys(page.aliases)) do
			aliases[#aliases + 1] = { old = a, new = page.aliases[a] }
		end
	end
	local byKey = function (x, y) return x.key < y.key end
	table.sort(current, byKey)
	table.sort(removed, byKey)
	table.sort(aliases, function (x, y) return x.old < y.old end)
	if #current > 0 then
		add('{| class="wikitable sortable cw-vars-table"')
		add('! Variable !! Shows !! Raw value !! System !! Description !! Code')
		for _, row in ipairs(current) do
			varRows(add, row.page, { row.key }, known)
		end
		add('|}')
	end
	if #removed > 0 then
		add("'''Removed from the mod''' (still shown with their last value; please update pages that use them):")
		add('{| class="wikitable sortable cw-vars-table"')
		add('! Variable !! Last value !! Removed on !! Description')
		for _, row in ipairs(removed) do
			local e = row.page.vars[row.key]
			add('|-')
			add('| ' .. esc(e.name or row.key) .. ' || ' .. esc(e.display or '?') .. ' || ' .. esc(e.removed) .. ' || ' .. esc(e.desc or ''))
		end
		add('|}')
	end
	if #aliases > 0 then
		add("'''Old names that still work:'''")
		for _, a in ipairs(aliases) do
			add('* <code>' .. esc(a.old) .. '</code> now shows <code>' .. esc(a.new) .. '</code>')
		end
	end
	return #current + #removed + #aliases
end

-- {{#invoke:Vars|list}}: every group, with a link to its own list.
-- {{#invoke:Vars|list|group=weapon}}: every variable in one group.
function p.list(frame)
	local out = {}
	local function add(s)
		out[#out + 1] = s
	end
	local known = {}
	local index = load(VARS_INDEX)
	local want = string.lower(trim(frame and frame.args and frame.args.group))
	local groups = sortedKeys(index and index.groups)
	if #groups == 0 then
		add("''No variables have been published yet. They appear after the next wiki sync.''")
	end
	if want == '' then
		if #groups > 0 then
			add('== Groups ==')
			add('{| class="wikitable sortable"')
			add('! Group !! Variables !! List')
			for _, g in ipairs(groups) do
				local gi = index.groups[g]
				add('|-')
				add('| <code>' .. esc(g) .. '</code> || ' .. esc(formatNumber(gi.count or 0)) .. ' || [[' .. LIST_PAGE .. '/' .. g .. '|Open the ' .. esc(g) .. ' list]]')
			end
			add('|}')
		end
		itemHelp(add)
		return table.concat(out, '\n')
	end
	add('<div class="cw-vars-filter"></div>')
	local pages = {}
	for _, pk in ipairs(sortedKeys(index and index.pages)) do
		if pk == want or string.sub(pk, 1, #want + 1) == want .. '.' then
			local page = load(pageTitle(pk))
			if page then
				pages[#pages + 1] = page
			end
		end
	end
	if groupTables(add, pages, known) == 0 and #groups > 0 then
		add("''There is no group called " .. esc(want) .. ". See [[" .. LIST_PAGE .. "|all groups]].''")
	end
	return table.concat(out, '\n')
end

return p
