local mod = mod_loader.mods[modApi.currentMod]
local cutils = mod:loadScript("libs/CUtils")
local helpers = mod:loadScript("libs/helpers")
local previewer = mod:loadScript("weaponPreview/api")
local tips = mod:loadScript("libs/tutorialTips")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "The king has limited movement, but can move in any of the 8 directions. The first movement upgrade allows 2 move in any of the 8 directions, later upgrades alternate between orthogonal and diagonal."
trait:Add{
  PawnTypes = { "Chess_King" },
  Icon = { "img/combat/icons/icon_king_move.png", "img/combat/icons/icon_empty_glow.png", Point(0,8) },
  Description = {"King Movement", HELP_TEXT}
}
tips:Add{
	id = "King_Move",
	title = "King Movement",
	text = HELP_TEXT
}

--[[--
  Adds all moves extending out in one direction to the object

  @param ret       SkillEffect instance
  @param start     Start Point
  @param offset    Offset direction Point
  @param distance  number of spaces to travel
]]
local function addDirectionMoves(ret, start, offset, distance)
  for d = 1, distance do
    local point = start + offset * d
    if Board:IsValid(point) and not Board:IsBlocked(point, PATH_FLYER) then
      ret:push_back(point)
    end
  end
end

--[[--
  King Move: 1 space in any direction

  Upgrades: Alternate orthogonal and diagonal
]]
Chess_King_Move = {}
function Chess_King_Move:GetTargetArea(p1)
  tips:Trigger("King_Move", p1)
  local ret = PointList()

  -- first upgrade increases both, after that only 1 is increased
  local orthogonal, diagonal
  local move = Pawn:GetMoveSpeed()
  if (move <= 2) then
    orthogonal = move
    diagonal = move
  else
    orthogonal = 1 + math.ceil(move / 2)
    diagonal = 1 + math.floor(move / 2)
  end

  -- add moves in all directions
  for dir = DIR_START, DIR_END do
    -- verticals and horizontals
    local offset = DIR_VECTORS[dir]
    addDirectionMoves(ret, p1, offset, orthogonal)
    -- diagonals
    offset = offset + DIR_VECTORS[(dir + 1) % 4]
    addDirectionMoves(ret, p1, offset, diagonal)
  end

  return ret
end

--- Move if a line, leap otherwise
function Chess_King_Move:GetSkillEffect(p1, p2)
  local ret = SkillEffect()

  -- if not a straight line, need to leap
  if p1.x ~= p2.x and p1.y ~= p2.y then
    helpers.addLeap(ret, p1, p2)
  else
    ret:AddMove(Board:GetPath(p1, p2, Pawn:GetPathProf()), FULL_DELAY)
  end

  return ret
end

--[[--
  Spawn Pawn: Spawns up to 2 pawns to do the king's fighting

  Upgrades: Alternate distance and diagonal
]]
Chess_Spawn_Pawn = Deployable:new {
  -- base stats
  Class       = "Ranged",
  Limited     = 0,
  Damage      = 0,
  PowerCost   = 2,
  Upgrades    = 2,
  UpgradeCost = {2, 3},
  -- settings
  Deployed    = "Chess_Pawn",
  DeployedAlt = "Chess_Pawn_Alt",
  -- effects
  Icon          = "weapons/chess_spawn_pawn.png",
  Projectile    = "effects/chess_shotup_pawn.png",
  ProjectileAlt = "effects/chess_shotup_pawn_alt.png",
  LaunchSound   = "/props/factory_launch",
  ImpactSound   = "/impact/generic/mech",
  -- visual
  TipImage = {
  Unit          = Point(1,3),
  Target        = Point(1,1),
  Enemy         = Point(2,1),
  Second_Origin = Point(1,1),
  Second_Target = Point(2,1),
  }
}

-- Range
Chess_Spawn_Pawn_A = Chess_Spawn_Pawn:new {
  Deployed    = "Chess_Pawn_A",
  DeployedAlt = "Chess_Pawn_A_Alt",
  TipImage = {
  Unit          = Point(1,3),
  Target        = Point(1,1),
  Enemy         = Point(3,1),
  Second_Origin = Point(1,1),
  Second_Target = Point(3,1),
  }
}

-- Explosion
Chess_Spawn_Pawn_B = Chess_Spawn_Pawn:new {
  Deployed    = "Chess_Pawn_B",
  DeployedAlt = "Chess_Pawn_B_Alt",
  TipImage = {
    Unit          = Point(2,3),
    Target        = Point(2,1),
    Enemy         = Point(3,1),
    CustomEnemy   = "Firefly1",
    Hole          = Point(2,0),
    Second_Origin = Point(2,3),
    Second_Target = Point(2,0)
  }
}

-- Both
Chess_Spawn_Pawn_AB = Chess_Spawn_Pawn_B:new {
  Deployed    = "Chess_Pawn_AB",
  DeployedAlt = "Chess_Pawn_AB_Alt"
}

-- true if it deploys a alt colored pawn, false deploys a normal. Unset is not a pawn
local CHESS_PAWNS = {
  Chess_Pawn        = true,
  Chess_Pawn_Alt    = false,
  Chess_Pawn_A      = true,
  Chess_Pawn_A_Alt  = false,
  Chess_Pawn_B      = true,
  Chess_Pawn_B_Alt  = false,
  Chess_Pawn_AB     = true,
  Chess_Pawn_AB_Alt = false,
}

-- true if the pawn type explodes
local PAWN_EXPLODES = {
  Chess_Pawn_B      = true,
  Chess_Pawn_B_Alt  = true,
  Chess_Pawn_AB     = true,
  Chess_Pawn_AB_Alt = true,
}

-- default pawn color for tooltips or if we cannot find the mech color
local DEFAULT_COLOR = 3

--[[--
  Gets the color of the mech

  @return Mech color, or DEFAULT_COLOR if missing
]]
local function getColor(pawnId)
  local color = nil
  if type(GameData) == 'table' and type(GameData.current) == 'table' and type(GameData.current.colors) == 'table' then
    color = GameData.current.colors[pawnId+1]
  end
  return color or DEFAULT_COLOR
end

-- Allows targeting water and holes instead of just land
function Chess_Spawn_Pawn_B:GetTargetArea(point)
  local ret = PointList()

  for dir = DIR_START, DIR_END do
    for i = 2, self.ArtillerySize do
      local curr = Point(point + DIR_VECTORS[dir] * i)
      if not Board:IsValid(curr) then
        break
      end

      if not Board:IsBlocked(curr, PATH_FLYER) then
        ret:push_back(curr)
      end
    end
  end

  return ret
end

-- Logic to limit to 2 pawns and to alternate colors
function Chess_Spawn_Pawn:GetSkillEffect(p1, target)
  local ret = SkillEffect()

  -- if true, we deploy the alternate color pawn
  local deployAlt = false
  local mechId = Pawn:GetId()
  -- determine if we need to kill an existing pawn
  local pawnToBeDestroyed = nil
  local pawnCount = 0
  local pawns = extract_table(Board:GetPawns(TEAM_PLAYER))
  -- simply iterate all pawns
  for _, pawnId in ipairs(pawns) do
    -- owner must be this mech, though skip that check in tooltips (owner not fully set)
    local pawn = Board:GetPawn(pawnId)
    if helpers.isTooltip() or cutils.GetPawnOwner(pawn) == mechId then
      -- pawn must be a chess pawn
      local pawnColor = CHESS_PAWNS[pawn:GetType()]
      if pawnColor ~= nil then
        -- increment found pawns, and store the color to spawn
        pawnCount = pawnCount + 1
        deployAlt = pawnColor
        -- oldest pawn is killed
        if pawnToBeDestroyed == nil then
          pawnToBeDestroyed = pawn
        end
      end
    end
  end

  -- if we found 2 pawns, kill the oldest one
  -- skip in tooltips, we cap at 2 pawns (at most 2 actions)
  if not helpers.isTooltip() and pawnCount >= 2 and pawnToBeDestroyed ~= nil then
    local space = pawnToBeDestroyed:GetSpace()
    local damage = SpaceDamage(space, DAMAGE_DEATH)
    damage.sAnimation = "explo_fire1"
    ret:AddDamage(damage)
    ret:AddSound("/impact/generic/explosion")
    ret:AddBounce(space, 3)

    -- damage preview on old pawn for explosions
    if PAWN_EXPLODES[pawnToBeDestroyed:GetType()] then
      for dir = DIR_START, DIR_END do
        previewer:AddDamage(SpaceDamage(space + DIR_VECTORS[dir], 2))
      end
    end
  end

  -- spawn the pawn
  local damage = SpaceDamage(target,0)
  local pawnType = deployAlt and self.DeployedAlt or self.Deployed
  -- set the color based on the current mech's pallet
  if GAME and not helpers.isTooltip() then
    _G[pawnType].ImageOffset = getColor(mechId)
  else
    _G[pawnType].ImageOffset = DEFAULT_COLOR
  end

  damage.sPawn = pawnType
  ret:AddArtillery(damage, deployAlt and self.ProjectileAlt or self.Projectile)

  -- if targeting water with an explosive pawn, preview that explosion
  if PAWN_EXPLODES[pawnType] and Board:IsBlocked(target, PATH_GROUND) then
    previewer:AddDamage(SpaceDamage(target, 2))
    for dir = DIR_START, DIR_END do
      previewer:AddDamage(SpaceDamage(target + DIR_VECTORS[dir], 2))
    end
  end

  return ret
end
