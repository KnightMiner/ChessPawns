--- This file contains mod specific helper functions, copy only specific utilities if any are useful
local helpers = {}

--- Cached point for the tooltip board size
local TOOLTIP_SIZE = Point(6,6)

--[[--
  Checks if we are currently in a tooltip

  @return True in tooltips
]]
function helpers.isTooltip()
  return Board:GetSize() == TOOLTIP_SIZE
end

--[[--
  Creates a damage animation on a space

  @param  space  Point for the animation
  @param  name   string animation name
  @return SpaceDamage instance
]]
function helpers.animationDamage(point, name)
  local damage = SpaceDamage(point, 0)
  damage.sAnimation = name
  return damage
end

--[[--
  Moves a chess piece across the given spaces

  @param effect  SkillEffect instance to add movements
  @param start   Starting Point of the move
  @param target  Stopping Point of the move
]]
function helpers.addLeap(effect, start, stop)
  if Board:GetTerrain(start) == TERRAIN_WATER then
    effect:AddSound("/props/water_splash_small")
    effect:AddDamage(helpers.animationDamage(start,"Splash"))
  else
    effect:AddSound("/weapons/science_repulse")
    for dir = DIR_START, DIR_END do
      effect:AddDamage(helpers.animationDamage(start,"airpush_"..dir))
    end
  end

  local move = PointList()
  move:push_back(start)
  move:push_back(stop)
  effect:AddLeap(move, FULL_DELAY)

  local flying = _G[Pawn:GetType()].Flying
  if not flying and Board:GetTerrain(stop) == TERRAIN_WATER then
    effect:AddSound("/props/water_splash")
    effect:AddDamage(helpers.animationDamage(stop,"Splash"))
  else
    effect:AddSound(flying and "/weapons/science_repulse" or "/impact/generic/mech")
    for dir = DIR_START, DIR_END do
      effect:AddDamage(helpers.animationDamage(stop,PUSH_ANIMS[dir]))
    end
  end
end


--[[--
  Checks if the given damage is enough to kill a pawn

  @param point    Pawn location
  @param amount   Amount of damage to deal
  @param pushDir  Direction of push before damage, to check if it deals extra damage
  @return  True if the amount of damage is enough to kill this pawn
]]
function helpers.willDamageKill(pawn, amount, pushDir)
  -- no pawn? already dead
  if pawn == nil then
    return true
  end

  -- ice and shield always takes 2 hits to break
  if pawn:IsFrozen() or pawn:IsShield() then
    return false
  end

  local health = pawn:GetHealth()
  -- if pushed, check if we will deal push damage or entirely miss
  if pushDir and pushDir ~= DIR_NONE then
    if Board:IsBlocked(pawn:GetSpace() + DIR_VECTORS[pushDir], PATH_FLYER) then
      health = health - 1
      -- if its dead now, the pawn did not kill it
      if health == 0 then
        return false
      end
    else
      return false
    end
  end
  -- ACID and health will affect the killing
  if pawn:IsAcid() then
    amount = amount * 2
  -- note this returns true even if acid
  elseif pawn:IsArmor() then
    health = health + 1
  end

  return health <= amount
end

--- Map of pawn name to boolean if they explode
local PAWN_EXPLODES = {
  Chess_Pawn_Explosive     = true,
  Chess_Pawn_Explosive_Alt = true,
}

--[[--
  Checks if a given pawn is an exploding chess pawn

  @param pawnType  Type of the pawn to check
]]
function helpers.pawnExplodes(pawnType)
  return PAWN_EXPLODES[pawnType]
end

return helpers
