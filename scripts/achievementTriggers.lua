local mod = mod_loader.mods[modApi.currentMod]
local achvApi = mod:loadScript("achievements/api")

local this = {}
local squadname = "Chess Pawns"
local difficulties = {[0] = "easy", [1] = "normal", [2] = "hard"}

--[[
  Initializes the achievement triggers
]]
function this:init()
	local oldMissionEnd = Mission_Final_Cave.MissionEnd

	function Mission_Final_Cave:MissionEnd()
		oldMissionEnd(self)
		--Win the Game Achievements
		if GAME.squadTitles["TipTitle_"..GameData.ach_info.squad] == squadname then
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

function this:trigger(id)
	-- must be using our squad for achievements
	LOG(GAME.squadTitles["TipTitle_"..GameData.ach_info.squad])
	if GAME.squadTitles["TipTitle_"..GameData.ach_info.squad] ~= squadname then
		return
	end

	-- ensure its not already unlocked
	if achvApi:GetChievoStatus(id) then	return end

	-- trigger it
	achvApi:TriggerChievo(id)
end

return this
