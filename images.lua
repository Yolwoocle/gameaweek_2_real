local Class = require "class"
require "util"

function load_image(name)
	local im = love.graphics.newImage("images/"..name)
	im:setFilter("nearest", "nearest")
	return im 
end
function load_image_table(name, n, w, h)
	if not n then  error("number of images `n` not defined")  end
	local t = {}
	for i=1,n do 
		t[i] = load_image(name..tostr(i))
	end
	t.w = w
	t.h = h
	return t
end

local img_names = {
	"empty",
	
	"magnet",
	"grass",
	"dirt",
	"snowball",

	"heart",
	"heart_half",
	"heart_empty",
	"ammo",

	"ant1",
	"ant2",
	"bee",
	"caterpillar",
	"duck",
	"fly",
	"grasshopper",
	"larva",
	"larva1",
	"larva2",
	"slug",
	"snail_open",
	"snail_shell",
	"spiked_fly",
	
	"bullet",

	"gun_machinegun",
	"gun_triple",
	"gun_burst",
	"gun_shotgun",
	"gun_minigun",
	"gun_mushroom_cannon",

	"metal",
	"chain",
	"bg_plate",
	"cabin_bg",
	"cabin_bg_amboccl",
	"cabin_walls",
	"cabin_door_left", "cabin_door_right",

	"logo",

	"loot_ammo",
	"loot_ammo_big",
	"loot_life",
	"loot_life_big",

	"lever_on",
	"lever_off",

	"big_red_button_crack0",
	"big_red_button_crack1",
	"big_red_button_crack2",
	"big_red_button_crack3",
	"big_red_button",

	"ptc_glass_shard",
	"snail_shell_fragment",

	"dummy_target",

	"controls",

	"mushroom_ant",
	"mushroom",
	"mushroom_yellow",
	"mushroom_spike",
}

local images = {}
for i=1,#img_names do   images[img_names[i]] = load_image(img_names[i]..".png")   end
return images