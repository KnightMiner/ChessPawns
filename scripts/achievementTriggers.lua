local mod = mod_loader.mods[modApi.currentMod]
local achvApi = mod:loadScript("achievements/api")

local this = {}
local squadname = "Chess Pawns"
local difficulties = {[0] = "easy", [1] = "normal", [2] = "hard"}

--[[--
  Helper function to verify the proper squad is selected
]]
local function checkSquad()
  return GAME.squadTitles["TipTitle_"..GameData.ach_info.squad] == squadname
end

--[[--
  Public function to check if the squad is selected an an achievement has not been unlocked
]]
function this:available(id)
  return checkSquad() and not achvApi:GetChievoStatus(id)
end

--[[--
  Initializes the achievement triggers
]]
function this:init()
  local oldMissionEnd = Mission_Final_Cave.MissionEnd

  function Mission_Final_Cave:MissionEnd()
    oldMissionEnd(self)
    --Win the Game Achievements
    if checkSquad() then
      -- count islands achieved
      local islands = 0
      for i = 0, 3 do
        if RegionData["island" .. i].secured then
          islands = islands + 1
        end
      end

      -- min 2 islands for victory
      if islands < 2 then return end

      -- trigger achievement based on win conditions
      local difficulty = GetRealDifficulty()
      for i = 0, difficulty do
        achvApi:TriggerChievo(islands .. "_clear", {
          [difficulties[i]] = true
        })
      end

      -- highscore achievement
      local highscore = GameData.current.score
      if highscore == 30000 then
        achvApi:TriggerChievo(prefix .. "perfect")
      end
    end
  end
end

--[[--
  Triggers the specified achievement

  @param id  Achievement ID to trigger
]]
function this:trigger(id)
  -- must be using our squad for achievements
  if not checkSquad() then
    return
  end

  -- ensure its not already unlocked
  if achvApi:GetChievoStatus(id) then  return end

  -- trigger it
  achvApi:TriggerChievo(id)
end

--[[--
  Increments the reposition counter for the mission. Global function to run as a script
]]
function incrementChessAchievementReposition()
  -- skip if no mission
  local mission = GetCurrentMission()
  if not mission then return end

  -- increment the count, then grant the achievement if relevant
  local count = mission.chess_repositioned or 0
  mission.chess_repositioned = count + 1
  LOG(mission.chess_repositioned)
  if mission.chess_repositioned >= 3 then
    this:trigger("repositioning")
  end
end

--[[--
  Checks if damage on the given point would reposition the pawn

  @param point  Point to check
  @param dir    Direction of damage to check, can be nil to not check direction
]]
function this:checkReposition(ret, point, dir)
  -- skip if we already got the achievement
  if not this:available("repositioning") then return end

  -- pawn must be a mech
  if Board:IsPawnTeam(point, TEAM_MECH) then
    -- pawn must be active, and if set the direction must be open
    local pawn = Board:GetPawn(point)
    if pawn:IsActive() and (not dir or not Board:IsBlocked(point + DIR_VECTORS[dir], pawn:GetPathProf())) then
      ret:AddScript("incrementChessAchievementReposition()")
    end
  end
end

return this
