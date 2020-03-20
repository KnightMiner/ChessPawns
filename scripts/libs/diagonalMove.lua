local mod = mod_loader.mods[modApi.currentMod]
local cutils = mod:loadScript("libs/CUtils")
local diagonal = {}

--[[--
  Adds a sprite to the game

  @param path Sprite path
]]
local function addSprite(path)
  modApi:appendAsset(
    string.format("img/%s.png", path),
    string.format("%simg/%s.png", mod.resourcePath, path)
  )
end

--- Just a no-op function in case the mech has a death effect
local function deathEffect(self, p1)
end

--[[--
  Sets up animations for the given pawn type. Safe to call multiple times for a pawn, but needs to be called after pawns are loaded

  @param type   Pawn type
  @param image  Image path to prevents fadeout over problematic tiles. If provided, should be the same as the pawn's stationary image, except with a second blank frame.
]]
function diagonal.setupAnimations(type, image)
  -- first, check if we already initialized this pawn type, if so we can skip
  local animName = "Diagonal_" .. type
  if _G[animName] then return end

  -- create animations
  local class = _G[type]
  ANIMS[animName] = ANIMS[class.Image]:new({Time = 0.1, NumFrames = 1, Loop = true})

  -- if given an image, use that image for the animation
  -- image is expected as a 2 frame animation
  if image then
    addSprite(image)
    ANIMS[animName.."d"] = ANIMS[animName]:new({time = 0.2, NumFrames = 2, Loop = false, Image = image .. ".png"})
  else
    ANIMS[animName.."d"] = ANIMS[animName]:new({Loop = false})
  end

  -- setup fake pawn to spawn the animation, used so we can get pallet colors working properly
  -- it has 0 health, so it will immediately die without affecting the board
  _G[animName] = class:new({Health = 0, Image = animName, DefaultTeam = TEAM_NONE})
  _G[animName].GetDeathEffect = deathEffect
end

--[[--
  Logic to create an animation pawn at the given point.
  Global as its called in a SkillEffect script

  @param point  Point to place the pawn animation
]]
function createDiagonalPawnAnimation(point)
  -- move the pawn out of the way
  Pawn:SetSpace(Point(-1,-1))

  -- if the animation does not exist, give up, no animations for you
  local name = Pawn:GetType()
  local type = "Diagonal_" .. name
  if not _G[type] then
    LOGF("Missing animations for %s", name)
    return
  end

  -- create the pawn, copying the ACID state if present
  -- would copy fire as well, but it does not show up
  local pawn = PAWN_FACTORY:CreatePawn(type)
  if Pawn:IsAcid() then
    pawn:SetAcid(true)
  end

  -- add the pawn to the board, it will immediately die
  Board:AddPawn(pawn, point)
end

--- Temporary workaround until the cutils fix is merged to make Pawn:SetFire(true) not affect the board
function setDiagonalPawnFire()
  if not Pawn:IsFire() then
    cutils.SetPawnFire(Pawn, true)
  end
end

--[[--
  Script function to remove a item from the board and move the pawn to that place.
  Assumes the item is stored to restore it later

  @param point  Point containing an item
]]
function removeDiagonalItem(point)
  cutils.TileRemoveItem(Board, point)
  Pawn:SetSpace(point)
end

--[[--
  Sets the color on the pawn based on the current pallet colors
]]
function diagonal.setColor()
  local color = cutils.GetPawnColor(Pawn)
  -- regular pawn
  local type = Pawn:GetType()
  local colorType = "Diagonal_" .. type
  if _G[colorType] then _G[colorType].ImageOffset = color end
  -- submerged pawn
  colorType = "DiagonalW_" .. type
  if _G[colorType] then _G[colorType].ImageOffset = color end
end

--[[--
  Move a single space using the diagonal movement logic. Can be used outside of diagonal.move to draw other paths
  Should always finish loops with Pawn:SetSpace, as this function may move the pawn off board

  @param ret    SkillEffect instance
  @param point  Target point for this step
]]
function diagonal.addStep(ret, point)
  -- items cause problems for any pawn on the space, so temporarily remove them and add back later
  local item = nil
  if Board:IsItem(point) then
    item = cutils.TileGetItemName(Board, point)
    ret:AddScript(string.format("removeDiagonalItem(%s)", point:GetString()))

  -- on tiles where we might interact with the board, add a fake pawn for animation
  elseif Board:IsPod(point) or Board:IsAcid(point) or Board:IsFire(point) or (Pawn:IsFire() and Board:GetTerrain(point) == TERRAIN_FOREST) then
    ret:AddScript(string.format("createDiagonalPawnAnimation(%s)", point:GetString()))
  else
    -- anywhere else directly to the space
    ret:AddScript(string.format("Pawn:SetSpace(%s)", point:GetString()))
  end

  -- add delay so the pawn animates
  ret:AddDelay(0.1)

  -- restore the item, this does not trigger as there is no delay in the next call
  if item then
    ret:AddScript(string.format("Board:SetItem(%s,'%s')", (point):GetString(), item))
  end
end

--[[--
  Minimizes a number to only have at most 1 in any direction

  @param i  number to minimize
  @return Minimized number
]]
local function minimizeNumber(i)
  if i == 0 then
    return i
  else
    return i / math.abs(i)
  end
end

--[[--
  Minimizes a point to only have at most 1 in any direction

  @param point  Point to minimize
  @return Minimized point
]]
function diagonal.minimize(point)
  return Point(minimizeNumber(point.x), minimizeNumber(point.y))
end

--[[--
  Logic to animation a full diagonal movement path

  @param ret  SkillEffect instance
  @param p1   Starting point
  @param p2   Ending point, must be a straight line away either diagonally or straight
]]
function diagonal.addMove(ret, p1, p2)
  -- if the same, no movement required
  if p1 == p2 then return end

  -- determine where we need to travel
  local offset = p2 - p1
  local orthogonal = false
  local distance = math.abs(offset.x)
  assert(distance == math.abs(offset.y), "Spaces must be in a straight diagonal line")

  -- add sound effect
  local pawnType = Pawn:GetType()
  ret:AddSound(_G[pawnType].SoundLocation .. "move")
  ret:AddDelay(0.1)

  -- distance of 1 has less work to do
  local wasFire = false
  if distance > 1 then
    -- normalize the offset to be distance of 1
    offset = diagonal.minimize(offset)

    -- prepare the animation
    diagonal.setColor()

    -- store fire as traveling through water may accidently unset it
    wasFire = Pawn:IsFire()

    -- iterate through points in the path, steping to each point
    local point = p1 + offset
    while point ~= p2 do
      diagonal.addStep(ret, point)
      point = point + offset
    end
  end

  -- move the actual pawn
  ret:AddScript(string.format("Pawn:SetSpace(%s)", p2:GetString()))

  -- restore fire if needed
  if wasFire then
    ret:AddScript("setDiagonalPawnFire()")
  end

  -- add a normal move so it shows up in the tooltip
  ret:AddTeleport(p1, p2, NO_DELAY)
end

--[[--
  Gets the target for a shot in a diagonal direction

  @param p1       Position of the pawn
  @param p2       Selected position
  @param profile  Pathing method to use
  @return Point of the target for this projectile
]]
function diagonal.getProjectileEnd(p1, p2, profile)
  profile = profile or PATH_PROJECTILE
	local direction = diagonal.minimize(p2 - p1)
	local target = p2

	while not Board:IsBlocked(target, profile) do
		target = target + direction
	end

	return target
end

return diagonal
