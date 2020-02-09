local mod = {
	id = "Knight_Chess",
	name = "Chess Pawns",
	version = "0.0.1",
	requirements = {},
}

function mod:init()
	local sprites = require(self.scriptPath .. "libs/sprites")
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
      Default =           { PosX = -20, PosY = -12 },
      Animated =          { PosX = -20, PosY = -12, NumFrames = 5 },
      Submerged =         { PosX = -20, PosY =  -6 },
      Broken =            { PosX = -20, PosY = -12 },
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
      Name = "chess_pawn",
      Default =           { PosX = -12, PosY = 0 },
      Animated =          { PosX = -12, PosY = 0, NumFrames = 4 },
      Death =             { PosX = -12, PosY = 0, NumFrames = 5, Time = 0.09, Loop = false },
      Icon =              {},
    }
	)
	sprites.addSprite("chess_castle_charge",      "weapons")
	sprites.addSprite("chess_knight_stomp",       "weapons")
	sprites.addSprite("chess_spawn_pawn",         "weapons")
	sprites.addSprite("chess_shotup_pawn_yellow", "effects")
	sprites.addSprite("chess_shotup_pawn_black",  "effects")

	modApi:addWeapon_Texts(require(self.scriptPath.."weapon_texts"))
	require(self.scriptPath.."skills/king")
	require(self.scriptPath.."skills/knight")
	require(self.scriptPath.."skills/rook")
	require(self.scriptPath.."skills/pawn")
	require(self.scriptPath.."pawns")
end

function mod:load(options,version)
	modApi:addSquad({"Chess Pawns","Chess_Knight","Chess_Rook","Chess_King"},"Chess Pawns","Chess piece themed mechs.",self.resourcePath.."/icon.png")
end

return mod
