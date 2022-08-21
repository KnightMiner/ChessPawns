local mod = {
  id = "Knight_Chess",
  name = "Chess Pawns",
  version = "1.4.0",
  requirements = {},
  icon = "img/icon.png",
  modApiVersion = "2.6.4",
  config = {
    rookRockThrow = true,
    knightCapMax = false
  }
}

--[[--
  Helper function to load mod scripts

  @param  name   Script path relative to mod directory
]]
function mod:loadScript(path)
  return require(self.scriptPath..path)
end

--[[--
  Fixes skill names in pawns

  @param name  Weapon name to fix
]]
local function fixWeaponTexts(name)
  -- get name and description
  local base = _G[name]
  if not base then return end
  base.Name = Weapon_Texts[name .. "_Name"]
  base.Description = Weapon_Texts[name .. "_Description"]
  -- upgrade A description
  for _, key in ipairs({"_A", "_B"}) do
    local fullName = name .. key
    local upgrade = _G[fullName]
    if upgrade ~= nil then
      upgrade.UpgradeDescription =  Weapon_Texts[fullName .. "_UpgradeDescription"]
    end
  end
end

function mod:metadata()
  modApi:addGenerationOption(
    "rookRockThrow",
    "Rook Rock Throw",
    "If checked, the rook is allowed to target mountains, throwing a rock instead of a unit",
    { enabled = true }
  )
  modApi:addGenerationOption(
    "knightCapMax",
    "Knight Cap Max Health",
    "If checked, Knight Stomp is capped at the units max health. Unchecked means it caps at current health",
    { enabled = false }
  )
  modApi:addGenerationOption(
    "oldRookMovement",
    "Old Rook Movement Upgrade",
    "If checked, rook mech will use the old movement upgrades which allow it to take corners. If unchecked, uses the new diagonal move upgrades",
    { enabled = false }
  )
  modApi:addGenerationOption(
    "resetTutorialTips",
    "Reset Tutorial Tooltips",
    "Check to reset all tutorial tooltips for this profile",
    { enabled = false }
  )
end

function mod:init()
  -- script init
  self:loadScript("weaponPreview/api")
  if modApiExt then
    self.modApiExt = modApiExt
  else
    self.modApiExt = self:loadScript("modApiExt/modApiExt")
    self.modApiExt:init()
  end

  -- load sprites
  local sprites = self:loadScript("libs/sprites")
  sprites.addMechs(
    {
      Name = "chess_king",
      Default =           { PosX = -19, PosY = -18 },
      Animated =          { PosX = -19, PosY = -18, NumFrames = 4 },
      Broken =            { PosX = -19, PosY = -18 },
      SubmergedBroken =   { PosX = -19, PosY = -12 },
      Icon =              {},
    },
    {
      Name = "chess_knight",
      Default =           { PosX = -20, PosY = -15 },
      Animated =          { PosX = -20, PosY = -15, NumFrames = 5 },
      Submerged =         { PosX = -20, PosY =  -6 },
      Broken =            { PosX = -20, PosY = -15 },
      SubmergedBroken =   { PosX = -20, PosY =  -6 },
      Icon =              {},
    },
    {
      Name = "chess_rook",
      Default =           { PosX = -13, PosY = -7 },
      Animated =          { PosX = -13, PosY = -7, NumFrames = 4 },
      Submerged =         { PosX = -13, PosY = -1 },
      Broken =            { PosX = -13, PosY = -7 },
      SubmergedBroken =   { PosX = -13, PosY = -1 },
      Icon =              {},
    },
    {
      Name = "chess_bishop",
      Default =           { PosX = -13, PosY = -15 },
      Animated =          { PosX = -13, PosY = -15, NumFrames = 4 },
      Submerged =         { PosX = -13, PosY =  -9 },
      Broken =            { PosX = -13, PosY = -15 },
      SubmergedBroken =   { PosX = -13, PosY =  -9 },
      Icon =              {},
    },
    {
      Name = "chess_pawn",
      NoHanger = true,
      Default =           { PosX = -12, PosY = 0 },
      Animated =          { PosX = -12, PosY = 0, NumFrames = 4 },
      Death =             { PosX = -12, PosY = 0, NumFrames = 5, Time = 0.09, Loop = false },
      Icon =              {},
    },
    {
      Name = "chess_pawn_alt",
      NoHanger = true,
      Default =           { PosX = -12, PosY = 0 },
      Animated =          { PosX = -12, PosY = 0, NumFrames = 4 },
      Death =             { PosX = -12, PosY = 0, NumFrames = 5, Time = 0.09, Loop = false },
      Icon =              {},
    }
  )

  -- add palette
  modApi:addPalette({
    id   = "ChessWhite",
    name = "Chess White",
    image = "img/units/player/chess_knight_ns.png",
    colorMap = {
      PlateHighlight = {170, 245, 255},
      PlateLight     = {255, 255, 255},
      PlateMid       = {192, 208, 216},
      PlateDark      = {110, 133, 141},
      PlateOutline   = { 36,  37,  49},
      PlateShadow    = { 43,  50,  56},
      BodyColor      = { 89,  96, 103},
      BodyHighlight  = {175, 175, 175},
    }
  })

  -- weapons
  sprites.addSprite("weapons", "chess_castle_charge")
  sprites.addSprite("weapons", "chess_knight_stomp")
  sprites.addSprite("weapons", "chess_spawn_pawn")
  sprites.addSprite("weapons", "chess_bishop_charge")
  sprites.addSprite("effects", "chess_shotup_pawn")
  sprites.addSprite("effects", "chess_shotup_pawn_alt")
  sprites.addAnimation("effects", "chess_speardiag_U", {Base = "explospear1_0", PosX = -40, PosY = -24})
  sprites.addAnimation("effects", "chess_speardiag_R", {Base = "explospear1_0", PosX = -46, PosY = -12})
  sprites.addAnimation("effects", "chess_speardiag_D", {Base = "explospear1_0", PosX = -41, PosY = -12})
  sprites.addAnimation("effects", "chess_speardiag_L", {Base = "explospear1_0", PosX = -42, PosY = -12})
  -- trait icons
  sprites.addSprite("combat/icons", "icon_king_move")
  sprites.addSprite("combat/icons", "icon_knight_move")
  sprites.addSprite("combat/icons", "icon_rook_move")
  sprites.addSprite("combat/icons", "icon_bishop_move")
  sprites.addSprite("combat/icons", "icon_pawn_move")
  sprites.addSprite("combat/icons", "icon_pawn_move_explode")
  sprites.addSprite("combat/icons", "icon_empty_glow")
  -- achievements
  local difficulties = {"easy", "normal", "hard"}
  sprites.addAchievement("chess_2_clear", difficulties)
  sprites.addAchievement("chess_3_clear", difficulties)
  sprites.addAchievement("chess_4_clear", difficulties)
  sprites.addAchievement("chess_perfect")
  sprites.addAchievement("chess_woodpusher")
  sprites.addAchievement("chess_pawn_grenade")
  sprites.addAchievement("chess_one_shot")
  sprites.addSprite("achievements", "chess_secret")

  -- texts
  local texts = require(self.scriptPath.."weapon_texts")
  modApi:addWeapon_Texts(texts)
  self:loadScript("tile_texts")

  -- core content
  self:loadScript("skills/king")
  self:loadScript("skills/knight")
  self:loadScript("skills/rook")
  self:loadScript("skills/bishop")
  self:loadScript("skills/pawn")
  self:loadScript("pawns")
  self:loadScript("achievements")
  self:loadScript("achievementTriggers"):init()

  -- diagonal pawn animations
  local diagonal = self:loadScript("libs/diagonalMove")
  diagonal.setupAnimations("Chess_King", "units/player/chess_king_diagonal")
  diagonal.setupAnimations("Chess_Rook", "units/player/chess_rook_diagonal")
  diagonal.setupAnimations("Chess_Bishop", "units/player/chess_bishop_diagonal")

  -- shop
  modApi:addWeaponDrop("Chess_Knight_Smite")
  modApi:addWeaponDrop("Chess_Castle_Charge")
  modApi:addWeaponDrop("Chess_Spawn_Pawn")
  modApi:addWeaponDrop("Chess_Bishop_Charge")

  -- weapon texts
  for _, weapon in ipairs({
    "Chess_Knight_Smite", "Chess_Castle_Charge", "Chess_Spawn_Pawn",
    "Chess_Bishop_Charge", "Chess_Pawn_Spear"
  }) do
    fixWeaponTexts(weapon)
  end
end

function mod:load(options,version)
  -- load libraries
  self.modApiExt:load(self, options, version)
  self:loadScript("libs/trait"):load()
  self:loadScript("weaponPreview/api"):load()

  -- add mech squad
  modApi:addSquad(
    { "Chess Pawns", "Chess_Knight", "Chess_Rook", "Chess_King", id = "knight_ChessPawns" },
    "Chess Pawns",
    "These mech employ unusual weapons and unique movement patterns.",
    self.resourcePath.."img/icon.png"
  )

  -- copy config over
  self.config.rookRockThrow = not options.rookRockThrow or options.rookRockThrow.enabled
  self.config.knightCapMax = options.knightCapMax and options.knightCapMax.enabled
  local image = self.config.rookRockThrow and "Mountain" or "Normal"
  for _, weapon in pairs({"Chess_Castle_Charge", "Chess_Castle_Charge_A", "Chess_Bishop_Charge"}) do
    local weaponObj = _G[weapon]
    if weaponObj and weaponObj.TipImages then
      weaponObj.TipImage = weaponObj.TipImages[image]
    end
  end

  local oldRookMovement = options.oldRookMovement and options.oldRookMovement.enabled
  Chess_Rook.MoveSkill = oldRookMovement and "Chess_Rook_Move_Corner" or "Chess_Rook_Move"

	-- reset tutorial tooltips if checked
	if options.resetTutorialTips and options.resetTutorialTips.enabled then
		self:loadScript("libs/tutorialTips"):ResetAll()
		options.resetTutorialTips.enabled = false
	end
end

return mod
