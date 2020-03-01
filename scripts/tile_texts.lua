-- tooltips for when a unit is untargetable
TILE_TOOLTIPS.knight_shielded = {"Untargetable", "Unit cannot be targeted because it is shielded"}
TILE_TOOLTIPS.knight_mountain = {"Untargetable", "Mountain must be damaged to be targeted"}
TILE_TOOLTIPS.knight_corpse = {"Untargetable", "Unit cannot be targeted bacause it leaves a corpse"}
for i = 1, 20 do
	TILE_TOOLTIPS["knight_max_"..i] = {"Max " .. i .. " Damage", "Knight Smite can do at most " .. i .. " damage"}
	TILE_TOOLTIPS["knight_too_high_"..i] = {"Untargetable", "Enemy cannot be targeted because the current max damage is " .. i}
end
