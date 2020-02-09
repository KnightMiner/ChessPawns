local mod = mod_loader.mods[modApi.currentMod]
local helpers = require(mod.scriptPath .. "libs/helpers")

--[[--
  Rook Move: any number of spaces in a straight line

  Upgrade: Move extra spaces in a second line
]]
Chess_Rook_Move = {}
function Chess_Rook_Move:GetTargetArea(p1)
  -- rook moves up to 7 in one direction, extra allows a second move on another axis
  local move = Pawn:GetMoveSpeed()
  local extra = 0
  if move > 7 then
    extra = move - 7
    move = 7
  end
  return helpers.getTargetLine(p1, move, extra)
end

--[[--
  Checks if a given line is valid for rook movement

  @param p1  First point to check
  @param p2  Second point, should share an axis with first point
  @return  true if the point is valid, false otherwise
]]
local function lineValid(p1, p2)
  -- path should be a straight line, meaning it equals the manhattan distance
  return Board:GetPath(p1, p2, Pawn:GetPathProf()):size() == (p1:Manhattan(p2) + 1)
end

--[[--
  Draws the path for the given rook movement
  All paths should consist of 1 or 2 lines over valid spaces
]]
function Chess_Rook_Move:GetSkillEffect(p1, p2)
  local ret = SkillEffect()
  local path = Pawn:GetPathProf()

  -- if not a straight line, find mid point for move
  local move
  if Pawn:GetMoveSpeed() > 7 then
    local diffX = math.abs(p1.x - p2.x)
    local diffY = math.abs(p1.y - p2.y)
    if diffX > 0 and diffY > 0 then
      -- start with the bigger midpoint
      local mid
      local midX = Point(p2.x, p1.y)
      local midY = Point(p1.x, p2.y)

      -- if X is blocked, y is correct
      if Board:IsBlocked(midX, path) then
        mid = midY
      -- y blocked means it must be x
      elseif Board:IsBlocked(midY, path) then
        mid = midX
      else
        -- since both corners are valid, have to check whole path
        -- try the longer distance first, its the preferred path
        mid = diffX > diffY and midX or midY

        -- the line to that point must be valid, if not it must be the other point
        if not lineValid(p1, mid) then
          mid = diffX > diffY and midY or midX
        end
      end

      -- path to the better point, then the other one
      move = Board:GetPath(p1, mid, path)
      -- then add remaining spaces to final stop
      local dir = DIR_VECTORS[GetDirection(p2 - mid)]
      for i = 1, mid:Manhattan(p2) do
        move:push_back(mid + dir * i)
      end
    else
      move = Board:GetPath(p1, p2, path)
    end
  else
    move = Board:GetPath(p1, p2, path)
  end

  -- make the actual move
  ret:AddMove(move, FULL_DELAY)

  -- charge remaining distance
  return ret
end

--[[--
  Castle Charge: charge forwards and flip enemy overself

  Upgrades: Toss and Damage
]]
Chess_Castle_Charge = Skill:new {
	-- base stats
  Class = "Brute",
  PowerCost = 1,
  Upgrades = 2,
  UpgradeCost = {1, 3},
	-- settings
  Damage = 1,
  Toss = false,
	-- effects
  Icon = "weapons/chess_castle_charge.png",
	LaunchSound = "/weapons/charge",
	ImpactSound = "/weapons/charge_impact",
  -- visual
  TipImage = {
		Unit = Point(2,4),
		Enemy = Point(2,1),
		Target = Point(2,1)
	}
}

-- Upgrade 1: Toss upgrade
Chess_Castle_Charge_A = Chess_Castle_Charge:new {
  ThrowRange = true
}

-- Upgrade 2: Damage upgrade
Chess_Castle_Charge_B = Chess_Castle_Charge:new {
  Damage = 3
}

-- Both upgrades
Chess_Castle_Charge_AB = Chess_Castle_Charge:new {
  ThrowRange = true,
  Damage = 3
}

--- Can charge in any direction, can target mobile enemies if there is a space to put them
function Chess_Castle_Charge:GetTargetArea(start)
	local ret = PointList()

  -- in each direction, draw a full path
	for dir = DIR_START, DIR_END do
    local offset = DIR_VECTORS[dir]
    local point = start + offset
    if Board:IsValid(point) then
      -- if we have a pawn, needs to not be guarding and the space behind needs to be free
      if Board:IsPawnSpace(point)
        and not Board:GetPawn(point):IsGuarding()
        and not Board:IsBlocked(start - offset, PATH_FLYER) then
          ret:push_back(point)
      -- otherwise, open space is eligable for a charge attack, so add all spaces to the end
      elseif not Board:IsBlocked(point, PATH_PROJECTILE) then
        ret:push_back(point)
        for i = 2, 7 do
          point = start + offset * i
          -- if a pawn, add and stop
          if Board:IsPawnSpace(point) and not Board:GetPawn(point):IsGuarding() then
            ret:push_back(point)
            break
          -- if empty, add and try next space
          elseif not Board:IsBlocked(point, PATH_PROJECTILE) then
            ret:push_back(point)
          -- blocked means we are done
          else
            break
          end
        end
      end
    end
  end

  return ret
end

--[[--
  Deals the weapons damage to a target. Used to hide damage from preview

  @param  target  Point target for damage
  @param  amount  Amount of damage to deal
]]
function Chess_Castle_Charge:ScriptDamage(target, amount)
  Board:DamageSpace(SpaceDamage(target, amount))
end

--- Flip the target over ourselves
function Chess_Castle_Charge:GetSkillEffect(p1, p2)
	local ret = SkillEffect()
	local dirVec = DIR_VECTORS[GetDirection(p2 - p1)]
  local path = PATH_PROJECTILE
	local target = GetProjectileEnd(p1, p2, path)

  local doDamage = true
  -- empty means we reached the board edge, so extend target by 1
  if not Board:IsBlocked(target, path) then
    doDamage = false
    target = target + dirVec
  -- if its not a pawn or the pawn is not movable, no damage
  elseif not Board:IsPawnSpace(target) or Board:GetPawn(target):IsGuarding() then
    doDamage = false
  end


  -- move the mech
  local newPos = target - dirVec
  local moved = p1 ~= newPos
  if moved then
    ret:AddCharge(Board:GetSimplePath(p1, newPos), NO_DELAY)
  end

  -- deal damage if required
  if doDamage then
    -- upgrade causes target to land where we started
    -- if no upgrade or we did not move, target lands behind us
    -- upgraded lands the target where we started
    local landing
    if self.ThrowRange and moved then
      landing = p1
    else
      landing = newPos - dirVec
    end
    local toss = PointList()
    toss:push_back(target)
    toss:push_back(landing)

    -- fake punch for animation, then toss the unit
    ret:AddMelee(newPos, SpaceDamage(target, 0))
    ret:AddLeap(toss, FULL_DELAY)
    -- add damage where the target used to be. Used for damage for the weapon preview
    -- if we add damage to the new position, it may show as targeting the attacking mech
    -- TODO: weapon preview lib
  	ret:AddDamage(helpers.safeDamage(target, self.Damage))

    -- add damage using a script, so it does not show in preview
    ret:AddScript("Chess_Castle_Charge:ScriptDamage("..landing:GetString()..","..self.Damage..")")
  	ret:AddBounce(landing, 3)
  end

  return ret
end
