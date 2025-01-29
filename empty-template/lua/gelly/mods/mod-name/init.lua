-- One of the benefits of the mod system is that it'll never be ran on the server, so most conditional realm blocks are unnecessary.
print("Mod loaded")

-- here is where your mod's code is going

hook.Add("GellyModsShutdown", "gelly.mod.mod-name", function()
	-- remove any created hooks
	
	-- remove any left over liquid
	gelly.Reset()

	print("Mod unloaded")
end)
