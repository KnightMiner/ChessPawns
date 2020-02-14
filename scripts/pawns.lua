local mod = mod_loader.mods[modApi.currentMod]
local trait = require(mod.scriptPath.."libs/trait")

----Mechs----

--[[--
  Knight Mech: Prime focused on leap attacks

	Move Skill: Limited to knight leaps
	Weapon: Knight Smite - Can instantly kill any target within a knight leap, inflicting self damage based on target's remaining health
]]
Chess_Knight = Pawn:new {
	-- basic
	Name = "Knight Mech",
	Class = "Prime",
	DefaultTeam = TEAM_PLAYER,
	Massive = true,
	-- stats
	Health = 4,
	MoveSpeed = 2,
	Armor = true,
	-- skills
	SkillList = { "Chess_Knight_Smite" },
	MoveSkill = Chess_Knight_Move,
	-- display
	Image = "chess_knight",
	ImageOffset = 3, -- yellow
	SoundLocation = "/mech/distance/dstrike_mech/",
	ImpactMaterial = IMPACT_METAL
}
AddPawnName("Chess_Knight")

--[[--
  Rook Mech: Fast brute focused on moving units on the board

	Move Skill: Limited to straight lines, but full length of the board
	Weapon: Castle Charge - Charge forwards and toss an enemy back
]]
Chess_Rook = Pawn:new {
	-- basic
	Name = "Rook Mech",
	Class = "Brute",
	DefaultTeam = TEAM_PLAYER,
	Massive = true,
	-- stats
	Health = 3,
	MoveSpeed = 7,
	-- skills
	SkillList = { "Chess_Castle_Charge" },
	MoveSkill = Chess_Rook_Move,
	-- display
	Image = "chess_rook",
	ImageOffset = 3, -- yellow
	SoundLocation = "/mech/prime/rock_mech/",
	ImpactMaterial = IMPACT_METAL
}
AddPawnName("Chess_Rook")

--[[--
  King Mech: Ranged mech focused on deployment of pawns

	Move Skill: Move speed very low, but can move diagonals
	Weapon: Spawn Pawn - deploys up to two pawns on the board to help fight
]]
Chess_King = Pawn:new {
	-- basic
	Name = "King Mech",
	Class = "Ranged",
	DefaultTeam = TEAM_PLAYER,
	Massive = true,
	-- stats
	Health = 2,
	MoveSpeed = 1,
	Flying = true,
	-- skills
	SkillList = { "Chess_SpawnPawn" },
	MoveSkill = Chess_King_Move,
	-- display
	Image = "chess_king",
	ImageOffset = 3, -- yellow
	SoundLocation = "/mech/prime/rock_mech/",
	ImpactMaterial = IMPACT_METAL
}
AddPawnName("Chess_King")

--[[--
  Pawn Mech: Deployable mech with limited movement

	Move Skill: Limited to straight lines
	Weapon: Pawn Spear - basic melee attack with upgradable range
]]
Chess_Pawn = Pawn:new {
	-- basic
	Name = "Pawn Mech",
	DefaultTeam = TEAM_PLAYER,
	-- stats
	Health = 1,
	MoveSpeed = 2,
	-- skills
	SkillList = { "Chess_PawnSpear" },
	MoveSkill = Chess_Pawn_Move,
	-- display
	Image = "chess_pawn",
	ImageOffset = 3, -- yellow
	SoundLocation = "/mech/distance/dstrike_mech/",
	ImpactMaterial = IMPACT_METAL
}
--- Same as Chess Pawn, but shows in black. Spawn Pawn alternates between the two colors
Chess_Pawn_Black = Chess_Pawn:new { ImageOffset = 4 }
AddPawnName("Chess_Pawn")
AddPawnName("Chess_Pawn_Black")

--- Pawns for Spawn Pawn Upgrade 1 - Spear range is upgraded, allowing 2 tiles to be reachable
Chess_Pawn_A       = Chess_Pawn:new   { SkillList = { "Chess_PawnSpear_A" } }
Chess_Pawn_A_Black = Chess_Pawn_A:new { ImageOffset = 4 }
AddPawnName("Chess_Pawn_A")
AddPawnName("Chess_Pawn_A_Black")

--- Pawns for Spawn Pawn Upgrade 2 - Explode on death for 2 damage to surrounding units
Chess_Pawn_B       = Chess_Pawn:new   {}
Chess_Pawn_B_Black = Chess_Pawn_B:new { ImageOffset = 4 }
AddPawnName("Chess_Pawn_B")
AddPawnName("Chess_Pawn_B_Black")

--- Pawns for combined upgrades
Chess_Pawn_AB       = Chess_Pawn_B:new  { SkillList = { "Chess_PawnSpear_A" } }
Chess_Pawn_AB_Black = Chess_Pawn_AB:new { ImageOffset = 4 }
AddPawnName("Chess_Pawn_AB")
AddPawnName("Chess_Pawn_AB_Black")

-- Pawn explosions --
trait:Add{
	PawnTypes = { "Chess_Pawn_B", "Chess_Pawn_AB", "Chess_Pawn_B_Black", "Chess_Pawn_AB_Black" },
	Icon = { "img/combat/icons/icon_explode.png", Point(0,8) },
	Description = {"Explosive Upgrade", "This unit will always explode on death, dealing 2 damage to adjacent tiles."}
}

-- TODO: reconsider smoke
-- chess pawn B explodes on death
function Chess_Pawn_B:GetDeathEffect(p1)
	local ret = SkillEffect()

	ret:AddSound("/impact/generic/explosion")

  -- explosion deals 2 damage in all directions
	for dir = DIR_START, DIR_END do
		-- TODO: delay is a little weird
		ret:AddDelay(0.075)

		damage = SpaceDamage(p1, 0)
		damage.sAnimation = PUSHEXPLO2_ANIMS[dir]
		ret:AddDamage(damage)

		local p2 = p1 + DIR_VECTORS[dir]
		damage = SpaceDamage(p2, 2)
		ret:AddDamage(damage)

		ret:AddBounce(p2, 1)
	end

  -- add smoke and deal 2 damage to attacker on same space
	local damage = SpaceDamage(p1, 2)
	damage.sAnimation = "explo_fire1"
	damage.iSmoke = 1
	ret:AddDamage(damage)
	ret:AddBounce(p1, 3)

	return ret
end
