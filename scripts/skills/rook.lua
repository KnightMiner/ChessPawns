local mod = mod_loader.mods[modApi.currentMod]
local config = mod.config
local achvTrigger = mod:loadScript("achievementTriggers")
local cutils = mod:loadScript("libs/CUtils")
local helpers = mod:loadScript("libs/helpers")
local previewer = mod:loadScript("weaponPreview/api")
local tips = mod:loadScript("libs/tutorialTips")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "The rook can move up to 7 spaces in a single direction. If the rook's speed is greater than 7, he can use the extra in a second direction."
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

--[[--
  Rook Move: any number of spaces in a straight line

  Upgrade: Move extra spaces in a second line
]]
Chess_Rook_Move = {}
function Chess_Rook_Move:GetTargetArea(p1)
  tips:Trigger("Rook_Move", p1)
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
  Push = false,
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

-- Upgrade 1: Toss upgrade
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

-- Upgrade 2: Damage upgrade
Chess_Castle_Charge_B = Chess_Castle_Charge:new {
  Damage = 3
}

-- Both upgrades
Chess_Castle_Charge_AB = Chess_Castle_Charge_A:new {
  Push = true,
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
      -- if there is a blockage, try melee throw
      if Board:IsBlocked(point, PATH_PROJECTILE) then
        -- space behind must be free
        if not Board:IsBlocked(start - offset, PATH_FLYER) then
          -- must be a pawn and not be guarding
          -- or must be a mountain
          if (Board:IsPawnSpace(point) and not Board:GetPawn(point):IsGuarding())
              or (config.rookRockThrow and Board:GetTerrain(point) == TERRAIN_MOUNTAIN) then
            ret:push_back(point)
          end
        end
      -- otherwise, open space is eligable for a charge attack, so add all spaces to the end
      else
        ret:push_back(point)
        for i = 2, 7 do
          point = start + offset * i
          -- if a pawn, add and stop
          if Board:IsPawnSpace(point) then
            if not Board:GetPawn(point):IsGuarding() then
              ret:push_back(point)
            end
            break
          -- can target mountains to throw a rock
          elseif config.rookRockThrow and Board:GetTerrain(point) == TERRAIN_MOUNTAIN then
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
  Spawns in a rock on a mountain, as vanilla does not like spawning units on mountains

  @param  space  Point to place the rock
]]
function Chess_Castle_Charge:AddRock(space)
  -- start by removing the mountain
  local mountainHealth = 0
  if Board:GetTerrain(space) == TERRAIN_MOUNTAIN then
    mountainHealth = cutils.GetTileHealth(Board, space)
    Board:SetTerrain(space, TERRAIN_RUBBLE)
  end

  -- spawn in the rock
  local rock = SpaceDamage(space, 0)
  rock.sPawn = "RockThrown"
  Board:DamageSpace(rock)

  -- then add the mountain back if we had one
  if mountainHealth > 0 then
    Board:SetTerrain(space, TERRAIN_MOUNTAIN)
    cutils.SetTileHealth(Board, space, mountainHealth)
  end
end

--[[--
  Checks if the given damage is enough to kill a pawn

  @param point    Pawn location
  @param amount   Amount of damage to deal
  @param pushDir  Direction of push before damage, to check if it deals extra damage
  @return  True if the amount of damage is enough to kill this pawn
]]
local function willDamageKill(pawn, amount, pushDir)
  -- ice and shield always takes 2 hits to break
  if pawn:IsFrozen() or pawn:IsShield() then
    return false
  end

  local health = pawn:GetHealth()
  -- if pushed, check if we will deal push damage or entirely miss
  if pushDir then
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

--[[--
  Checks if the current charge attack would trigger the achievement

  @param point    Point the pawn lands
  @param offsetDir  Direction the pawn was thrown. nil if push is disabled
]]
function Chess_Castle_Charge:CheckAchievement(point, offsetDir)
  local pawn = Board:GetPawn(point)

  -- ensure the space has an exploding pawn
  if pawn ~= nil and helpers.pawnExplodes(pawn:GetType()) then
    -- count how many enemies will be killed
    local kills = 0
    for dir = DIR_START, DIR_END do
      local offset = point + DIR_VECTORS[dir]
      -- if the offset dir is nil, no push
      -- if its a direction 0-3, pushes must be +- 1 away from that
      local pushDir = offsetDir ~= nil and ((offsetDir+dir) % 2 == 1) and dir or nil
      if Board:IsPawnSpace(offset) and Board:IsPawnTeam(offset, TEAM_ENEMY)
          and willDamageKill(Board:GetPawn(offset), 2, pushDir) then
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
  local dir = GetDirection(p2 - p1)
  local dirVec = DIR_VECTORS[dir]
  local path = PATH_PROJECTILE
  local target = GetProjectileEnd(p1, p2, path)

  local doDamage = true
  local isMountain = config.rookRockThrow and Board:GetTerrain(target) == TERRAIN_MOUNTAIN
  -- empty means we reached the board edge, so extend target by 1
  if not Board:IsBlocked(target, path) then
    doDamage = false
    target = target + dirVec
  -- if its not a pawn or mountain, or its a pawn and the pawn is not movable, no damage
  elseif not isMountain and (not Board:IsPawnSpace(target) or Board:GetPawn(target):IsGuarding()) then
    doDamage = false
  end

  -- move the mech
  local newPos = target - dirVec
  local moved = p1 ~= newPos
  if moved then
    ret:AddCharge(Board:GetSimplePath(p1, newPos), p1:Manhattan(newPos) * 0.1)
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
    local toss = PointList()
    toss:push_back(target)
    toss:push_back(landing)

    -- set direction to use it in the achievment check
    if self.Push then
      dir = GetDirection(p2 - p1)
    else
      dir = nil
    end

    -- mountains toss a rock
    if isMountain then
      -- damage the mountain, then spawn and throw the rock
      local damage = SpaceDamage(target, self.Damage)
      if moved then
        ret:AddDamage(damage)
      else
        ret:AddMelee(newPos, damage)
      end
      ret:AddScript(string.format("Chess_Castle_Charge:AddRock(%s)", target:GetString()))
      ret:AddLeap(toss, FULL_DELAY)
      ret:AddBounce(landing, 3)
      ret:AddSound("/impact/dynamic/rock")

      -- add a fake rock for the preview
      local fakeRock = SpaceDamage(landing, 0)
      fakeRock.sPawn = "RockThrown"
      previewer:AddDamage(fakeRock)
    else
      -- fake punch for pawn animation, real punch for mountain
      if not moved then
        ret:AddMelee(newPos, SpaceDamage(target, 0))
      end
      -- otherwise its a pawn, toss the unit
      ret:AddLeap(toss, FULL_DELAY)
      ret:AddBounce(landing, 3)

      -- check the achievement
      if achvTrigger:available("pawn_grenade") then
        ret:AddScript(string.format("Chess_Castle_Charge:CheckAchievement(%s, %d)", landing:GetString(), dir))
      end
      -- increment pushes for achievement
      achvTrigger:checkPush(ret, target)

      -- add damage where the target used to be. Used for damage for the weapon preview
      -- if we add damage to the new position, it may show as targeting the attacking mech
      previewer:AddDamage(SpaceDamage(target, self.Damage))
      -- real damage, hidden from preview
      local damage = SpaceDamage(landing, self.Damage)
      damage.bHide = true
      ret:AddDamage(damage)
    end

    -- push to either side
    if self.Push then
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

  return ret
end
