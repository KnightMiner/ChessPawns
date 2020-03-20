local mod = {
  id = "Knight_Chess",
  name = "Chess Pawns",
  version = "1.1.0",
  requirements = {},
  icon = "img/icon.png",
  modApiVersion = "2.4.1",
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
    "resetTutorialTips",
    "Reset Tutorial Tooltips",
    "Check to reset all tutorial tooltips for this profile",
    { enabled = false }
  )
end

function mod:init()
  -- script init
  self:loadScript("weaponPreview/api")
  self:loadScript("achievements/init")
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
      Default =           { PosX = -12, PosY = 0 },
      Animated =          { PosX = -12, PosY = 0, NumFrames = 4 },
      Death =             { PosX = -12, PosY = 0, NumFrames = 5, Time = 0.09, Loop = false },
      Icon =              {},
    },
    {
      Name = "chess_pawn_alt",
      Default =           { PosX = -12, PosY = 0 },
      Animated =          { PosX = -12, PosY = 0, NumFrames = 4 },
      Death =             { PosX = -12, PosY = 0, NumFrames = 5, Time = 0.09, Loop = false },
      Icon =              {},
    }
  )
  sprites.addSprite("weapons", "chess_castle_charge")
  sprites.addSprite("weapons", "chess_knight_stomp")
  sprites.addSprite("weapons", "chess_spawn_pawn")
  sprites.addSprite("weapons", "chess_bishop_charge")
  sprites.addSprite("effects", "chess_shotup_pawn")
  sprites.addSprite("effects", "chess_shotup_pawn_alt")
  sprites.addSprite("combat/icons", "icon_king_move")
  sprites.addSprite("combat/icons", "icon_knight_move")
  sprites.addSprite("combat/icons", "icon_rook_move")
  sprites.addSprite("combat/icons", "icon_bishop_move")
  sprites.addSprite("combat/icons", "icon_pawn_move")
  sprites.addSprite("combat/icons", "icon_pawn_move_explode")
  sprites.addSprite("combat/icons", "icon_empty_glow")
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
  diagonal.setupAnimations("Chess_Bishop", "units/player/chess_bishop_diagonal")

  -- shop
  self.shop = self:loadScript("libs/shop")
  self.shop:addWeapon({
    id = "Chess_Knight_Smite",
    name = texts.Chess_Knight_Smite_Name,
    desc = "Adds Knight Smite to the store."
  })
  self.shop:addWeapon({
    id = "Chess_Castle_Charge",
    name = texts.Chess_Castle_Charge_Name,
    desc = "Adds Castle Charge to the store."
  })
  self.shop:addWeapon({
    id = "Chess_Spawn_Pawn",
    name = texts.Chess_Spawn_Pawn_Name,
    desc = "Adds Spawn Pawn to the store."
  })
  -- add bishop charge only if the bishop is unlocked
  local achvTrigger = self:loadScript("achievementTriggers")
  if achvTrigger:hasSecret() then
    self.shop:addWeapon({
      id = "Chess_Bishop_Charge",
      name = texts.Chess_Bishop_Charge_Name,
      desc = "Adds Bishop Charge to the store."
    })
  end
end

function mod:load(options,version)
  -- load libraries
  self.modApiExt:load(self, options, version)
  self.shop:load(options)
  self:loadScript("libs/trait"):load()
  self:loadScript("weaponPreview/api"):load()

  -- add mech squad
  modApi:addSquad(
    { "Chess Pawns", "Chess_Knight", "Chess_Rook", "Chess_King" },
    "Chess Pawns",
    "These mech employ unusual weapons and unique movement patterns.",
    self.resourcePath.."img/icon.png"
  )

  -- copy config over
  self.config.rookRockThrow = not options.rookRockThrow or options.rookRockThrow.enabled
  self.config.knightCapMax = options.knightCapMax and options.knightCapMax.enabled
  local image = self.config.rookRockThrow and "Mountain" or "Normal"
  for _, weapon in pairs({"Chess_Castle_Charge", "Chess_Castle_Charge_A", "Chess_Bishop_Charge"}) do
    _G[weapon].TipImage = _G[weapon].TipImages[image]
  end

	-- reset tutorial tooltips if checked
	if options.resetTutorialTips and options.resetTutorialTips.enabled then
		self:loadScript("libs/tutorialTips"):ResetAll()
		options.resetTutorialTips.enabled = false
	end
end

return mod
