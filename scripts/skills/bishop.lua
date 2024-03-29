local mod = mod_loader.mods[modApi.currentMod]
local config = mod.config
local achvTrigger = mod:loadScript("achievementTriggers")
local diagonal = mod:loadScript("libs/diagonalMove")
local helpers = mod:loadScript("libs/helpers")
local tips = mod:loadScript("libs/tutorialTips")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "The bishop can move up to 7 spaces in a single diagonal. If the bishops's speed is greater than 7, you can use the extra to move in any orthogonal direction."
trait:Add{
  PawnTypes = "Chess_Bishop",
  Icon = "img/combat/icons/icon_bishop_move.png",
  IconGlow = "img/combat/icons/icon_empty_glow.png",
  Title = "Bishop Movement",
  Description = HELP_TEXT
}
tips:Add{
	id = "Bishop_Move",
	title = "Bishop Movement",
	text = HELP_TEXT
}

--[[--
  Bishop Move: any number of spaces in a diagonal line

  Upgrade: Move extra spaces orthogonally
]]
Chess_Bishop_Move = Chess_Rook_Move:new{}

--[[--
  This function is a safer version of GetTargetArea as the weaponPreview lib injects code into all GetTargetArea functions
  Designed to be called externally by mods with custom movement skills

  @param p1    Pawn location
  @param move  Pawn move speed, defaults to Pawn:GetMoveSpeed()
  @return  Target area for this function
]]
function Chess_Bishop_Move:GetTargetAreaExt(p1, move)
  if not IsTestMechScenario() then
    tips:Trigger("Bishop_Move", p1)
  end
  local move = move or Pawn:GetMoveSpeed()
  local orthoSpeed, diagSpeed = self:SplitMoveSpeed(move or Pawn:GetMoveSpeed())
  return diagonal.getDiagonalMoves(p1, diagSpeed, orthoSpeed)
end


--- CauldronPilots compatibility: allow leaping diagnally
function Chess_Bishop_Move:CricketTargetArea(p1)
  -- start with defaukt move
  local ret = self:GetTargetAreaExt(p1)
  local defaultSpaces = extract_table(ret)
  local orthoSpeed, diagSpeed = self:SplitMoveSpeed(Pawn:GetMoveSpeed())
  -- add any bonus spaces diagonally in each direction
  for dir = DIR_START, DIR_END do
    local offset = DIR_VECTORS[dir] + DIR_VECTORS[(dir+1)%4]
    for i = 1, diagSpeed do
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
  Bishop Charge: charge diagonal and flip enemy overself

  Upgrades: Phase and Damage
]]
Chess_Bishop_Charge = Chess_Castle_Charge:new {
  -- base stats
  Class = "Science",
  PowerCost = 0,
  Upgrades = 2,
  UpgradeCost = {1, 2},
  -- settings
  Damage = 0,
  Push = true,
  Orthogonal = false,
  Diagonal = true,
  -- effects
  Icon = "weapons/chess_bishop_charge.png",
  -- visual
  TipImage = {
    Unit          = Point(2,2),
    Enemy         = Point(3,1),
    Target        = Point(3,1),
    Second_Origin = Point(2,2),
    Enemy2        = Point(0,0),
    Enemy3        = Point(2,3),
    Enemy4        = Point(3,2),
    Second_Target = Point(0,0)
  }
}

-- Only show the bishop charge when the achievements are completed
function Chess_Bishop_Charge:GetUnlocked()
  return achvTrigger:hasSecret()
end

-- vanilla does not support diagonal direciton, plus phase makes things a bit more difficult
function Chess_Bishop_Charge:GetTargetZone(p1, p2)
  local ret = PointList()
  ret:push_back(p2)
  -- proceed away from the point until the first blockage
  local direction = diagonal.minimize(p2 - p1)
  -- add spaces moving back to the mech
  local space = p2 - direction
  while space ~= p1 and Board:IsValid(space) and not Board:IsBlocked(space, PATH_PROJECTILE) do
    ret:push_back(space)
    space = space - direction
  end
  -- move forwards if the selected space is not blocked
  if not Board:IsBlocked(p2, PATH_PROJECTILE) then
    space = p2 + direction
    while Board:IsValid(space) and not Board:IsBlocked(space, PATH_PROJECTILE) do
      ret:push_back(space)
      space = space + direction
    end
    -- if the blockage is targetable, add it
    if Board:IsPawnSpace(space) and not Board:GetPawn(space):IsGuarding()
        or config.rookRockThrow and Board:GetTerrain(space) == TERRAIN_MOUNTAIN then
      ret:push_back(space)
    end
  end
  return ret
end

-- Upgrade 1: Orthogonal upgrade
Chess_Bishop_Charge_A = Chess_Bishop_Charge:new {
  Orthogonal = true,
  TipImage = {
    Unit          = Point(2,2),
    Enemy         = Point(3,2),
    Target        = Point(3,2),
    Second_Origin = Point(2,2),
    Enemy2        = Point(0,0),
    Enemy3        = Point(1,3),
    Enemy4        = Point(2,3),
    Second_Target = Point(0,0)
  }
}

-- Upgrade 2: Phase upgrade
Chess_Bishop_Charge_B = Chess_Bishop_Charge:new {
  Phase = true,
  TipImage = {
    Unit     = Point(3,0),
    Building = Point(2,1),
    Enemy    = Point(0,3),
    Target   = Point(0,3),
    Enemy2   = Point(2,0),
  }
}

-- Both upgrades
Chess_Bishop_Charge_AB = Chess_Bishop_Charge:new {
  Phase = true,
  Orthogonal = true,
  TipImage = {
    Unit          = Point(3,1),
    Building      = Point(2,1),
    Enemy         = Point(3,0),
    Enemy2        = Point(0,1),
    Enemy3        = Point(2,2),
    Enemy4        = Point(3,2),
    Target        = Point(2,2),
    Second_Origin = Point(3,1),
    Second_Target = Point(0,1)
  }
}

-- add bishop to selection screen
modApi:addModsInitializedHook(function()
  local oldGetStartingSquad = getStartingSquad
  function getStartingSquad(choice, ...)
    -- get vanilla results
    local result = oldGetStartingSquad(choice, ...)

    -- if the squad is chess pawns, insert bishop mech in
    if result[1] == "Chess Pawns" and achvTrigger:hasSecret() then
      local copy = {}
      for i, v in pairs(result) do
        copy[#copy+1] = v
      end
      copy[#copy+1] = "Chess_Bishop"
      return copy
    end

    return result
  end
end)
