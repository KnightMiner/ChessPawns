local mod = mod_loader.mods[modApi.currentMod]
local achvTrigger = mod:loadScript("achievementTriggers")
local helpers = mod:loadScript("libs/helpers")
local previewer = mod:loadScript("weaponPreview/api")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "Pawns can move up to 2 spaces in a single direction."
trait:Add{
  PawnTypes = { "Chess_Pawn", "Chess_Pawn_Alt" },
  Icon = "img/combat/icons/icon_pawn_move.png",
  IconGlow = "img/combat/icons/icon_empty_glow.png",
  Title = "Pawn Movement",
  Description = HELP_TEXT
}

-- Pawn explosions --
trait:Add{
  PawnTypes = { "Chess_Pawn_Explosive", "Chess_Pawn_Explosive_Alt" },
  Icon = "img/combat/icons/icon_pawn_move_explode.png",
  IconGlow = "img/combat/icons/icon_explode_glow.png",
  IconOffset = Point(0,8),
  Title = "Explosive Pawn",
  Description = HELP_TEXT .. "\nThis unit will always explode on death, dealing 2 damage to adjacent tiles."
}

--[[--
  Pawn Move: 2 space in a straight line

  Upgrades: Alternates distance and diagonal
]]
Chess_Pawn_Move = {}
function Chess_Pawn_Move:GetTargetArea(p1)
  return helpers.getTargetLine(p1, Pawn:GetMoveSpeed(), 0)
end

--[[--
  Pawn Spear: 1 push damage in any orthogonal, or 1 space stealing damage in any diagonal
]]
Chess_Pawn_Spear = Skill:new{
  -- base stats
	Class       = "Prime",
	Icon        = "weapons/prime_spear.png",
	PowerCost   = 0,
	Upgrades    = 0,
	UpgradeCost = {},
  -- settings
	Damage = 1,
  -- effects
	LaunchSound = "/weapons/sword",
	TipImage = {
    CustomPawn = "Chess_Pawn",
    Unit          = Point(2,3),
    Enemy         = Point(1,2),
    CustomEnemy   = "Leaper1",
    Enemy2        = Point(2,2),
    Target        = Point(2,2),
    Second_Origin = Point(2,3),
    Second_Target = Point(1,2),
	}
}

function Chess_Pawn_Spear:GetTargetArea(point)
	local ret = PointList()
	for i = DIR_START, DIR_END do
    -- add orthogonals
		local curr = point + DIR_VECTORS[i]
    if Board:IsValid(curr) then
      ret:push_back(curr)
      -- add diagonals if attackable
      curr = curr + DIR_VECTORS[(i+1)%4]
      if Board:IsValid(curr) and Board:IsPawnSpace(curr) or Board:IsTerrain(curr, TERRAIN_MOUNTAIN) then
        ret:push_back(curr)
      end
    end
	end

	return ret
end

-- Sword animations for each diagonal direction
local DIAGONAL_SWORDS = {
  [p2idx(Point(-1,-1), 8)] = "chess_speardiag_U",
  [p2idx(Point(-1, 1), 8)] = "chess_speardiag_L",
  [p2idx(Point( 1,-1), 8)] = "chess_speardiag_R",
  [p2idx(Point( 1, 1), 8)] = "chess_speardiag_D",
}

function Chess_Pawn_Spear:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
  -- determine push
  local offset = p2 - p1
  local direction
  if offset.x == 0 or offset.y == 0 then
    direction = GetDirection(p2 - p1)
  else
    direction = DIR_NONE
  end

  -- deal damage to the target
	local damage = SpaceDamage(p2, self.Damage, direction)
  -- melee animation of adjecent
  if direction ~= DIR_NONE then
	  damage.sAnimation = "explospear1_" .. direction
    ret:AddMelee(p1, damage)
    achvTrigger:checkPush(ret, p2, direction)
  else
    -- diagonal damage
    damage.sAnimation = DIAGONAL_SWORDS[p2idx(offset, 8)]
	  ret:AddDamage(damage)

    -- if space is empty after attacking, move to it
    local willKill
    -- mountains need to be at 1 health
    local terrain = Board:GetTerrain(p2)
    if terrain == TERRAIN_MOUNTAIN then
      willKill = Board:GetHealth(p2) == 1
    else
      -- pawns at 1 health
      local target = Board:GetPawn(p2)
      willKill = (helpers.willDamageKill(target, 1) and not target:IsMech() and not _G[target:GetType()]:GetCorpse())
    end
    -- if we kill it, take its space
    if willKill then
      ret:AddDelay(0.1)
      ret:AddScript(string.format("Pawn:SetSpace(%s)", p2:GetString()))
      -- for animation
      ret:AddTeleport(p1, p2, NO_DELAY)
      -- explosion preview if explosiive
      if helpers.pawnExplodes(Pawn:GetType()) and (terrain == TERRAIN_HOLE or terrain == TERRAIN_WATER) then
        for i = DIR_START, DIR_END do
          previewer:AddDamage(SpaceDamage(p2+DIR_VECTORS[i], 2))
        end
      end
    end
  end

	return ret
end
