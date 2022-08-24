local mod = mod_loader.mods[modApi.currentMod]
local config = mod.config
local achvTrigger = mod:loadScript("achievementTriggers")
local helpers = mod:loadScript("libs/helpers")
local pawnMove = mod:loadScript("libs/pawnMoveSkill")
local previewer = mod:loadScript("weaponPreview/api")
local saveData = mod:loadScript("libs/saveData")
local tips = mod:loadScript("libs/tutorialTips")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "The knight leaps 2 spaces in one direction, then 1 to either side. The first movement upgrade allows leaping 3 spaces in one direction, and later upgrades allow repeating a leap in one direction."
trait:Add{
  PawnTypes = "Chess_Knight",
  Icon = "img/combat/icons/icon_knight_move.png",
  IconGlow = "img/combat/icons/icon_empty_glow.png",
  Title = "Knight Movement",
  Description = HELP_TEXT
}
tips:Add{
	id = "Knight_Move",
	title = "Knight Movement",
	text = HELP_TEXT
}
tips:Add{
	id = "Knight_Attack",
	title = "Knight Targets",
	text = "The knight cannot attack units with more health, factoring in armor, ACID, and damage upgrades. The knight also cannot attack shielded units, or units that leave a corpse on death. The knight can target mountains if they are damaged."
}

--[[--
  Gets the max health for a pawn. Will be a little low in the mech tester

  @param pawn  Pawn to get health for
  @return Max health for the pawn.
]]
local function getPawnMaxHealth(pawn)
  -- if no region, use base health, won't consider pilot and other upgrades but better than nothing
  if saveData.dataUnavailable() then
    return _G[pawn:GetType()]:GetHealth()
  end
  -- fetch from save data if available
  return saveData.getPawnKey(pawn, "max_health")
end

--[[--
  Determines the equivelent health after applying status effects for a unit, used for attack strength comparisons

  @param pawn    Pawn of focus
  @param useMax  If true, returns the maximum health. False returns the current health
  @return  True if the point is valid
]]
local function getHealthEquivelent(pawn, useMax)
  -- when using max, return highest possible health
  -- no max returns current health
  local health
  if useMax then
    health = getPawnMaxHealth(pawn)
  else
    health = pawn:GetHealth()
  end

  -- ignore ACID if using max health
  if not useMax and pawn:IsAcid() then
    health = math.ceil(health / 2)
  -- note this returns true even if acid
  -- TODO: this is pretty unreliable when it comes to psions, is there a way to detect armor reliably that does not depend on save data?
  elseif pawn:IsArmor() then
    health = health + 1
  end

  return health
end

--[[--
  Determines if a point is valid for knight movement or attack

  @param point       Point targeting
  @param isAttack    If true, we are attacking so pawns and holes can be targeted
  @param maxDamage   Max damage the knight can deal
  @return  True if the point is valid
]]
local function pointValid(point, isAttack, maxDamage)
  -- invalid points immediately fail
  if not Board:IsValid(point) then
    return false
  end

  -- if not blocked, attack allows anything, but stop holes for normal, non flying movement
  if not Board:IsBlocked(point, isAttack and PATH_FLYER or Pawn:GetPathProf()) then
    return true
  end

  -- if blocked, movement will fail. attacks may work though
  if not isAttack then
    return false
  end

  -- can target mountains provided they are damaged
  if Board:GetTerrain(point) == TERRAIN_MOUNTAIN then
    if Board:GetHealth(point) == 1 then
      return true
    else
      previewer:AddDesc(point, "knight_mountain")
      return false
    end
  end

  -- if not a pawn, means blocked by a building or mountain
  local pawnAtPoint = Board:GetPawn(point)
  if pawnAtPoint == nil then
    return false
  end

  -- skip remaining logic in tooltips to save some effort
  -- plus, some code later crashes in modloader 2.4.0, so prevents a crash
  if helpers.isTooltip() then
    return true
  end

  -- no attacking pawns with a corpse
  if pawnAtPoint:IsCorpse() then
    previewer:AddDesc(point, "knight_corpse")
    return false
  end

  -- no attacking shielded or frozen enemies, that takes 2 hits
  if pawnAtPoint:IsShield() then
    previewer:AddDesc(point, "knight_shielded")
    return false
  end
  if pawnAtPoint:IsFrozen() then
    previewer:AddDesc(point, "knight_frozen")
    return false
  end

  -- cap based on knight's and enemies health
  if (maxDamage < getHealthEquivelent(pawnAtPoint, false)) then
    previewer:AddDesc(point, "knight_too_high_" .. maxDamage)
    return false
  end

  return true
end

--[[--
  Knight Move: 2 spaces in one direction, then 1 space on the other axis
]]
Chess_Knight_Move = pawnMove.ExtendDefaultMove{
  IsAttack = false
}

--[[--
  Moves:
   1: normal (for pilot ability)
   2: Knight
   3: Knight + threeleaper
   4: Knight x2 + threeleaper
   5: Knight x2 + threeleaper x2
   6: Knight x3 + threeleaper x2
]]
function Chess_Knight_Move:GetTargetAreaExt(p1, move)
  if not helpers.isTooltip() and not IsTestMechScenario() then
    tips:Trigger(self.IsAttack and "Knight_Attack" or "Knight_Move", p1)
  end
  local ret = PointList()
  local move = self.IsAttack and 2 or move or Pawn:GetMoveSpeed()
  if move < 1 then
    return ret
  end

  -- add a terrain description for max damage
  -- max damage will use knight's max health if shielded
  local maxDamage = 0
  if self.IsAttack then
    maxDamage = getHealthEquivelent(Pawn, config.knightCapMax or Pawn:IsShield()) + self.LessSelfDamage
    previewer:AddDesc(p1, "knight_max_" .. maxDamage)
  end

  -- all four directions
  local both = move > 1 and 3 or 1
  for dir = DIR_START, DIR_END do
    -- both opposite axises, only 1 axis if move is 1
    for d = 1, both, 2 do
      -- direction of this movement
      local offset = DIR_VECTORS[dir] * 2 + DIR_VECTORS[(dir + d) % 4]
      local point = p1 + offset
      if pointValid(point, self.IsAttack, maxDamage) then
        ret:push_back(point)

        -- second knight leap
        -- note IsAttack is never true after here
        if move >= 4 then
          point = point + offset
          if pointValid(point, false, 0) then
            ret:push_back(point)

            --  third leap
            if move >= 6 then
              point = point + offset
              if pointValid(point, false, 0) then
                ret:push_back(point)
              end
            end
          end
        end
      end
    end

    -- 3+ gives threeleaper
    -- 5+ gives double threeleaper
    if move >= 3 then
      -- direction of movement
      local offset = DIR_VECTORS[dir] * 3
      local point = p1 + offset
      if pointValid(point, false, 0) then
        ret:push_back(point)

        -- double threeleaper
        if move >= 5 then
          point = point + offset
          if pointValid(point, false, 0) then
            ret:push_back(point)
          end
        end
      end
    end
  end

  return ret
end

--[[--
  Divides a point elementwise by the given number, flooring any remainder

  @param point  Point to divide
  @param amount  Divisor
  @return  Divided point
]]
local function dividePoint(point, divisor)
  return Point(math.floor(point.x / divisor), math.floor(point.y / divisor))
end

--- Knight makes leaping movements. Will make multiple leaps if over 3 tiles
function Chess_Knight_Move:GetSkillEffectExt(p1, p2, ret)
  local ret = ret or SkillEffect()

  -- if the movement is too far, add a middle move
  local middle = p1
  local dist = p1:Manhattan(p2)
  -- if greater than 3, takes at least 2 moves
  if dist > 3 then
    local start = p1
    local offset
    -- if greater than 6, 3 moves
    if dist > 6 then
      offset = dividePoint(p2 - p1, 3)
      start = p1 + offset
      helpers.addLeap(ret, p1, start)
    else
      offset = dividePoint(p2 - p1, 2)
    end

    -- move from start to middle
    middle = start + offset
    helpers.addLeap(ret, start, middle)
  end

  -- add final move
  helpers.addLeap(ret, middle, p2)

  return ret
end

--[[--
  Knight Smite: knight move onto target for instant kill

  Upgrades: Push and Less Self Damage
]]
Chess_Knight_Smite = Chess_Knight_Move:new {
  -- base stats
  Class = "Prime",
  Damage = DAMAGE_DEATH,
  PowerCost = 1,
  Upgrades = 2,
  UpgradeCost = {1, 2},
  -- settings
  IsAttack = true,
  Push = false,
  LessSelfDamage = 0,
  -- effects
  Icon = "weapons/chess_knight_stomp.png",
  LaunchSound = "/weapons/modified_cannons",
  ImpactSound = "/impact/generic/explosion",
  -- visual
  TipImage = {
    Unit        = Point(2,3),
    Enemy       = Point(1,1),
    Target      = Point(1,1),
    CustomEnemy = "Firefly1"
  }
}

-- Push upgrade
Chess_Knight_Smite_A = Chess_Knight_Smite:new {
  Push = true,
  TipImage = {
    Unit = Point(2,3),
    Enemy = Point(1,1),
    Enemy2 = Point(2,1),
    Target = Point(1,1),
    CustomEnemy = "Firefly1"
  }
}

-- Damage upgrade
Chess_Knight_Smite_B = Chess_Knight_Smite:new {
  LessSelfDamage = 1
}

-- Both upgrades
Chess_Knight_Smite_AB = Chess_Knight_Smite_A:new {
  Push = true,
  LessSelfDamage = 1
}

--[[--
  Kills the enemy at the given point, dealing self damage to the attacker

  @param  target  Point target for damage
  @param  selfDamage  amount of damage to deal the attacking mech
]]
function Chess_Knight_Smite:Squash(target, selfDamage)
  -- move the mech out of the way so it does not die
  Pawn:SetSpace(Point(-1,-1))

  -- if attacking a pawn, check if its a boss pawn for achievement
  if achvTrigger:available("one_shot") and Board:IsPawnSpace(target) then
    -- must be at max health
    local pawn = Board:GetPawn(target)
    local maxHealth = getPawnMaxHealth(pawn)
    -- require max health to be 5 or more, removes cases of bosses with multiple parts that are easy to one shot (slime, swarmers)
    if maxHealth >= 5 and pawn:GetHealth() == maxHealth then
      local type = pawn:GetType()
      if _G[type].Tier == TIER_BOSS then
        achvTrigger:trigger("one_shot")
      end
    end
  end

  Board:DamageSpace(SpaceDamage(target, DAMAGE_DEATH))

  -- move the mech back, then self damage
  Pawn:SetSpace(target)
  -- doing these in one damage was giving me bugs, so one for animation and one for damage
  if selfDamage > 0 then
    Board:DamageSpace(SpaceDamage(target, selfDamage))
    Board:DamageSpace(helpers.animationDamage(target, "ExploAir1"))
  end
end

--- Moves the knight and instantly kills the target
function Chess_Knight_Smite:GetSkillEffect(p1, p2)
  local ret = SkillEffect()

  -- crack on boost
  local addCrackPreview = false
  if Pawn:IsBoosted() then
    addCrackPreview = true
    local crackDamage = SpaceDamage(p1, 0)
    crackDamage.iCrack = EFFECT_CREATE
    crackDamage.bHide = true -- does not show properly in the preview when we crack before leap
    ret:AddDamage(crackDamage)
  end

  -- move mech
  helpers.addLeap(ret, p1, p2)

  -- attack target if available
  local target = Board:GetPawn(p2)
  if target ~= nil and p2 ~= Pawn:GetSpace() then
    -- deal damage based on targets health
    local selfDamage = getHealthEquivelent(target) - self.LessSelfDamage

    -- add damage for display at self, skip at target as that makes the preview show the mech dying
    if selfDamage > 0 then
      local selfDamage = SpaceDamage(p1, selfDamage)
      if Pawn:IsBoosted() then
        selfDamage.iCrack = EFFECT_CREATE
      end
      previewer:AddDamage(selfDamage)
      addCrackPreview = false -- including in self damage here
    end

    -- run kill script
    ret:AddScript("Chess_Knight_Smite:Squash("..p2:GetString()..","..selfDamage..")")
  else
    if Board:GetTerrain(p2) == TERRAIN_MOUNTAIN then
      -- attack mountain and mech
      ret:AddDamage(SpaceDamage(p2, 1))
    end
  end

  -- if I want cracking to show in the tooltip, I must crack after the leap
  if addCrackPreview then
    local crackDamage = SpaceDamage(p1, 0)
    crackDamage.iCrack = EFFECT_CREATE
    -- the annoying part is I can only use the previewer to crack if I also include damage in the previewer
    -- if I want cracking to show in the tooltip I must either crack after leaping outside of preview (looks dumb) or crack after leaping with damage in preview (wrong here)
    -- to work around this, I simply crack the tile twice. however this means if I leap from an ice tile it will fully break the ice tile
    -- setting the terrain to ice works around this
    if Board:GetTerrain(p1) == TERRAIN_ICE and Board:GetHealth(p1) == 2 then
      crackDamage.iTerrain = TERRAIN_ICE
    end
    ret:AddDamage(crackDamage)
  end

  -- bounce a bit on landing
  ret:AddBounce(p2, 3)

  -- push effect on land
  if self.Push then
    for dir = DIR_START, DIR_END do
      -- actual push
      local point = p2 + DIR_VECTORS[dir]
      local damage = SpaceDamage(point, 0, dir)
      damage.sAnimation = PUSH_ANIMS[dir]
      ret:AddDamage(damage)
      -- increment pushes for achievement
      achvTrigger:checkPush(ret, point, dir)
    end
  end

  return ret
end
