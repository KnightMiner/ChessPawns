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

--- Space is blocked and prevents further movement
local BLOCKED = 0
--- Space is blocked, but further movement allowed
local OCCUPIED = 1
--- Space is empty and can be used for paths
local FREE = 2

--[[--
  Checks a point to determine if it is blocked

  @param point    Point to check
  @return  BLOCKED, OCCUPIED, or FREE
]]
local function blockType(point)
  -- invalid is blocked, we are done
  if not Board:IsValid(point) then
    return BLOCKED
  end

  -- if empty, its free
  -- for some reason the 16 bit is set for PathProf, not sure what it means
  local path = Pawn:GetPathProf() % 16
  if not Board:IsBlocked(point, path) then
    return FREE
  end
  -- flying does not care about blockages
  if path == PATH_FLYER then
    return OCCUPIED
  end

  -- Kawn does not care about any pawns
  if path == PATH_ROADRUNNER then
    if Board:IsPawnSpace(point) then
      return OCCUPIED
    end
  -- anyone else just skips own team
  elseif Board:IsPawnTeam(point, Pawn:GetTeam()) then
    return OCCUPIED
  end
  -- any other blockages (hole, mountain, vek)
  return BLOCKED
end

--[[--
  Gets all target areas in a straight line

  @param move    Maximum spaces to move
  @param offsets Number of spaces to offset from the line
  @return  PointList of available points
]]
function helpers.getTargetLine(start, speed, extra)
  -- using a hash so we can skip duplicates
  local points = {}

  -- move in all four directions
  for dir = DIR_START, DIR_END do
    -- straight line
    local offset = DIR_VECTORS[dir]
    for x = 1, speed do
      local linePoint = start + offset * x
      local lineType = blockType(linePoint)
      -- blocked we are done
      if lineType == BLOCKED then break end

      -- free spaces means we we keep this
      if lineType == FREE then
        points[p2idx(linePoint)] = linePoint

        -- extra means extend off sides
        if extra > 0 then
          for s = 1, 3, 2 do
            local side = DIR_VECTORS[(dir+s)%4]
            for y = 1, extra do
              local sidePoint = linePoint + side * y
              local sideType = blockType(sidePoint)
              -- blocked is done with this side
              if sideType == BLOCKED then break end

              -- free means add point
              if sideType == FREE then
                points[p2idx(sidePoint)] = sidePoint
              end
            end
          end
        end
      end
    end
  end

  -- convert to a list, note the keys are the points
  local list = PointList()
  for _,point in pairs(points) do
    list:push_back(point)
  end
  return list
end

--[[--
  Gets all target areas in a straight line

  @param move    Maximum spaces to move
  @param offsets Number of spaces to offset from the line
  @return  PointList of available points
]]
function helpers.getDiagonalMoves(start, speed, extra)
  local points = PointList()

  -- move in all four directions
  for dir = DIR_START, DIR_END do
    -- straight line
    local offset = DIR_VECTORS[dir]
    for x = 1, extra do
      local point = start + offset * x
      local type = blockType(point)
      -- blocked we are done
      if type == BLOCKED then break end

      -- free spaces means we we keep this, occupied we keep going but skip this
      if type == FREE then
        points:push_back(point)
      end
    end

    -- diagonal line
    offset = offset + DIR_VECTORS[(dir+1)%4]
    for x = 1, speed do
      local point = start + offset * x
      local type = blockType(point)
      -- blocked we are done
      if type == BLOCKED then break end

      -- free spaces means we we keep this, occupied we keep going but skip this
      if type == FREE then
        points:push_back(point)
      end
    end
  end

  return points
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
