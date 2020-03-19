local mod = mod_loader.mods[modApi.currentMod]
local achvApi = mod:loadScript("achievements/api")

-- special
achvApi:AddChievo{
  id = "woodpusher",
  name = "Woodpusher",
  tip = "Use pawn, rook, and knight weapons to push other mechs 3 times in one mission.",
  img = "img/achievements/chess_woodpusher.png",
}

achvApi:AddChievo{
  id = "pawn_grenade",
  name = "Pawn Grenade",
  tip = "Kill at least two enemies by tossing an exploding pawn at them with the castle charge.",
  img = "img/achievements/chess_pawn_grenade.png",
}

achvApi:AddChievo{
  id = "one_shot",
  name = "One Shot",
  tip = "Kill a boss in a single hit using knight smite.",
  img = "img/achievements/chess_one_shot.png",
}

local difficulties = {"hard", "normal", "easy"}

--[[--
  Selects an image based on the achievement status for victory images

  @param chievo  Achievement instance
  @return  Achievement image path
]]
local function getVictoryImg(chievo)
  -- if achieved, use full image with all medals
  if achvApi:IsChievoCompleted(chievo.id) then
    return chievo.img
  end

  -- return highest earned metal
  local baseImg = chievo.img:sub(1,-5)
  local progress = achvApi:GetChievoProgress(chievo.id)
  for _, diff in ipairs(difficulties) do
    if progress[diff] then
      return baseImg .. "_" .. diff .. ".png"
    end
  end

  -- no progress image
  return chievo.img_gray
end

-- general
achvApi:AddChievo{
  id = "2_clear",
  name = "Chess Pawns 2 Island Victory",
  tip = "Complete 2 corporate islands then win the game.\n\nEasy: $easy\nNormal: $normal\nHard: $hard",
  img = "img/achievements/chess_2_clear.png",
  objective = {
    easy = true,
    normal = true,
    hard = true,
  },
  GetImg = getVictoryImg
}

achvApi:AddChievo{
  id = "3_clear",
  name = "Chess Pawns 3 Island Victory",
  tip = "Complete 3 corporate islands then win the game.\n\nEasy: $easy\nNormal: $normal\nHard: $hard",
  img = "img/achievements/chess_3_clear.png",
  objective = {
    easy = true,
    normal = true,
    hard = true,
  },
  GetImg = getVictoryImg
}

achvApi:AddChievo{
  id = "4_clear",
  name = "Chess Pawns 4 Island Victory",
  tip = "Complete 4 corporate islands then win the game.\n\nEasy: $easy\nNormal: $normal\nHard: $hard",
  img = "img/achievements/chess_4_clear.png",
  objective = {
    easy = true,
    normal = true,
    hard = true,
  },
  GetImg = getVictoryImg
}

achvApi:AddChievo{
  id = "perfect_game",
  name = "Chess Pawns Perfect Game",
  tip = "Win the game and obtain the highest possible score.",
  img = "img/achievements/chess_perfect.png"
}
