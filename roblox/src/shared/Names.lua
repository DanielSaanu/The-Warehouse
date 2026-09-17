--!strict
-- Random names for people and places. Deterministic given an Rng. Children keep the father's last name
-- (handled by whoever creates the child: pass the surname through).
local Rng = require(script.Parent.Rng)

local Names = {}

local FIRST_A = { "Ab", "Ash", "Bel", "Bran", "Cal", "Dar", "Ed", "Fen", "Gar", "Hal", "Id", "Jor", "Kel", "Lan", "Mar", "Nel", "Or", "Pel", "Ren", "Sal", "Tam", "Ul", "Ver", "Wil", "Yor", "Zan", "Ael", "Bri", "Cor", "Dun", "El", "Fal", "Gwen", "Hen", "Isa", "Lor", "Mor", "Nia", "Od", "Ros", "Tal", "Una", "Wen" }
local FIRST_B = { "a", "an", "ar", "ec", "el", "en", "et", "ia", "ic", "id", "in", "is", "la", "lin", "lo", "na", "o", "on", "ric", "ta", "us", "wen", "wyn", "y" }
local LAST_A = { "Ash", "Black", "Bright", "Cold", "Deep", "Elm", "Fair", "Fern", "Grey", "Hart", "High", "Long", "Marsh", "Moss", "Oak", "Red", "Rock", "Stone", "Thorn", "Wolf", "Wood", "Green", "Salt", "Storm", "Wild" }
local LAST_B = { "ford", "wood", "hill", "field", "brook", "well", "worth", "ridge", "mere", "ley", "ton", "by", "dale", "moor", "crag", "bank", "combe", "stead", "hurst", "haven" }
local PLACE_A = { "Ash", "Bram", "Cold", "Dun", "Elder", "Fal", "Glen", "Hollow", "Ken", "Low", "Mal", "Nor", "Oak", "Pen", "Ram", "Sel", "Thorn", "Ulf", "Wen", "Wyn", "Yar" }
local PLACE_B = { "ford", "wick", "ham", "bury", "mouth", "gate", "den", "holt", "caster", "thorpe", "worth", "fell", "mere", "burn", "stow" }
local CAMP_B = { " Hollow", " Camp", "'s Rest", " Crag", " Den", " Cut" }

function Names.first(rng: Rng.Rng): string
	return rng:pick(FIRST_A) .. rng:pick(FIRST_B)
end

function Names.last(rng: Rng.Rng): string
	return rng:pick(LAST_A) .. rng:pick(LAST_B)
end

--- Full name. Pass a surname to keep a family together.
function Names.person(rng: Rng.Rng, surname: string?): (string, string)
	return Names.first(rng), surname or Names.last(rng)
end

--- Village name. Plunderer places sound rougher.
function Names.place(rng: Rng.Rng, tribeType: string?): string
	if tribeType == "plunderer" then
		return rng:pick(LAST_A) .. rng:pick(CAMP_B)
	end
	return rng:pick(PLACE_A) .. rng:pick(PLACE_B)
end

--- Tribe name from its home village ("the Ashford tribe", "the Wolf Crag band").
function Names.tribe(placeName: string, tribeType: string): string
	if tribeType == "plunderer" then return "the " .. placeName .. " band" end
	if tribeType == "hunter" then return "the " .. placeName .. " hunters" end
	return "the " .. placeName .. " tribe"
end

return Names
