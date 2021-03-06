local Class = require "class"
local Collision = require "collision"
local Player = require "player"
local Enemies = require "data.enemies"
local Bullet = require "bullet"
local TileMap = require "tilemap"
local WorldGenerator = require "worldgenerator"
local Inventory = require "inventory"
local ParticleSystem = require "particles"
local AudioManager = require "audio"
local MenuManager = require "menu"

local waves = require "data.waves"

local images = require "images"
require "util"
require "constants"

local Game = Class:inherit()

function Game:init()
	-- Global singletons
	collision = Collision:new()
	particles = ParticleSystem:new()
	audio = AudioManager:new()
	
	-- Audio
	self.volume = 1
	self.sound_on = true

	self:new_game()

	-- Menu Manager
	self.menu = MenuManager:new(self)
end

function Game:new_game(number_of_players)
	-- Reset global systems
	collision = Collision:new()
	particles = ParticleSystem:new()

	number_of_players = number_of_players or 1

	-- Players
	self.max_number_of_players = 4 
	self.number_of_players = number_of_players

	-- Map & world gen
	self.shaft_w, self.shaft_h = 26,14
	self.map = TileMap:new(30, 17)
	self.world_generator = WorldGenerator:new(self.map)
	self.world_generator:generate(10203)
	self.world_generator:make_box(self.shaft_w, self.shaft_h)

	-- Level info
	self.floor = 0 --Floor n°
	self.floor_progress = 3.5 --How far the cabin is to the next floor
	-- self.max_elev_speed = 1/2
	self.cur_wave_max_enemy = 1
	
	-- Background
	self.door_offset = 0
	self.draw_enemies_in_bg = false
	self.door_animation = false
	self.def_elevator_speed = 400
	self.elevator_speed = 0
	self.has_switched_to_next_floor = false
	self.game_started = false

	self.bg_particles = {}
	for i=1,60 do
		local p = self:new_bg_particle()
		p.x = random_range(0, CANVAS_WIDTH)
		p.y = random_range(0, CANVAS_HEIGHT)
		table.insert(self.bg_particles, p)
	end

	-- Bounding box
	local map_w = self.map.width * BW
	local map_h = self.map.height * BW
	local box_ax = self.world_generator.box_ax
	local box_ay = self.world_generator.box_ay
	local box_bx = self.world_generator.box_bx
	local box_by = self.world_generator.box_by
	-- Don't try to understand all you have to know is that it puts collision 
	-- boxes around the elevator shaft
	self.boxes = {
		{name="box_up",     is_solid = true, x = -BW, y = -BW,  w=map_w + 2*BW,     h=BW + box_ay*BW},
		{name="box_down", is_solid = true, x = -BW, y = (box_by+1)*BW,  w=map_w + 2*BW,     h=BW*box_ay},
		{name="box_left", is_solid = true, x = -BW,  y = -BW,   w=BW + box_ax * BW, h=map_h + 2*BW},
		{name="box_right", is_solid = true, x = BW*(box_bx+1), y = -BW, w=BW*box_ax, h=map_h + 2*BW},
	}
	for i,box in pairs(self.boxes) do   collision:add(box)   end
	
	-- Actors
	self.actor_limit = 100
	self.enemy_count = 0
	self.actors = {}
	self:init_players()

	-- Start lever
	local nx = CANVAS_WIDTH/2
	local ny = self.world_generator.box_by * BLOCK_WIDTH
	-- local l = create_actor_centered(Enemies.ButtonGlass, nx, ny)
	local l = create_actor_centered(Enemies.DummyTarget, floor(nx), floor(ny))
	self:new_actor(l)

	self.inventory = Inventory:new()

	-- Camera & screenshake
	self.cam_x = 0
	self.cam_y = 0
	self.cam_ox, self.cam_oy = 0, 0
	self.screenshake_q = 0
	self.screenshake_speed = 20

	-- Debugging
	self.debug_mode = false
	self.msg_log = {}

	self.test_t = 0

	-- Logo
	self.logo_y = 15
	self.logo_vy = 0
	self.move_logo = false
	
	if self.menu then
		self.menu:set_menu()
	end

	self.stats = {
		floor = 0,
		kills = 0,
		time = 0,
	}

	self.time = 0
end

function Game:update(dt)
	-- Menus
	self.menu:update(dt)

	if not self.menu.cur_menu then
		self:update_main_game(dt)
	end

	-- Update button states
	for _, player in pairs(self.players) do
		player:update_button_state()
	end
end

function Game:update_main_game(dt)
	self.time = self.time + dt
	
	self.map:update(dt)

	-- Particles
	particles:update(dt)
		-- Background lines
	for i,o in pairs(self.bg_particles) do
		o.y = o.y + dt*self.elevator_speed*o.spd
		if o.y > CANVAS_HEIGHT then
			o.x = love.math.random(0, CANVAS_WIDTH)
			o.w = love.math.random(2, 12)
			o.h = love.math.random(8, 64)
			o.y = -o.h- love.math.random(0, CANVAS_HEIGHT)
			o.col = random_sample{COL_DARK_GRAY, COL_MID_GRAY, --[[COL_DARK_RED, COL_MID_DARK_GREEN, COL_DARK_BLUE, COL_DARK_PURPLE]]}
		end

		-- Size corresponds to elevator speed
		o.oh = max(o.w/o.h, self.elevator_speed / self.def_elevator_speed)
		o.oy = .5 * o.h * o.oh
	end

	self:progress_elevator(dt)

	-- Update actors
	for i = #self.actors, 1, -1 do
		local actor = self.actors[i]

		actor:update(dt)
	
		if actor.is_removed then
			table.remove(self.actors, i)
		end
	end

	
	-- Logo
	if self.move_logo then
		self.logo_vy = self.logo_vy - dt
		self.logo_y = self.logo_y + self.logo_vy
	end

	if love.keyboard.isScancodeDown("a") then self.cam_x = self.cam_x - 1 end
	if love.keyboard.isScancodeDown("d") then self.cam_x = self.cam_x + 1 end
	if love.keyboard.isScancodeDown("w") then self.cam_y = self.cam_y - 1 end
	if love.keyboard.isScancodeDown("s") then self.cam_y = self.cam_y + 1 end

	if love.keyboard.isDown("h") then self.screenshake_q = 0 end

	-- Screenshake
	self.screenshake_q = max(0, self.screenshake_q - self.screenshake_speed * dt)
	self.cam_ox, self.cam_oy = random_neighbor(self.screenshake_q), random_neighbor(self.screenshake_q)
end

function Game:draw()
	-- Sky
	gfx.clear(COL_BLACK_BLUE)
	gfx.translate(-self.cam_x + self.cam_ox, -self.cam_y + self.cam_oy)

	for i,o in pairs(self.bg_particles) do
		rect_color(o.col, "fill", o.x, o.y + o.oy, o.w, o.h * o.oh)
	end

	-- Map
	self.map:draw()
	
	-- Background
	--TODO: fuze it into map or remove map, only have coll boxes & no map
	local bw = BLOCK_WIDTH
	self.cabin_x, self.cabin_y = self.world_generator.box_ax*bw, self.world_generator.box_ay*bw
	self.door_ax, self.door_ay = self.cabin_x+154, self.cabin_x+122
	self.door_bx, self.door_by = self.cabin_y+261, self.cabin_y+207

	
	-- Door background
	rect_color(COL_BLACK_BLUE, "fill", self.door_ax, self.door_ay, self.door_bx - self.door_ax, self.door_by - self.door_ay)
	-- If doing door animation, draw buffered enemies
	if self.door_animation then
		for i,e in pairs(self.door_animation_enemy_buffer) do 
			e:draw()
		end
	end
	self:draw_background(self.cabin_x, self.cabin_y)
	
	-- Draw actors
	for _,actor in pairs(self.actors) do
		if not actor.is_player then
			actor:draw()
		end
	end
	for _,p in pairs(self.players) do
		p:draw()
	end

	particles:draw()

	-- Walls
	gfx.draw(images.cabin_walls, self.cabin_x, self.cabin_y)
	
	-- Draw actors UI
	-- Draw actors
	for k,actor in pairs(self.actors) do
		if actor.draw_hud then     actor:draw_hud()    end
	end

	-- UI
	-- print_centered_outline(COL_WHITE, COL_DARK_BLUE, concat("FLOOR ",self.floor), CANVAS_WIDTH/2, 8)
	-- local w = 64
	-- rect_color(COL_MID_GRAY, "fill", floor((CANVAS_WIDTH-w)/2),    16, w, 8)
	-- rect_color(COL_WHITE,    "fill", floor((CANVAS_WIDTH-w)/2) +1, 17, (w-2)*self.floor_progress, 6)

	love.graphics.draw(images.logo, floor((CANVAS_WIDTH - images.logo:getWidth())/2), self.logo_y)
	love.graphics.draw(images.controls, floor((CANVAS_WIDTH - images.controls:getWidth())/2), floor(self.logo_y) + images.logo:getHeight()+6)

	-- Debug
	if self.debug_mode then
		self:draw_debug()
	end

	if self.menu.cur_menu then
		self.menu:draw()
	end

	--'Memory used (in kB): ' .. collectgarbage('count')

	local t = "EARLY VERSION - NOT FINAL!"
	gfx.print(t, CANVAS_WIDTH-get_text_width(t), 0)
	local t = os.date('%a %d/%b/%Y')
	print_color({.7,.7,.7}, t, CANVAS_WIDTH-get_text_width(t), 12)

end

function Game:draw_debug()
	gfx.print(concat("FPS: ",love.timer.getFPS(), " / frmRpeat: ",self.frame_repeat, " / frame: ",frame), 0, 0)
	
	local items, len = collision.world:getItems()
	for i,it in pairs(items) do
		local x,y,w,h = collision.world:getRect(it)
		rect_color({0,1,0,.3},"fill", x, y, w, h)
		rect_color({0,1,0,.5},"line", x, y, w, h)
	end
	
	-- Print debug info
	local txt_h = get_text_height(" ")
	local txts = {
		concat("FPS: ",love.timer.getFPS()),
		concat("n° of actors: ", #self.actors, " / ", self.actor_limit),
		concat("n° collision items: ", collision.world:countItems()),
	}
	for i=1, #txts do  print_label(txts[i], 0, txt_h*i) end
	
	self.world_generator:draw()
	draw_log()
end

function Game:new_actor(actor)
	if #self.actors >= self.actor_limit then   
		actor:remove()
		return
	end
	if actor.is_enemy then 
		self.enemy_count = self.enemy_count + 1
	end
	table.insert(self.actors, actor)
end

function Game:on_kill(actor)
	if actor.is_enemy then
		self.enemy_count = self.enemy_count - 1
		self.stats.kills = self.stats.kills + 1
	end

	if actor.is_player then
		self:on_game_over()
	end
end

function Game:on_game_over()
	self.menu:set_menu("game_over")
	self.stats.time = self.time
	self.stats.floor = self.floor
end

function draw_log()
	-- log
	local x2 = floor(CANVAS_WIDTH/2)
	local h = gfx.getFont():getHeight()
	print_label("--- LOG ---", x2, 0)
	for i=1, min(#msg_log, max_msg_log) do
		print_label(msg_log[i], x2, i*h)
	end
end

function Game:init_players()
	-- TODO: move this to a general function (?)
	local control_schemes = {
		[1] = {
			type = "keyboard",
			left = {"a", "left"},
			right = {"d", "right"},
			up = {"w", "up"},
			down = {"s", "down"},
			jump = {"z", "c", "b"},
			shoot = {"x", "v", "n"},
			switchgun = {"g"}, --test
			pause = {"escape"},
		},
		[2] = {
			type = "keyboard",
			left = {"left"},
			right = {"right"},
			up = {"up"},
			down = {"down"},
			jump = {"."},
			shoot = {","},
			pause = {"escape"},
		}
	}

	local sprs = {
		images.ant,
		images.caterpillar
	}

	self.players = {}

	-- Spawn at middle
	local mx = floor((self.map.width / self.max_number_of_players))
	local my = floor(self.map.height / 2)

	for i=1, self.number_of_players do
		local player = Player:new(i, mx*16 + i*16, my*16, sprs[i], control_schemes[i])
		self.players[i] = player
		self:new_actor(player)
	end
end


-----------------------------------------------------
--- [[[[[[[[ BACKGROUND & LEVEL PROGRESS ]]]]]]]] ---
-----------------------------------------------------

-- TODO: Should we move this to a separate class?

function Game:new_bg_particle()
	local o = {}
	o.x = love.math.random(0, CANVAS_WIDTH)
	o.w = love.math.random(2, 12)
	o.h = love.math.random(8, 64)
	o.y = -o.h - love.math.random(0, CANVAS_HEIGHT)
	o.col = random_sample{COL_DARK_GRAY, COL_MID_GRAY}
	o.spd = random_range(0.5, 1.5)

	o.oy = 0
	o.oh = 1
	return o
end

function Game:progress_elevator(dt)
	-- Only switch to next floor until all enemies killed
	if not self.door_animation and self.enemy_count == 0 then
		self.door_animation = true
		self.has_switched_to_next_floor = false
		self:new_wave_buffer_enemies(dt)
	end

	-- Do the door opening animation
	if self.door_animation then
		self.floor_progress = self.floor_progress - dt
		self:update_door_anim(dt)
	end
	
	-- Go to next floor once animation is finished
	if self.floor_progress <= 0 then
		self.floor_progress = 5.5
		
		self.door_animation = false
		self.draw_enemies_in_bg = false
		self.door_offset = 0
	end
end

function Game:update_door_anim(dt)
	-- 4-3: open doors / 3-2: idle / 2-1: close doors
	if self.floor_progress > 4 then
		-- Door is closed at first...
		self.door_offset = 0
	elseif self.floor_progress > 3 then
		-- ...Open door...
		self.door_offset = lerp(self.door_offset, 54, 0.1)
	elseif self.floor_progress > 2 then
		-- ...Keep door open...
		self.door_offset = 54
	elseif self.floor_progress > 1 then
		-- ...Close doors
		self.door_offset = lerp(self.door_offset, 0, 0.1)
		self:activate_enemy_buffer(dt)
	end

	-- Elevator speed
	if 5 > self.floor_progress and self.floor_progress > 3 then
		self.elevator_speed = max(0, self.elevator_speed - 18)
	elseif self.floor_progress < 1 then
		self.elevator_speed = min(self.elevator_speed + 10, self.def_elevator_speed)
	end

	-- Switch to next floor if just opened doors
	if self.floor_progress < 4.2 and not self.has_switched_to_next_floor then
		self.floor = self.floor + 1
		self.has_switched_to_next_floor = true
		self:next_floor(dt)
	end
end

function Game:next_floor(dt)
	self.move_logo = true
end

function Game:new_wave_buffer_enemies()
	-- Spawn a bunch of enemies
	local bw = BLOCK_WIDTH
	local wg = self.world_generator
	
	self.cur_wave_max_enemy = n
	self.door_animation_enemy_buffer = {}

	print(self.floor, clamp(self.floor, 1, #waves))
	local wave_n = clamp(self.floor+1, 1, #waves)
	local wave = waves[wave_n] -- Minus 1 because the floor indicator changes before enemies are spawned
	local n = love.math.random(wave.min, wave.max)
	for i=1, n do
		-- local x = love.math.random((wg.box_ax+1)*bw, (wg.box_bx-1)*bw)
		-- local y = love.math.random((wg.box_ay+1)*bw, (wg.box_by-1)*bw)
		local x = love.math.random(self.door_ax, self.door_bx)
		local y = love.math.random(self.door_ay, self.door_by)
		
		local enem = random_weighted(wave.enemies)
		local e = enem:new(x,y)
		
		-- Center enemy
		e.x = floor(e.x - e.w/2)
		e.y = floor(e.y - e.h/2)
		-- Prevent collisions with floor
		if e.y+e.h > self.door_by then   e.y = self.door_by - e.h    end
		collision:remove(e)
		table.insert(self.door_animation_enemy_buffer, e)
	end
end

function Game:activate_enemy_buffer()
	for k, e in pairs(self.door_animation_enemy_buffer) do
		e:add_collision()
		self:new_actor(e)
	end
	self.door_animation_enemy_buffer = {}
end

function Game:draw_background(cabin_x, cabin_y) 
	local bw = BLOCK_WIDTH

	-- Doors
	gfx.draw(images.cabin_door_left,  cabin_x + 154 - self.door_offset, cabin_y + 122)
	gfx.draw(images.cabin_door_right, cabin_x + 208 + self.door_offset, cabin_y + 122)

	-- Cabin background
	gfx.draw(images.cabin_bg, cabin_x, cabin_y)
	gfx.draw(images.cabin_bg_amboccl, cabin_x, cabin_y)
	
	-- Level counter
	gfx.setFont(FONT_7SEG)
	print_color(COL_WHITE, string.sub("00000"..tostring(self.floor),-3,-1), 198+16*2, 97+16*2)
	gfx.setFont(FONT_REGULAR)
end



function Game:keypressed(key, scancode, isrepeat)
	if key == "f3" then
		self.debug_mode = not self.debug_mode
	end

	for i, ply in pairs(self.players) do
		--ply:keypressed(key, scancode, isrepeat)
	end
end

-- function Game:keyreleased(key, scancode)
-- 	for i, ply in pairs(self.players) do
-- 		--ply:keyreleased(key, scancode)
-- 	end
-- end

function Game:screenshake(q)
	self.screenshake_q = self.screenshake_q + q
end

function Game:button_down(btn)
	--[[
		Returns if ANY player is holding `btn`
	]]
	for _, player in pairs(self.players) do
		if player:button_down(btn) then
			return true, player
		end
	end
	return false
end

function Game:button_pressed(btn)
	--[[
		Returns if ANY player is pressing `btn`
	]]
	for _, player in pairs(self.players) do
		if player:button_pressed(btn) then
			return true, player
		end
	end
	return false
end

function Game:toggle_sound()
	-- TODO: move from bool to a number (0-1), customisable in settings
	self.sound_on = not self.sound_on
end

function Game:set_volume(n)
	self.volume = n
	love.audio.setVolume( self.volume )
end

return Game