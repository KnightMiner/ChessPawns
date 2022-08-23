local mod = mod_loader.mods[modApi.currentMod]
local config = mod.config
local achvTrigger = mod:loadScript("achievementTriggers")
local diagonal = mod:loadScript("libs/diagonalMove")
local helpers = mod:loadScript("libs/helpers")
local pawnMove = mod:loadScript("libs/pawnMoveSkill")
local previewer = mod:loadScript("weaponPreview/api")
local tips = mod:loadScript("libs/tutorialTips")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "The rook can move up to 7 spaces in a single direction. If the rook's speed is greater than 7, you can use the extra move diagonally."
trait:Add{
  PawnTypes = "Chess_Rook",
  Icon = "img/combat/icons/icon_rook_move.png",
  IconGlow = "img/combat/icons/icon_empty_glow.png",
  Title = "Rook Movement",
  Description = HELP_TEXT
}
tips:Add{
	id = "Rook_Move",
	title = "Rook Movement",
	text = HELP_TEXT
}
HELP_TEXT = "The rook can move up to 7 spaces in a single direction. If the rook's speed is greater than 7, you can use the extra in a second direction."
tips:Add{
	id = "Rook_Move_Corner",
	title = "Rook Movement",
	text = HELP_TEXT
}

--[[--
  Corner Rook Move: any number of spaces in a straight line

  Upgrade: Move extra spaces in a second line
  No longer used by default, in favor of diagonal style
]]
Chess_Rook_Move_Corner = pawnMove.ExtendDefaultMove()

function Chess_Rook_Move_Corner:GetTargetAreaExt(p1, move)
  -- rook moves up to 7 in one direction, extra allows a second move on another axis
  if not IsTestMechScenario() then
    tips:Trigger("Rook_Move_Corner", p1)
  end
  local move = move or Pawn:GetMoveSpeed()
  local offsetSpeed, orthoSpeed
  if move > 4 then
    -- from 5 to 8, get full 7 ortho speed
    -- +2 diagonal per move above 4 (so max speed at 8)
    orthoSpeed = 7
    offsetSpeed = move - 4
  else
    -- each speed is +2 ortho movement, with the exception of the first which grants 1
    -- no diagonal speed at all
    orthoSpeed = math.max(2 * move - 1, 0)
    offsetSpeed = 0
  end

  -- using a hash so we can skip duplicates
  local points = {}

  -- for some reason the 16 bit is set for PathProf, not sure what it means
  local path = Pawn:GetPathProf() % 16

  -- move in all four directions
  for dir = DIR_START, DIR_END do
    -- straight line
    local offset = DIR_VECTORS[dir]
    for x = 1, orthoSpeed do
      local linePoint = p1 + offset * x
      if not Board:IsValid(linePoint) then break end

      -- if blocked, we may still keep going, could be a pawn
      if Board:IsBlocked(linePoint, path) then
        if not diagonal.canMovePast(linePoint, path) then break end
      else
        -- free spaces means we keep this and possibly extend off to either side
        points[p2idx(linePoint)] = linePoint

        -- offsetSpeed means extend off sides
        if offsetSpeed > 0 then
          for s = 1, 3, 2 do
            local side = DIR_VECTORS[(dir+s)%4]
            for y = 1, extra do
              local sidePoint = linePoint + side * y
              if not Board:IsValid(linePoint) then break end

              -- if blocked, we might be done
              -- if not blocked, add point and keep going
              if Board:IsBlocked(linePoint, path) then
                if not diagonal.canMovePast(linePoint, path) then break end
              else
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

--- CauldronPilots compatibility: bonus spaces from CricketSkill
function Chess_Rook_Move_Corner:CricketTargetArea(p1)
  -- start with defaukt move
  local ret = self:GetTargetAreaExt(p1)
  local defaultSpaces = extract_table(ret)
  -- add any bonus spaces diagonally in each direction
  for dir = DIR_START, DIR_END do
    local offset = DIR_VECTORS[dir]
    for i = 1, Pawn:GetMoveSpeed() do
      local point = p1 + offset*i
      -- if this point is invalid, all later points will also be invalid
      if not Board:IsValid(point) then break end
			-- point must be somewhere they can land and not already included
      if not Board:IsBlocked(point, Pawn:GetPathProf()) and not list_contains(defaultSpaces, point) then
        ret:push_back(point)
      end
    end
  end

  return ret
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
function Chess_Rook_Move_Corner:GetSkillEffectExt(p1, p2, ret)
  local ret = ret or SkillEffect()
  local path = Pawn:GetPathProf()

  -- if not a straight line, find mid point for move
  local move
  local offset = p2 - p1
  if offset.x ~= 0 and offset.y ~= 0 then
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

        -- the path to that point must be valid, if not it must be the other point
        if not lineValid(p1, mid) or not lineValid(mid, p2) then
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
  Rook Move: any number of spaces in a straight line

  Upgrade: Move extra spaces diagonally
]]
Chess_Rook_Move = pawnMove.ExtendDefaultMove()

--[[--
  This function is a safer version of GetTargetArea as the weaponPreview lib injects code into all GetTargetArea functions
  Designed to be called externally by mods with custom movement skills

  @param p1    Pawn location
  @param move  Pawn move speed, defaults to Pawn:GetMoveSpeed()
  @return  Target area for this function
]]
function Chess_Rook_Move:GetTargetAreaExt(p1, move)
  if not IsTestMechScenario() then
    tips:Trigger("Rook_Move", p1)
  end
  local move = move or Pawn:GetMoveSpeed()
  local diagSpeed, orthoSpeed
  if move > 4 then
    -- from 5 to 8, get full 7 ortho speed
    -- +2 diagonal per move above 4 (so max speed at 8)
    orthoSpeed = 7
    diagSpeed = 2 * (move - 4)
  else
    -- each speed is +2 ortho movement, with the exception of the first which grants 1
    -- no diagonal speed at all
    orthoSpeed = math.max(2 * move - 1, 0)
    diagSpeed = 0
  end
  return diagonal.getDiagonalMoves(p1, diagSpeed, orthoSpeed)
end

--[[--
  This function is a safer version of GetSkillEffect as the weaponPreview lib injects code into all GetTargetArea functions
  It also allows a clean way to build on an existing skill effect

  @param p1   Pawn location
  @param p2   Target location
  @param ret  Existing SkillEffect instance
  @return  Effect for this move
]]
function Chess_Rook_Move:GetSkillEffectExt(p1, p2, ret)
  local ret = ret or SkillEffect()
  diagonal.lineMoveSkillEffect(ret, p1, p2)
  return ret
end

--[[--
  Castle Charge: charge forwards and flip enemy overself

  Upgrades: Toss and Damage
]]
Chess_Castle_Charge = Skill:new {
  -- base stats
  Class = "Brute",
  PowerCost = 0,
  Upgrades = 2,
  UpgradeCost = {1, 3},
  -- settings
  Damage = 1,
  Push = false,
  Phase = false,
  Orthogonal = true,
  Diagonal = false,
  ZoneTargeting = ZONE_CUSTOM,
  -- effects
  Icon = "weapons/chess_castle_charge.png",
  LaunchSound = "/weapons/charge",
  ImpactSound = "/weapons/charge_impact",
  -- visual
  TipImages = {
    -- tip image with mountain config option
    Mountain = {
      Unit          = Point(3,2),
      Enemy         = Point(3,3),
      Target        = Point(3,3),
      Second_Origin = Point(3,2),
      Mountain      = Point(0,2),
  		Second_Target = Point(0,2)
    },
    -- tip image with no mountain enabled
    Normal = {
      Unit   = Point(3,2),
      Enemy  = Point(0,2),
      Target = Point(0,2)
    }
  }
}
Chess_Castle_Charge.TipImage = Chess_Castle_Charge.TipImages.Mountain

--[[ Upgrade 1: Toss upgrade
Chess_Castle_Charge_A = Chess_Castle_Charge:new {
  Push = true,
  TipImages = {
    -- tip image with mountain config option
    Mountain = {
      Unit          = Point(3,2),
      Enemy         = Point(3,3),
      Enemy2        = Point(2,1),
      Target        = Point(3,3),
      Second_Origin = Point(3,2),
      Mountain      = Point(0,2),
  		Second_Target = Point(0,2)
    },
    -- tip image with no mountain enabled
    Normal = {
      Unit   = Point(3,2),
      Enemy  = Point(0,2),
      Enemy2 = Point(3,1),
      Target = Point(0,2)
    }
  }
}
Chess_Castle_Charge_A.TipImage = Chess_Castle_Charge_A.TipImages.Mountain
]]

-- Upgrade 1: Queen charge
Chess_Castle_Charge_A = Chess_Castle_Charge:new {
  Diagonal = true,
  TipImages = {
    -- tip image with mountain config option
    Mountain = {
      Unit          = Point(3,2),
      Enemy         = Point(3,3),
      Target        = Point(3,3),
      Second_Origin = Point(3,2),
      Mountain      = Point(1,0),
  		Second_Target = Point(1,0)
    },
    -- tip image with no mountain enabled
    Normal = {
      Unit   = Point(3,2),
      Enemy  = Point(1,0),
      Target = Point(1,0)
    }
  }
}
Chess_Castle_Charge_A.TipImage = Chess_Castle_Charge_A.TipImages.Mountain

-- Upgrade 2: Damage upgrade
Chess_Castle_Charge_B = Chess_Castle_Charge:new {
  Damage = 3
}

-- Both upgrades
Chess_Castle_Charge_AB = Chess_Castle_Charge_A:new {
  Damage = 3
}

-- adds a line to the target area
local function addLine(self, ret, start, offset)
  -- offset the point in each direction
  local point = start + offset
  if Board:IsValid(point) then
    for i = 1, 7 do
      point = start + offset * i
      -- need an open spot to move the mech
      local canTarget = not Board:IsBlocked(point - offset * (i == 1 and 2 or 1), PATH_FLYER)

      -- if a pawn, add and stop
      if Board:IsPawnSpace(point) then
        if canTarget and not Board:GetPawn(point):IsGuarding() then
          ret:push_back(point)
        end
        -- can phase through pawns
        if not self.Phase then break end
      -- can target mountains to throw a rock
      elseif config.rookRockThrow and Board:GetTerrain(point) == TERRAIN_MOUNTAIN then
        if canTarget then
          ret:push_back(point)
        end
        -- cannot phase through mountains
        break
      -- if empty, add and try next space
      elseif not Board:IsBlocked(point, PATH_PROJECTILE) then
        ret:push_back(point)
      -- blocked means we are done, unless phasing
      elseif not self.Phase then
        break
      end
    end
  end
end

--- Can charge in any direction, can target mobile enemies if there is a space to put them
function Chess_Castle_Charge:GetTargetArea(start)
  local ret = PointList()

  -- in each direction, draw a full path
  for dir = DIR_START, DIR_END do
    -- allow choosing one or both directions of charge
    local orthoOffset = DIR_VECTORS[dir]
    local diagOffset = orthoOffset + DIR_VECTORS[(dir+1)%4]
    if self.Orthogonal then
      addLine(self, ret, start, orthoOffset)
    end
    if self.Diagonal then
      addLine(self, ret, start, diagOffset)
    end
  end

  return ret
end

function Chess_Castle_Charge:GetTargetZone(origin, target)
	local targets = self:GetTargetArea(origin)
	local ret = PointList()

	local dir = diagonal.minimize(target-origin)
  LOG(dir)
	for i = 1, targets:size() do
    LOG(diagonal.minimize(targets:index(i) - origin))
		if diagonal.minimize(targets:index(i) - origin) == dir then
			ret:push_back(targets:index(i))
		end
	end

	return ret
end

--[[--
  Checks if the current charge attack would trigger the achievement

  @param point    Point the pawn lands
]]
function Chess_Castle_Charge:CheckAchievement(point)
  local pawn = Board:GetPawn(point)

  -- ensure the space has an exploding pawn
  if pawn ~= nil and helpers.pawnExplodes(pawn:GetType()) then
    -- count how many enemies will be killed
    local kills = 0
    for dir = DIR_START, DIR_END do
      local offset = point + DIR_VECTORS[dir]
      if Board:IsPawnSpace(offset) and Board:IsPawnTeam(offset, TEAM_ENEMY) and Board:IsDeadly(SpaceDamage(offset, 2), Board:GetPawn(offset)) then
        kills = kills + 1
      end
    end

    -- if we killed at least 2 enemies, grant achievement
    if kills >= 2 then
      achvTrigger:trigger("pawn_grenade")
    end
  end
end

--- Flip the target over ourselves
function Chess_Castle_Charge:GetSkillEffect(p1, p2)
  local ret = SkillEffect()
  local path = PATH_PROJECTILE

  -- fire in the direction based on type
  local dirVec = diagonal.minimize(p2 - p1)
  local target = diagonal.getProjectileEnd(p1, p2, path)
  local isDiagonal = math.abs(dirVec.x) == math.abs(dirVec.y)

  local doDamage = true
  local isMountain = config.rookRockThrow and Board:GetTerrain(target) == TERRAIN_MOUNTAIN
  -- if its not a pawn or mountain, or its a pawn and the pawn is not movable, no damage
  if not isMountain and (not Board:IsPawnSpace(target) or Board:GetPawn(target):IsGuarding()) then
    doDamage = false
  end

  -- move the mech
  local newPos = target - dirVec
  local moved = p1 ~= newPos
  if moved then
    if isDiagonal then
      diagonal.addMove(ret, p1, newPos)
    elseif self.Phase then
      ret:AddCharge(Board:GetPath(p1, newPos, PATH_FLYER), p1:Manhattan(newPos) * 0.1)
    else
      ret:AddCharge(Board:GetSimplePath(p1, newPos), p1:Manhattan(newPos) * 0.1)
    end
  end

  -- deal damage if required
  if doDamage then
    -- upgrade causes target to land where we started
    -- if no upgrade or we did not move, target lands behind us
    -- upgraded lands the target where we started
    local landing
    if moved then
      landing = p1
    else
      landing = newPos - dirVec
    end

    -- toss used for either case

    -- set direction to use it in the achievment check
    local dir
    if self.Push then
      dir = isDiagonal and -1 or GetDirection(p2 - p1)
    end

    -- mountains toss a rock
    if isMountain then
      -- damage the mountain
      local damage = SpaceDamage(target, self.Damage)
      if moved or isDiagonal then
        ret:AddDamage(damage)
      else
        ret:AddMelee(newPos, damage)
      end
      -- add a rocck firing from the mountain
      local rock = SpaceDamage(landing, 0)
      rock.sPawn = "RockThrown"
      ret:AddArtillery(target, rock, "effects/shotdown_rock.png", FULL_DELAY)
      ret:AddBounce(landing, 3)
      ret:AddSound("/impact/dynamic/rock")
    else
      -- fake punch for pawn animation
      if not moved and not isDiagonal then
        ret:AddMelee(newPos, SpaceDamage(target, 0))
      end
      -- toss the pawn
      local toss = PointList()
      toss:push_back(target)
      toss:push_back(landing)
      ret:AddLeap(toss, FULL_DELAY)
      ret:AddBounce(landing, 3)

      -- check the achievement, note this assumes no push to work
      if self.Damage > 0 then
        local targetPawn = Board:GetPawn(target)
        if targetPawn and helpers.pawnExplodes(targetPawn:GetType()) then
          for i = DIR_START, DIR_END do
            previewer:AddDamage(SpaceDamage(landing+DIR_VECTORS[i], 2))
          end
          if achvTrigger:available("pawn_grenade") then
            ret:AddScript(string.format("Chess_Castle_Charge:CheckAchievement(%s)", landing:GetString()))
          end
        end
      end
      -- increment pushes for other achievement
      achvTrigger:checkPush(ret, target)

      -- add damage where the target used to be. Used for damage for the weapon preview
      -- if we add damage to the new position, it may show as targeting the attacking mech
      previewer:AddDamage(SpaceDamage(target, self.Damage))
      -- real damage, hidden from preview
      local damage = SpaceDamage(landing, self.Damage)
      damage.bHide = true
      ret:AddDamage(damage)
    end

    if self.Push then
      if isDiagonal then
        -- push all four directions
        for i = DIR_START, DIR_END do
          local point = landing + DIR_VECTORS[i]
          local push = SpaceDamage(point, 0, i)
          push.sAnimation = "airpush_"..i
          ret:AddDamage(push)
          -- increment pushes for achievement
          achvTrigger:checkPush(ret, point, i)
        end
      else
        -- push to either side
        for i = -1, 1, 2 do
          local sideDir = (dir + i) % 4
          local point = landing + DIR_VECTORS[sideDir]
          local push = SpaceDamage(point, 0, sideDir)
          push.sAnimation = "airpush_"..sideDir
          ret:AddDamage(push)
          -- increment pushes for achievement
          achvTrigger:checkPush(ret, point, sideDir)
        end
      end
    end
  end

  return ret
end
