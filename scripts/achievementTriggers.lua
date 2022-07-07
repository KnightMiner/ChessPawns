local mod = mod_loader.mods[modApi.currentMod]
local helpers = mod:loadScript("libs/helpers")

local this = {}
local squadname = "Chess Pawns"
local difficulties = {[0] = "easy", [1] = "normal", [2] = "hard"}
local bonusAchievements = {"woodpusher", "pawn_grenade", "one_shot"}
local unlock = {
  unlockTitle = 'Mech Unlocked!',
  name = 'Bishop Mech',
  tip = 'Bishop Mech unlocked. This mech can now be selected in custom squads.',
  img = 'img/achievements/chess_secret.png',
}

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
  return not helpers.isTooltip() and not IsTestMechScenario() and checkSquad() and not modApi.achievements:isComplete(mod.id, id)
end

--[[--
  Mark the given difficulty for victory

  @param islands  Number of islands cleared
  @param diff     Difficulty name
]]
local function achieveDifficulty(islands, diff)
  -- TODO
  --[[
  local name = islands .. "_clear"
  if not modApi.achievements:isProgress(mod.id, name, {[diff] = true}) then
    modApi.toasts:add({
      name = string.format("%s %d Island %s Victory", squadname, islands, (diff:gsub("^%l", string.upper))),
      tip = string.format('Complete %d corporate islands in %s then win the game.', islands, diff),
      img = string.format('img/achievements/chess_%d_clear_%s.png', islands, diff),
    })
    modApi.achievements:trigger(mod.id, name, {[diff] = true})
  end
  ]]
end

--[[--
  Initializes the achievement triggers
]]
function this:init()
  --[[
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
      if difficulty >= 0 and difficulty <= 2 then
        achieveDifficulty(islands, difficulties[difficulty])
      end

      -- highscore achievement
      local highscore = GameData.current.score
      if highscore == 30000 then
        --TODO modApi.achievements:trigger(mod.id, prefix .. "perfect")
      end
    end
  end
  ]]
end

--[[--
  Checks if we completed all the achievements needed for the secret unlock

  @return true if the secret is unlocked
]]
function this:hasSecret()
  for _, id in ipairs(bonusAchievements) do
    if not modApi.achievements:isComplete(mod.id, id) then
      return false
    end
  end

  return true
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
  if modApi.achievements:isComplete(mod.id, id) then return end

  -- trigger it
  modApi.achievements:trigger(mod.id, id)

  -- show bonus message when relevant
  if this:hasSecret() then
    modApi.toasts:add(unlock)
  end
end

--[[--
  Increments the push counter for the mission. Global function to run as a script
]]
function incrementChessAchievementWoodpusher()
  -- skip if no mission
  local mission = GetCurrentMission()
  if not mission then return end

  -- increment the count, then grant the achievement if relevant
  local count = mission.chess_woodpusher or 0
  mission.chess_woodpusher = count + 1
  if mission.chess_woodpusher >= 3 then
    this:trigger("woodpusher")
  end
end

--[[--
  Checks if damage on the given point would reposition the pawn

  @param point  Point to check
  @param dir    Direction of damage to check, can be nil to not check direction
]]
function this:checkPush(ret, point, dir)
  -- skip if we already got the achievement
  if not this:available("woodpusher") then return end

  -- pawn must be a mech
  if Board:IsPawnTeam(point, TEAM_MECH) then
    -- pawn must be active, and if set the direction must be open
    local pawn = Board:GetPawn(point)
    if pawn:IsActive() and (not dir or not Board:IsBlocked(point + DIR_VECTORS[dir], pawn:GetPathProf())) then
      ret:AddScript("incrementChessAchievementWoodpusher()")
    end
  end
end

return this
