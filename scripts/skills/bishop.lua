local mod = mod_loader.mods[modApi.currentMod]
local achvTrigger = mod:loadScript("achievementTriggers")
local diagonal = mod:loadScript("libs/diagonalMove")
local helpers = mod:loadScript("libs/helpers")
local tips = mod:loadScript("libs/tutorialTips")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
local HELP_TEXT = "The bishop can move up to 7 spaces in a single diagonal. If the bishops's speed is greater than 7, you can use the extra to move in any orthogonal direction."
trait:Add{
  PawnTypes = "chess_bishop",
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

  Upgrade: Move extra spaces in a second line
]]
Chess_Bishop_Move = {}
function Chess_Bishop_Move:GetTargetArea(p1)
  tips:Trigger("Bishop_Move", p1)
  -- rook moves up to 7 in one direction, extra allows a second move on another axis
  local move = Pawn:GetMoveSpeed()
  local extra = 0
  if move > 7 then
    extra = move - 7
    move = 7
  end
  return helpers.getDiagonalMoves(p1, move, extra)
end

--[[--
  Draws the path for the given bishop movement
  All paths should consist of a single line, though some lines are diagonal
]]
function Chess_Bishop_Move:GetSkillEffect(p1, p2)
  local ret = SkillEffect()

  -- in diagonal line? use diagonal move util
  local offset = p2 - p1
  if math.abs(offset.x) == math.abs(offset.y) then
    diagonal.addMove(ret, p1, p2)
  else
    ret:AddMove(Board:GetPath(p1, p2, Pawn:GetPathProf()), FULL_DELAY)
  end

  return ret
end

--[[--
  Bishop Charge: charge diagonal and flip enemy overself

  Upgrades: Phase and Damage
]]
Chess_Bishop_Charge = Chess_Castle_Charge:new {
  -- base stats
  PowerCost = 0,
  Upgrades = 2,
  UpgradeCost = {2, 3},
  -- settings
  Diagonal = true,
  -- effects
  Icon = "weapons/chess_bishop_charge.png",
  -- visual
  TipImages = {
    -- tip image with mountain config option
    Mountain = {
      Unit          = Point(3,3),
      Enemy         = Point(4,2),
      Target        = Point(4,2),
      Second_Origin = Point(3,3),
      Mountain      = Point(1,1),
  		Second_Target = Point(1,1)
    },
    -- tip image with no mountain enabled
    Normal = {
      Unit          = Point(2,2),
      Enemy         = Point(3,1),
      Target        = Point(3,1),
      Second_Origin = Point(3,3),
      Enemy2        = Point(1,1),
  		Second_Target = Point(1,1)
    }
  }
}
Chess_Bishop_Charge.TipImage = Chess_Bishop_Charge.TipImages.Mountain

-- Upgrade 1: Push upgrade
Chess_Bishop_Charge_A = Chess_Bishop_Charge:new {
  Phase = true,
  TipImage = {
    Unit     = Point(3,0),
    Building = Point(2,1),
    Enemy    = Point(0,3),
    Target   = Point(0,3)
  }
}

-- Upgrade 2: Damage upgrade
Chess_Bishop_Charge_B = Chess_Bishop_Charge:new {
  Damage = 3
}

-- Both upgrades
Chess_Bishop_Charge_AB = Chess_Bishop_Charge_A:new {
  Phase = true,
  Damage = 3
}

-- add bishop to selection screen
modApi:addModsInitializedHook(function()
  local oldGetStartingSquad = getStartingSquad
  function getStartingSquad(choice, ...)
    -- get vanilla results
    local result = oldGetStartingSquad(choice, ...)
    if not achvTrigger:hasSecret() then
      return result
    end

    -- if the squad is chess pawns, insert bishop mech in
    if result[1] == "Chess Pawns" then
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
