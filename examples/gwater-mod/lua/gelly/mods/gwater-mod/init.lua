print("Gwater mod loaded")

hook.Add("GellyModsShutdown", "gelly.mod.gwater-mod", function()
	-- remove any left over liquid
	gelly.Reset()

	print("Gwater mod unloaded")
end)