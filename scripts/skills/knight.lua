local path = mod_loader.mods[modApi.currentMod].scriptPath
local helpers = require(path .. "libs/helpers")
local cutils = require(path .. "libs/CUtils")
local previewer = require(path .. "weaponPreview/api")

--[[--
  Used to safely get the armor status of a pawn.
	Works around a bug in ModLoader 2.4.0 where the mech tester returns invalid region data for armor.

  @param pawn       Pawn of interest
  @return  True if the pawn is armored
]]
local function isArmorSafe(pawn)
	if IsTestMechScenario() then
		return _G[pawn:GetType()]:GetArmor()
	end

	return pawn:IsArmor()
end

--[[--
  Determines if a point is valid for knight movement or attack

  @param point       Point targeting
  @param isAttack    If true, we are attacking so pawns and holes can be targeted
  @param isUpgraded  If true, we have less self damage and can do a little more damage
  @return  True if the point is valid
]]
local function pointValid(point, isAttack, isUpgraded)
	-- invalid points immediately fail
	if not Board:IsValid(point) then
		return false
	end
	-- if not blocked, attack allows anything, but stop holes for normal, non flying movement
	if not Board:IsBlocked(point, PATH_FLYER) then
		return isAttack or Pawn:IsFlying() or Board:GetTerrain(point) ~= TERRAIN_HOLE
	end

	-- if blocked, movement will fail. attacks may work though
	if not isAttack then
		return false
	end

	-- if not a pawn, means blocked by a building or mountain
	local pawnAtPoint = Board:GetPawn(point)
	if pawnAtPoint == nil then
		return false
	end

	-- skip remaining logic in tooltips to save some effort
	-- plus, some code later crashes in modloader 2.4.0, so prevents a crash
	if helpers.isTooltip() then
		return true
	end

	-- no attacking shielded enemies, that takes 2 hits
	-- no attacking pawns with a corpse (false for mechs oddly, so check that too)
	if pawnAtPoint:IsShield() or pawnAtPoint:IsMech() or _G[pawnAtPoint:GetType()]:GetCorpse() then
		return false
	end

	-- max damage is the pawns max heallth, taking armor and the lower self damage upgrades into account
	local maxDamage = cutils.GetMaxHealth(Pawn) + (isArmorSafe(Pawn) and 1 or 0) + (isUpgraded and 1 or 0)
	-- target is lowered by acid and raised by armor
	local targetHealth = pawnAtPoint:GetHealth()
	if pawnAtPoint:IsAcid() then
		targetHealth = math.ceil(targetHealth / 2)
	elseif isArmorSafe(pawnAtPoint) then
		targetHealth = targetHealth + 1
	end

	return maxDamage >= targetHealth
end

--[[--
  Knight Move: 2 spaces in one direction, then 1 space on the other axis
]]
Chess_Knight_Move = Move:new {
	IsAttack = false
}

--[[--
	Moves:
	 1: normal (for pilot ability)
	 2: Knight
	 3: Knight + threeleaper
	 4: Knight x2 + threeleaper
	 5: Knight x2 + threeleaper x2
	 6: Knight x3 + threeleaper x2
]]
function Chess_Knight_Move:GetTargetArea(p1)
	local ret = PointList()
	local move = self.IsAttack and 2 or Pawn:GetMoveSpeed()

	-- all four directions
	for dir = DIR_START, DIR_END do
		-- both opposite axises
		for d = 1, 3, 2 do
			-- direction of this movement
			local offset = DIR_VECTORS[dir] * 2 + DIR_VECTORS[(dir + d) % 4]
			local point = p1 + offset
			if pointValid(point, self.IsAttack, self.LessSelfDamage) then
				ret:push_back(point)

				-- second knight leap
				-- note IsAttack is never true after here
				if move >= 4 then
					point = point + offset
					if pointValid(point, false, false) then
						ret:push_back(point)

						--  third leap
						if move >= 6 then
							point = point + offset
							if pointValid(point, false, false) then
								ret:push_back(point)
							end
						end
					end
				end
			end
		end

		-- 3+ gives threeleaper
		-- 5+ gives double threeleaper
		if move >= 3 then
			-- direction of movement
			local offset = DIR_VECTORS[dir] * 3
			local point = p1 + offset
			if pointValid(point, false, false) then
				ret:push_back(point)

				-- double threeleaper
				if move >= 5 then
					point = point + offset
					if pointValid(point, false, false) then
						ret:push_back(point)
					end
				end
			end
		end
	end

	return ret
end

--[[--
  Divides a point elementwise by the given number, flooring any remainder

	@param point  Point to divide
	@param amount  Divisor
	@return  Divided point
]]
local function dividePoint(point, divisor)
	return Point(math.floor(point.x / divisor), math.floor(point.y / divisor))
end

--- Knight makes leaping movements. Will make multiple leaps if over 3 tiles
function Chess_Knight_Move:GetSkillEffect(p1, p2)
	local ret = SkillEffect()

	-- if the movement is too far, add a middle move
	local middle = p1
	local dist = p1:Manhattan(p2)
	-- if greater than 3, takes at least 2 moves
	if dist > 3 then
		local start = p1
		local offset
		-- if greater than 6, 3 moves
		if dist > 6 then
			offset = dividePoint(p2 - p1, 3)
			start = p1 + offset
			helpers.addLeap(ret, p1, start)
		else
			offset = dividePoint(p2 - p1, 2)
		end

		-- move from start to middle
		middle = start + offset
		helpers.addLeap(ret, start, middle)
	end

	-- add final move
	helpers.addLeap(ret, middle, p2)

	return ret
end

--[[--
  Knight Smite: knight move onto target for instant kill

  Upgrades: Push and Less Self Damage
]]
Chess_Knight_Smite = Chess_Knight_Move:new {
	-- base stats
	Class = "Prime",
	Damage = DAMAGE_DEATH,
	PowerCost = 2,
	Upgrades = 2,
	UpgradeCost = {1, 2},
	-- settings
	IsAttack = true,
  Push = false,
	LessSelfDamage = false,
	-- effects
	Icon = "weapons/chess_knight_stomp.png",
	LaunchSound = "/weapons/modified_cannons",
	ImpactSound = "/impact/generic/explosion",
  -- visual
	TipImage = {
		Unit        = Point(2,3),
		Enemy       = Point(1,1),
		Target      = Point(1,1),
		CustomEnemy = "Firefly1"
	}
}

-- Push upgrade
Chess_Knight_Smite_A = Chess_Knight_Smite:new {
  Push = true,
  TipImage = {
		Unit = Point(2,3),
		Enemy = Point(1,1),
		Enemy2 = Point(2,1),
		Target = Point(1,1),
		CustomEnemy = "Firefly1"
	}
}

-- Damage upgrade
Chess_Knight_Smite_B = Chess_Knight_Smite:new {
	LessSelfDamage = true
}

-- Both upgrades
Chess_Knight_Smite_AB = Chess_Knight_Smite_A:new {
  Push = true,
	LessSelfDamage = true
}

--[[--
  Kills the enemy at the given point, dealing self damage to the attacker

  @param  target  Point target for damage
  @param  selfDamage  amount of damage to deal the attacking mech
]]
function Chess_Knight_Smite:Squash(target, selfDamage)
	-- move the mech out of the way so it does not die
	Pawn:SetSpace(Point(-1,-1))
	Board:DamageSpace(SpaceDamage(target, DAMAGE_DEATH))

	-- move the mech back, then self damage
	Pawn:SetSpace(target)
	-- doing these in one damage was giving me bugs, so one for animation and one for damage
	if selfDamage > 0 then
		Board:DamageSpace(SpaceDamage(target, selfDamage))
		Board:DamageSpace(helpers.animationDamage(target, "ExploAir1"))
	end
end

--- Moves the knight and instantly kills the target
function Chess_Knight_Smite:GetSkillEffect(p1, p2)
	local ret = SkillEffect()

	-- attack target if available
	local target = Board:GetPawn(p2)
	if target ~= nil and target:GetSpace() ~= Pawn:GetSpace() then
		-- deal damage based on targets health
		local selfDamage = target:GetHealth()
		-- acid means less self damage, they squash easier
		-- skip in tooltips, as the modloader 2.4.0 has a bug where this crashes
		if not helpers.isTooltip() then
			if target:IsAcid() then
				selfDamage = math.ceil(selfDamage / 2)
			-- armor means more
			elseif isArmorSafe(target) then
				selfDamage = selfDamage + 1
			end
		end
		-- less self drops it again
		if self.LessSelfDamage then
			selfDamage = math.max(selfDamage - 1)
		end

		-- move mech
		helpers.addLeap(ret, p1, p2)

		-- add damage for display at old location
		previewer:AddDamage(SpaceDamage(p1, selfDamage))

		-- run kill script
		ret:AddScript("Chess_Knight_Smite:Squash("..p2:GetString()..","..selfDamage..")")
	else
		-- just normal leap if no enemy
		helpers.addLeap(ret, p1, p2)
	end

	-- bounce a bit on landing
	ret:AddBounce(p2, 3)

	-- push effect on land
	if self.Push then
		for dir = DIR_START, DIR_END do
			local damage = SpaceDamage(p2 + DIR_VECTORS[dir], 0, dir)
			damage.sAnimation = PUSH_ANIMS[dir]
			ret:AddDamage(damage)
		end
	end

	return ret
end
