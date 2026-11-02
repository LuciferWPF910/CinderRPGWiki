-- Module:Map/types
-- Marker types for {{Map marker}}. Each type gets one entry in the map's
-- filter list, in the order below. Add a line to add a type:
--   key = { label = 'Name in the filter list', icon = 'Uploaded file.png' },
-- Types without an icon show a coloured dot instead (colour = '#rrggbb').
-- A marker can also use a type that is not listed here: give it icon= and
-- label= on the marker itself.

return {
	order = {
		'chest', 'sack', 'platsilver', 'rubysilver', 'bellflower', 'scarlet', 'mushroom',
		'ester', 'soulgem', 'mob', 'boss', 'dungeon', 'obelisk', 'quest', 'town', 'poi',
	},
	types = {
		chest      = { label = 'Chest', icon = 'item.crate_chest.png' },
		sack       = { label = 'Woven Sack', icon = 'item.woven_sack.png' },
		platsilver = { label = 'Platsilver Node', icon = 'ingredient.silver_ore.png' },
		rubysilver = { label = 'Rubysilver Node', icon = 'ingredient.rubysilver_ore.png' },
		bellflower = { label = 'Bell Flower', icon = 'ingredient.bell_flower.png' },
		scarlet    = { label = 'Scarlet Bulb', icon = 'ingredient.scarletbulb_flower.png' },
		mushroom   = { label = 'Redcap Mushroom', icon = 'ingredient.redcap_mushroom.png' },
		ester      = { label = 'Ester Berry', icon = 'ingredient.esterberries.png' },
		soulgem    = { label = 'Soul Gem', icon = 'ingredient.soulgem.png' },
		mob        = { label = 'Mob Spot', icon = 'ingredient.monster_wing.png' },
		boss       = { label = 'Boss', colour = '#E53935' },
		dungeon    = { label = 'Dungeon Entrance', icon = 'item.gemmed_key.png' },
		obelisk    = { label = 'Obelisk', icon = 'item.ritual_rune.png' },
		quest      = { label = 'Quest', icon = 'item.quest_letter.png' },
		town       = { label = 'Town', colour = '#BFA06F' },
		poi        = { label = 'Point of Interest', colour = '#4FC3F7' },
	},
	-- Other names editors might type for the same type.
	aliases = {
		miniboss = 'mob', mobspot = 'mob', mobs = 'mob', woven = 'sack', wovensack = 'sack',
		silver = 'platsilver', ruby = 'rubysilver', berry = 'ester', esterberry = 'ester',
		key = 'dungeon', entrance = 'dungeon', rune = 'obelisk', village = 'town', city = 'town',
		redcap = 'mushroom', bell = 'bellflower',
	},
}
