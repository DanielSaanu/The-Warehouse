-- H4: development mode. Off outside Studio whatever the flag; in Studio only an explicit false turns it off.
local DevMode = __require("DevMode")

for _, flag in ipairs({ true, false, "yes", 1 }) do
	assert(DevMode.resolve(false, flag) == false, "outside Studio dev mode is off, flag " .. tostring(flag))
end
assert(DevMode.resolve(false, nil) == false, "outside Studio with no attribute: off")
assert(DevMode.resolve(true, true) == true, "Studio + ticked: on")
assert(DevMode.resolve(true, false) == false, "Studio + unticked: off, the ordinary game")
assert(DevMode.resolve(true, nil) == true, "Studio, attribute never set: on (the project is in development)")
assert(DevMode.resolve(true, "false") == true, "a non-boolean is never read as off: the real save is not touched by accident")
local on, why = DevMode.resolve(false, true)
assert(not on and type(why) == "string" and why:find("Studio"), "the reason names why")
print("devmode: ok")
