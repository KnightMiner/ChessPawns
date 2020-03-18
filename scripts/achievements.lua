local mod = mod_loader.mods[modApi.currentMod]
local achvApi = mod:loadScript("achievements/api")

achvApi:AddChievo{
  id = "2_clear",
  name = "Chess Pawns 2 Island Victory",
  tip = "Complete 2 corporate islands then win the game.\n\nEasy: $easy\nNormal: $normal\nHard: $hard",
  img = "img/achievements/chess_2_clear.png",
  objective = {
    easy = true,
    normal = true,
    hard = true,
  }
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
  }
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
  }
}

achvApi:AddChievo{
  id = "perfect_game",
  name = "Chess Pawns Perfect Game",
  tip = "Win the game and obtain the highest possible score.",
  img = "img/achievements/chess_perfect.png"
}
