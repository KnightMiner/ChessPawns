local sprites = {}
local mod = mod_loader.mods[modApi.currentMod]

--[[--
  Adds a sprite to the game

  @param filename  File to add
  @param path      Base sprite path
]]
function sprites.addSprite(filename, path)
  modApi:appendAsset(
    string.format("img/%s/%s.png", path, filename),
    string.format("%simg/%s/%s.png", mod.resourcePath, path, filename)
  )
end

--[[
  Converts a name into a path to a mech sprite

  @param name  Mech sprite name
  @return  Sprite path
]]
local function mechPath(name)
  return string.format("units/player/%s.png", name)
end

--[[
  Adds the specific animation for a mech

  @param name        Mech name
  @param key         Key in object containing animation data
  @param suffix      Suffix for this animation type
  @param fileSuffix  Suffix used in the filepath. If unset, defaults to suffix
]]
local function addMechAnim(name, object, suffix, fileSuffix)
  if object then
  -- default fileSuffix to the animation suffix
  fileSuffix = fileSuffix or suffix

  -- add the sprite to the resource list
  local filename = name .. fileSuffix
  sprites.addSprite(filename, "units/player")

  -- add the mech animation to the animation list
  object.Image = mechPath(filename)
  ANIMS[name..suffix] = ANIMS.MechUnit:new(object);
  end
end

--[[--
  Adds a list of resources to the game

  @param sprites  varargs parameter of all mechs to add
]]
function sprites.addMechs(...)
  for _, object in pairs({...}) do
    local name = object.Name

    -- these types are pretty uniform
    addMechAnim(name, object.Default,         ""                     )
    addMechAnim(name, object.Animated,        "a",        "_a"       )
    addMechAnim(name, object.Broken,          "_broken"              )
    addMechAnim(name, object.Death,           "d",        "_death"   )
    addMechAnim(name, object.Submerged,       "w",        "_w"       )
    addMechAnim(name, object.SubmergedBroken, "w_broken", "_w_broken")

    -- icon actually uses 2 images, and uses a different object type
    if object.Icon then
      -- firstly, we have the extra hanger sprite
      sprites.addSprite(name .. "_h", "units/player")

      -- add the regular no shadow sprite
      local iconname = name .. "_ns"
      sprites.addSprite(iconname, "units/player")

      -- second, we use MechIcon instead of MechUnit
      object.Icon.Image = mechPath(iconname)
      ANIMS[iconname] = ANIMS.MechIcon:new(object.Icon);
    end
  end
end

return sprites
