-- One of the benefits of the mod system is that it'll never be ran on the server, so most conditional realm blocks are unnecessary.
print("Rainbow Watergun mod loaded")

-- here is where your mod's code is going to be

hook.Add("GellyModsShutdown", "gelly.mod.mod-name", function()
	-- remove any left over liquid
	gelly.Reset()

	print("Mod unloaded")
end)
