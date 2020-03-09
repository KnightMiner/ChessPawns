local mod = mod_loader.mods[modApi.currentMod]
local helpers = mod:loadScript("libs/helpers")
local trait = mod:loadScript("libs/trait")

-- Move tooltip --
trait:Add{
  PawnTypes = { "Chess_Pawn", "Chess_Pawn_A", "Chess_Pawn_Alt", "Chess_Pawn_A_Alt" },
  Icon = { "img/combat/icons/icon_pawn_move.png", "img/combat/icons/icon_empty_glow.png", Point(0,8) },
  Description = {"Pawn Movement", "Pawns can move up to 2 spaces in a single direction."}
}

-- Pawn explosions --
trait:Add{
  PawnTypes = { "Chess_Pawn_B", "Chess_Pawn_AB", "Chess_Pawn_B_Alt", "Chess_Pawn_AB_Alt" },
  Icon = { "img/combat/icons/icon_pawn_move_explode.png", "img/combat/icons/icon_explode_glow.png", Point(0,8) },
  Description = {"Explosive Pawn", "Pawns can move up to 2 spaces in a single direction.\nThis unit will always explode on death, dealing 2 damage to adjacent tiles."}
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
  Pawn Spear: 1 damage in any of the 4 directions

  Upgrade: Increases range by 1
]]
Chess_Pawn_Spear = Prime_Spear:new{
  Class        = "Unique",
  Range        = 1,
  PathSize     = 1,
  Damage       = 1,
  Push         = 1,
  PowerCost    = 0,
  Upgrades     = 1,
  UpgradeCost  = {1},
  LaunchSound  = "/weapons/sword",
  TipImage     = {
    Unit       = Point(2,3),
    Enemy      = Point(2,2),
    Target     = Point(2,2),
    CustomPawn = "Chess_Pawn"
  }
}

Chess_Pawn_Spear_A = Chess_Pawn_Spear:new {
  Range = 2,
  PathSize = 2,
  TipImage     = {
    Unit       = Point(2,3),
    Enemy      = Point(2,1),
    Target     = Point(2,1),
    CustomPawn = "Chess_Pawn_A"
  }
}
