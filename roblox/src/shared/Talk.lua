--!strict
-- Talking: how the player learns anything (DESIGN.md §8). Villagers give one random line from their village's
-- knowledge bank; role NPCs answer topics. The bank is built by the server from live state and passed in as `ctx`.
-- Pure Luau so every line can be checked outside Studio.
local Rng = require(script.Parent.Rng)

local Talk = {}

export type Context = {
	village: string,        -- village name
	tribeType: string,      -- farmer / hunter / plunderer
	tribeName: string,
	repWord: string,        -- the player's standing here
	warning: string?,       -- tomorrow's calamity, if a warning is due
	calamity: string?,      -- the calamity happening right now
	wildlife: string,       -- Ecology.describe for this region
	banditHint: string,     -- where the bandit band was last seen
	hunterVillage: string,  -- the village the survivor points you to
	hunterDir: string,      -- and which way it lies from here ("east", "north-east", ...)
	farmerVillage: string,
	plundererVillage: string,
	plundererDir: string,   -- the way the raiders came, i.e. the way not to walk on day one
	prices: string,         -- "food 2, hides 5, ..."
	scarce: string,         -- the good this village is short of
	makes: string,          -- the good this village makes
	survivorName: string?,
	playerName: string?,
	familyNews: string?,    -- the village's latest birth or succession, if any
}

Talk.TOPICS = { "road", "tribes", "prices", "me" }
Talk.TOPIC_LABELS = { road = "Ask about the road", tribes = "Ask about the tribes", prices = "Ask about prices", me = "Ask about me" } :: { [string]: string }

local GENERIC = {
	"Long day. Longer night.",
	"If you're heading out, be back before dark. The wolves aren't shy.",
	"The roads are the only fast way anywhere. Off them it's all brambles and boar.",
	"Tall grass hides a person as well as it hides a bandit. Remember that both ways.",
	"Rest before the week is out. Something always comes at the end of the week.",
	"You look like you slept in a ditch. There's a bed in the village if they'll have you.",
}

local BY_TRIBE = {
	farmer = {
		"We grow it, they eat it. That's the whole of it.",
		"The caravan should be back soon. Or it should have been back by now. One of those.",
		"Tools. We're always short of tools. Bring tools and you'll be welcome here.",
		"The hunters are decent folk. The ones up north are not.",
	},
	hunter = {
		"A squad went out this morning. Five of them. Four would still be a good week.",
		"You want hides? We have hides. You want food? So do we.",
		"Bandits jump small groups. Walk with us or walk fast.",
		"The totem watches the road. Don't ask me if it works. It hasn't fallen down yet.",
	},
	plunderer = {
		"Don't touch anything. Don't look at anything. Buy what you're buying and go.",
		"The band is out. If you meet them on the road, that's your bad luck.",
		"Food. We take it because nobody sells it to us. Funny how that works.",
		"The skull post is a joke. Mostly.",
	},
} :: { [string]: { string } }

--- One line from the village's bank. Live facts (the forecast, the game, the bandits) are weighted in.
function Talk.villagerLine(rng: Rng.Rng, ctx: Context): string
	local pool: { string } = {}
	if ctx.calamity then
		table.insert(pool, ctx.calamity)
		table.insert(pool, ctx.calamity)
	end
	if ctx.warning then
		table.insert(pool, ctx.warning)
		table.insert(pool, ctx.warning)
	end
	table.insert(pool, ctx.wildlife)
	table.insert(pool, ctx.banditHint)
	if ctx.familyNews then
		table.insert(pool, ctx.familyNews)
		table.insert(pool, ctx.familyNews)
	end
	table.insert(pool, ("We're short of %s. Bring some and the merchant will pay well."):format(ctx.scarce))
	for _, l in ipairs(GENERIC) do table.insert(pool, l) end
	for _, l in ipairs(BY_TRIBE[ctx.tribeType] or {}) do table.insert(pool, l) end
	return rng:pick(pool)
end

--- What a hostile village says instead of talking. Being refused is itself information.
function Talk.refusal(ctx: Context): string
	if ctx.tribeType == "plunderer" then return "They look at your knife, then at you, and say nothing." end
	return "They turn away. Nobody here will talk to you."
end

--- The first five minutes: the named relative who is the only prompt when you wake (DESIGN.md §12).
function Talk.survivor(ctx: Context): { string }
	return {
		("%s. You're alive. Listen, because I'll only say it once."):format(ctx.playerName or "You"),
		"WASD or the arrows to walk. Left click swings your knife at whatever is in front of you.",
		"F does the rest: talk to people, read a sign, trade at a stall, sleep in a bed. Whatever is nearest.",
		("The bandits came from the %s, from %s. Do not go %s. Not yet, not with that knife."):format(ctx.plundererDir, ctx.plundererVillage, ctx.plundererDir),
		("Go %s down the road to %s instead. The hunters owe us. Tell them %s sent you."):format(ctx.hunterDir, ctx.hunterVillage, ctx.survivorName or "I"),
		"Read the signs on the road. They were put up by people who knew where they were going.",
		"And be back inside walls or by a fire before the end of the week. Something always comes.",
	}
end

--- The one line under the clock: a tutorial, not a quest log (docs/qa/rung2-part4.md). It walks one way and stops,
--- and the first calamity clears it for good. nil means nothing is being asked of the player.
Talk.GOAL_STAGES = { "survivor", "road", "guard", "sell", "shelter" }

function Talk.goal(stage: number, ctx: Context): string?
	if stage == 1 then return "Talk to the person calling you" end
	if stage == 2 then return ("Go %s down the road to %s"):format(ctx.hunterDir, ctx.hunterVillage) end
	if stage == 3 then return ("Talk to the guard at %s"):format(ctx.hunterVillage) end
	if stage == 4 then return "Sell a hide at a stall" end
	if stage == 5 then return "Be inside walls or by a fire before day 7" end
	return nil
end

--- What a sign says, as a one-page dialogue.
function Talk.sign(text: string): { string }
	return { text }
end

--- The village guard's answers: survival basics and what is dangerous nearby.
function Talk.guard(ctx: Context, topic: string): string
	if topic == "road" then
		local line = ctx.banditHint .. " " .. ctx.wildlife
		if ctx.calamity then line = ctx.calamity .. " " .. line
		elseif ctx.warning then line = ctx.warning .. " " .. line end
		return line
	elseif topic == "tribes" then
		return ("The farmers at %s grow the food. The hunters at %s bring in hides. The band at %s takes what it wants. Head that way, don't start trouble."):format(ctx.farmerVillage, ctx.hunterVillage, ctx.plundererVillage)
	elseif topic == "prices" then
		return ("Merchant's board today: %s. We make %s, we're short of %s."):format(ctx.prices, ctx.makes, ctx.scarce)
	elseif topic == "me" then
		local w = ctx.repWord
		if w == "family" then return ("%s calls you one of our own. Whatever you need."):format(ctx.tribeName) end
		if w == "welcome" then return ("You're welcome in %s. Keep it that way and the prices stay kind."):format(ctx.village) end
		if w == "neutral" then return "Nobody here has an opinion of you yet. Trade honest, help a caravan, and they will." end
		if w == "wary" then return "People are watching you. Whatever you did, or whatever they heard, it's not forgotten. A gift or a favour would help." end
		return "If it were up to me you'd be outside the walls already."
	end
	return "..."
end

--- The caravan master: trade and standing, the way DESIGN.md §8 puts it.
function Talk.caravanMaster(ctx: Context): { string }
	return {
		("We run %s to %s and back. Food out, hides home. Nothing fancy."):format(ctx.farmerVillage, ctx.hunterVillage),
		"Get close with the villages round here and they'll cut you a deal. Get on their bad side and they won't trade at all. Or worse.",
		if ctx.calamity then ctx.calamity elseif ctx.warning then ctx.warning .. " We'll be sitting it out." else ctx.banditHint,
	}
end

--- The merchant's one line before the board opens.
function Talk.merchant(ctx: Context): string
	local w = ctx.repWord
	if w == "wary" then return "Coin first. And don't linger." end
	if w == "family" or w == "welcome" then return ("Good to see you. %s is short of %s if you have any."):format(ctx.village, ctx.scarce) end
	return ("Buying and selling. We're short of %s, if you've got it."):format(ctx.scarce)
end

--- Squad and band members, one line each. The band's line is what you hear before they draw.
function Talk.groupLine(kind: string, ctx: Context): string
	if kind == "hunter" then return "Squad's out for deer. Walk with us if you like, but don't spook the game." end
	if kind == "bandit" then return "Wrong road, friend." end
	if kind == "caravan_guard" then return "Talk to the master. I'm just here to look mean." end
	return "..."
end

return Talk
