require "util"
local Class = require "class"
local images = require "images"
local sounds = require "data.sounds"

-- Help. If you are the poor sod sent to modify the code within 
-- this, be warned: it's a fucking mess.

local MenuItem = Class:inherit()
function MenuItem:init_menuitem(i, x, y)
	self.i = i
	self.x = x
	self.y = y

	self.is_selected = false
end

function MenuItem:update_menuitem(dt)

end

function MenuItem:on_click()
end

------------

local TextMenuItem = MenuItem:inherit()

-- Split into SelectableMenuItem ? Am I becoming a Java dev now?
-- THIS IS A MESS, *HELP*
-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAA
-- Should do:
-- MenuItem
-- -> TextMenuItem
-- -> SelectableMenuItem
--   -> ToggleMenuItem
--   -> SliderMenuItem
function TextMenuItem:init(i, x, y, text, on_click, update_value)
	self:init_textitem(i, x, y, text, on_click, update_value)
end
function TextMenuItem:init_textitem(i, x, y, text, on_click, update_value)
	self:init_menuitem(i, x, y)

	self.ox = 0
	self.oy = 0
	self.text = text or ""
	self.label_text = self.text
	self.value_text = ""

	self.value = nil
	self.type = "text"

	if on_click and type(on_click) == "function" then
		self.on_click = on_click
		self.is_selectable = true
	else
		self.is_selectable = false
	end

	-- -- Custom update value function
	-- if custom_update_value then
	-- 	self.update_value = custom_update_value
	-- end

	self.update_value = update_value or function() end

	-- if default_val ~= nil then
	-- 	self:update_value(default_val)
	-- end
end

function TextMenuItem:update(dt)
	self:update_textitem(dt)
end
function TextMenuItem:update_textitem(dt)
	self:update_value()

	self.ox = lerp(self.ox, 0, 0.3)
	self.oy = lerp(self.oy, 0, 0.3)

	if type(self.value) ~= "nil" then
		self.text = concat(self.label_text, ": ", self.value_text)
	else
		self.text = self.label_text
	end
end

function TextMenuItem:draw()
	self:draw_textitem()
end
function TextMenuItem:draw_textitem()
	gfx.setColor(1, 1, 1, 1)
	local th = get_text_height(self.text)
	if self.is_selected then
		-- rect_color_centered(COL_LIGHT_YELLOW, "fill", self.x, self.y+th*0.4, get_text_width(self.text)+8, th/4)
		-- rect_color_centered(COL_WHITE, "fill", self.x, self.y, get_text_width(self.text)+32, th)
		print_centered_outline(COL_WHITE, COL_ORANGE, self.text, self.x + self.ox, self.y + self.oy)
		-- print_centered(self.text, self.x, self.y)
	else
		if not self.is_selectable then
			local v = 0.5
			gfx.setColor(v, v, v, 1)
		end
		print_centered(self.text, self.x, self.y + self.oy)
	end
	gfx.setColor(1, 1, 1, 1)
end

function TextMenuItem:set_selected(val, diff)
	self.is_selected = val
	if val then
		self.oy = sign(diff or 1) * 4
	end
end

function TextMenuItem:after_click()
	audio:play(sounds.menu_select)
	self.oy = -4
end

--------

local SliderMenuItem = TextMenuItem:inherit()

function SliderMenuItem:init(i, x, y, text, on_click, values, update_value)
	self:init_textitem(i, x, y)

	self.ox = 0
	self.oy = 0
	self.text = text or ""
	self.label_text = self.text
	self.value_text = ""

	self.values = values
	self.value_index = 1
	self.value = values[1]
	self.value_text = tostring(self.value)

	self.on_click = on_click
	self.is_selectable = true

	self.update_value = update_value
end

function SliderMenuItem:update(dt)
	self.ox = lerp(self.ox, 0, 0.3)
	self.oy = lerp(self.oy, 0, 0.3)
	
	self:update_value()

	if type(self.value) ~= "nil" then
		self.text = concat(self.label_text, ": < ", self.value_text, " >")
	else
		self.text = self.label_text
	end

	if game:button_pressed("left") and self.is_selected then
		self:on_click(-1)
		self:after_click(-1)
	end
	if game:button_pressed("right") and self.is_selected then
		self:on_click(1)
		self:after_click(1)
	end
end

function SliderMenuItem:set_selected(val, diff)
	self.is_selected = val
	if val then
		self.oy = sign(diff or 1) * 4
	end
end

function SliderMenuItem:next_value(diff)
	diff = diff or 1
	self.value_index = mod_plus_1(self.value_index + diff, #self.values)
	self.value = self.values[self.value_index]
	self.value_text = tostring(self.value)
end

function SliderMenuItem:after_click(diff)
	diff = diff or 1
	self.ox = sign(diff) * 4

	-- TODO: rising pitch or decreasing pitch
	-- + sound preview for music & sfx
	audio:play(sounds.menu_select)
end


--------

local StatsMenuItem = TextMenuItem:inherit()

function StatsMenuItem:init(i, x, y, text, get_value)
	self:init_textitem(i, x, y, text)
	self.get_value = get_value
	self.value = nil
end

function StatsMenuItem:update(dt)
	self:update_textitem(dt)
	self.value = self:get_value()
	self.value_text = tostring(self.value)
end

--------

local CustomDrawMenuItem = MenuItem:inherit()

function CustomDrawMenuItem:init(i, x, y, custom_draw)
	self:init_menuitem(i, x, y)
	self.draw = custom_draw
end

--------

local Menu = Class:inherit()

function Menu:init(game, items, bg_color)
	self.items = {}
	self.is_menu = true

	local th = get_text_height()
	local h = (#items - 1) * th
	local start_y = CANVAS_HEIGHT / 2 - h / 2
	for i, parms in pairs(items) do
		local parm1 = parms[1]
		if type(parm1) == "string" then
			self.items[i] = TextMenuItem:new(i, CANVAS_WIDTH / 2, start_y + (i - 1) * th, unpack(parms))
		else
			local class = table.remove(parms, 1)
			self.items[i] = class:new(i, CANVAS_WIDTH / 2, start_y + (i - 1) * th, unpack(parms))
		end
	end

	self.bg_color = bg_color or { 1, 1, 1, 0 }
end

function Menu:update(dt)
	for i, item in pairs(self.items) do
		item:update(dt)
	end
end

function Menu:draw()
	for i, item in pairs(self.items) do
		item:draw()
	end
end

-----------

function func_set_menu(menu)
	return function()
		game.menu:set_menu(menu)
	end
end

-----------

local MenuManager = Class:inherit()

function MenuManager:init(game)
	self.game = game
	self.menus = {}

	-----------------------------------------------------
	------ [[[[[[[[[[[[[[[[ MENUS ]]]]]]]]]]]]]]]] ------
	-----------------------------------------------------

	-- FIXME: This is messy, eamble multiple types of menuitems
	-- This is so goddamn overengineered and needlessly complicated
	self.menus.title = Menu:new(game, {
		{ ">>>> ELEVATOR DITCH (logo here) <<<<" },
		-- {"********** PAUSED **********"},
		{ "" },
		{ "PLAY", function() game:new_game() end },
		{ "OPTIONS", func_set_menu('options') },
		{ "QUIT", quit_game },
		{ "" },
		{ "" },
	}, { 0, 0, 0, 0.85 })
	
	self.menus.pause = Menu:new(game, {
		{ "<<<<<<<<< PAUSED >>>>>>>>>" },
		-- {"********** PAUSED **********"},
		{ "" },
		{ "RESUME", function() game.menu:unpause() end },
		{ "RETRY", function() game:new_game() end },
		{ "OPTIONS", func_set_menu('options') },
		{ "CREDITS", func_set_menu('credits') },
		{ "BACK TO TITLE SCREEN", func_set_menu('title') },
		{ "QUIT", quit_game },
		{ "" },
		{ "" },
	}, { 0, 0, 0, 0.85 })

	self.menus.options = Menu:new(game, {
		{ "<<<<<<<<< OPTIONS >>>>>>>>>" },
		{ "< BACK", function() game.menu:back() end },
		{ "" },
		{ "SOUND", function(self, option)
			game:toggle_sound()
		end, 
		function(self)
			self.value = game.sound_on
			self.value_text = game.sound_on and "ON" or "OFF"
		end},

		{ SliderMenuItem, "VOLUME", function(self, diff)
			self:next_value(diff)
			game:set_volume(self.value/20)
		end, range_table(0,20),
		function(self)
			self.value = game.volume
			self.value_text = concat(floor(100 * self.value), "%")
		end},

		{""},

		-- {"MUSIC: [ON/OFF]", function(self)
		-- 	game:toggle_sound()
		-- end},
		{ "FULLSCREEN", function(self)
			toggle_fullscreen()
		end,
		function(self)
			self.value = is_fullscreen
			self.value_text = is_fullscreen and "ON" or "OFF"
		end},

		{ SliderMenuItem, "PIXEL SCALE", function(self, diff)
			diff = diff or 1
			self:next_value(diff)

			local scale = self.value
			pixel_scale = scale
			update_screen(scale)
		end, { "auto", "max whole", 1, 2, 3, 4}, function(self)
			self.value = pixel_scale
			self.value_text = tostring(pixel_scale)
		end},

		{ "VSYNC", function(self)
			toggle_vsync()
		end,
		function(self)
			self.value = is_vsync
			self.value_text = is_vsync and "ON" or "OFF"
		end},

		{ "" }
	}, { 0, 0, 0, 0.85 })

	self.menus.game_over = Menu:new(game, {
		{"********** GAME OVER! **********"},
		{ "" },
		{ StatsMenuItem, "Kills", function(self) return game.stats.kills end },
		{ StatsMenuItem, "Time",  function(self)
			return time_to_string(game.stats.time)
		end },
		{ StatsMenuItem, "Floor", function(self) return game.stats.floor end },
		{ "" },
		{ "RETRY", function() game:new_game() end },
		{ "BACK TO TITLE SCREEN", func_set_menu("title") },
		{ "" },
		{ "" },
	}, { 0, 0, 0, 0.85 })

	self.cur_menu = nil
	self.is_paused = false

	self.sel_n = 1
	self.sel_item = nil

	self.last_menu = "title"
end

function MenuManager:update(dt)
	if self.cur_menu then
		self.cur_menu:update(dt)

		-- Navigate up and down
		if game:button_pressed("up") then self:incr_selection(-1) end
		if game:button_pressed("down") then self:incr_selection(1) end

		-- Update current selection
		self.sel_n = mod_plus_1(self.sel_n, #self.cur_menu.items)
		self.sel_item = self.cur_menu.items[self.sel_n]
		self.sel_item.is_selected = true

		-- On pressed
		local btn = game:button_pressed("jump")
		local btn_back = game:button_pressed("shoot")
		if btn and self.sel_item and self.sel_item.on_click then
			self.sel_item:on_click()
			self.sel_item:after_click()
		end
	end

	local btn_pressed, player = game:button_pressed("pause")
	if btn_pressed then
		self:toggle_pause()
	end
end

function MenuManager:draw()
	if self.cur_menu.bg_color then
		rect_color(self.cur_menu.bg_color, "fill", game.cam_x or 0, game.cam_y or 0, CANVAS_WIDTH, CANVAS_HEIGHT)
	end
	self.cur_menu:draw()
end

function MenuManager:set_menu(menu)
	self.last_menu = self.cur_menu

	if type(menu) == "nil" then
		self.cur_menu = nil
		return
	end
	
	local m = self.menus[menu]

	if type(menu) ~= "string" and menu.is_menu then
		m = menu		
	end

	if not m then return false, "menu '" .. menu .. "' does not exist" end
	self.cur_menu = m

	-- Update selection to first selectable
	local sel, found = self:find_selectable_from(1, 1)
	self:set_selection(sel)

	-- Reset game screenshake
	if game then
		game.cam_x = 0
		game.cam_y = 0
	end

	return true
end

function MenuManager:pause()
	if self.cur_menu == nil then
		self.is_paused = true
		self:set_menu("pause")
	end
end

function MenuManager:unpause()
	self.is_paused = false
	self:set_menu()
end

function MenuManager:toggle_pause()
	if self.is_paused then
		self:unpause()
	else
		self:pause()
	end
end

function MenuManager:incr_selection(n)
	if not self.cur_menu then return false, "no current menu" end

	-- Increment selection until valid item
	local sel, found = self:find_selectable_from(self.sel_n, n)

	if not found then
		self.sel_n = self.sel_n + n
		return false, concat("no selectable item found; selection set to n + (", n, ") (", self.sel_n, ")")
	end

	-- Update new selection
	self.sel_item:set_selected(false, n)
	self.sel_n = sel
	self.sel_item = self.cur_menu.items[self.sel_n]
	self.sel_item:set_selected(true, n)
	
	audio:play(sounds.menu_hover)

	return true
end

function MenuManager:find_selectable_from(n, diff)
	diff = diff or 1

	local len = #self.cur_menu.items
	local sel = n

	local limit = len
	local found = false
	while not found and limit > 0 do
		sel = mod_plus_1(sel + diff, len)
		if self.cur_menu.items[sel].is_selectable then found = true end
		limit = limit - 1
	end

	return sel, found
end

function MenuManager:set_selection(n)
	if self.sel_item then self.sel_item:set_selected(false) end
	if not self.cur_menu then return false end

	self.sel_n = n
	self.sel_item = self.cur_menu.items[self.sel_n]
	if not self.sel_item then return false end
	self.sel_item:set_selected(true)

	return true
end

function MenuManager:back()
	self:set_menu(self.last_menu)
end

return MenuManager
