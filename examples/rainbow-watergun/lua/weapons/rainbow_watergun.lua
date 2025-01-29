SWEP.Category = "Gelly"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Rainbow Gelly Gun"

SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = ""

SWEP.ParticleDensity = 150
SWEP.FireRate = 40      -- bursts per second
SWEP.RapidFireBoost = 6 -- how much proportional quantity of particles to emit when rapid firing

local CROSSHAIR_RADIUS = 10

local INDICATOR_WIDTH_HU = 1
local INDICATOR_HEIGHT_HU = 2
local INDICATOR_HEIGHT_OFFSET = 5

local X_SWAY_PERIOD = 5
local X_SWAY_AMPLITUDE = 0.7
local Y_SWAY_PERIOD = 3
local Y_SWAY_AMPLITUDE = 0.2

local PARTICLE_LIMIT_WARNING_PERCENT = 0.4

function SWEP:Initialize()
	self:SetHoldType("pistol")
end

function SWEP:GetPrimaryBounds()
	local size = gellyx.settings.get("gelly_gun_primary_size"):GetFloat()
	return Vector(size, size, size)
end

function SWEP:GetSecondaryBounds()
	local size = gellyx.settings.get("gelly_gun_secondary_size"):GetFloat()
	return Vector(size, size, size)
end

function min3(a, b, c)
    return math.min(math.min(a, b), c)
end

function hueToRGB(hue)
    local r = (5 + hue * 6) % 6
    local g = (3 + hue * 6) % 6
    local b = (1 + hue * 6) % 6

    r = 1 - math.max(min3(r, 4 - r, 1), 0)
    g = 1 - math.max(min3(g, 4 - g, 1), 0)
    b = 1 - math.max(min3(b, 4 - b, 1), 0)

    return Vector(r, g, b)
end

function SWEP:PrimaryAttack()
	if SERVER then
		self:CallOnClient("PrimaryAttack")
		return
	end
	---@type Player
	local owner = self:GetOwner()
	
	local position = owner:GetShootPos() + owner:GetAimVector() * gellyx.settings.get("gelly_gun_distance"):GetFloat()
	
	local material = gellyx.presets.getActivePreset().Material
	
	material.Absorption = hueToRGB(CurTime()) * math.max(material.Absorption.x, math.max(material.Absorption.y, material.Absorption.z))

	gellyx.emitters.Cube({
		center = position,
		velocity = owner:GetAimVector() * 2,
		bounds = self:GetPrimaryBounds(),
		density = gellyx.settings.get("gelly_gun_density"):GetInt(),
		material = material
	})

	self:SetNextPrimaryFire(CurTime() + 1 / self.FireRate)
end

function SWEP:SecondaryAttack()
	if SERVER then
		self:CallOnClient("SecondaryAttack")
		return
	end
	
	local owner = self:GetOwner()
	
	local position = owner:GetShootPos() + owner:GetAimVector() * gellyx.settings.get("gelly_gun_distance"):GetFloat()
	
	local material = gellyx.presets.getActivePreset().Material
	
	material.Absorption = hueToRGB(CurTime()) * math.max(material.Absorption.x, math.max(material.Absorption.y, material.Absorption.z))

	gellyx.emitters.Cube({
		center = position,
		velocity = owner:GetAimVector() * gellyx.settings.get("gelly_gun_secondary_velocity"):GetFloat(),
		bounds = self:GetSecondaryBounds(),
		density = gellyx.settings.get("gelly_gun_density"):GetInt(),
		material = material
	})

	self:SetNextSecondaryFire(CurTime() + 1 / self.FireRate * self.RapidFireBoost)
end

function SWEP:DoDrawCrosshair(x, y)
	surface.DrawCircle(
		x,
		y,
		CROSSHAIR_RADIUS,
		Color(255, 255, 255, 255)
	)
end

function SWEP:GetViewModelSwayVector()
	-- B = 2pi / P
	local swayX = math.sin(CurTime() * 2 * math.pi / X_SWAY_PERIOD) * X_SWAY_AMPLITUDE
	local swayY = math.sin(CurTime() * 2 * math.pi / Y_SWAY_PERIOD) * Y_SWAY_AMPLITUDE

	return Vector(swayX, 0, swayY)
end

function SWEP:IsParticleLimitNear()
	return gelly.GetStatus().ActiveParticles
		>= gelly.GetStatus().MaxParticles * PARTICLE_LIMIT_WARNING_PERCENT
end

function SWEP:IsInputBlocked()
	return vgui.GetKeyboardFocus() or gui.IsConsoleVisible() or gui.IsGameUIVisible()
end

function SWEP:ViewModelDrawn(vm)
	-- draw some 3D status indicators on the viewmodel
	-- top left corner
	local muzzleOrigin = vm:GetAttachment(vm:LookupAttachment("muzzle")).Pos
	if self.Forcefield then
		render.SetMaterial(forcefieldSprite)
		local deltaTime = math.min(CurTime() - self.ForcefieldActivationTime, FORCEFIELD_SPRITE_TIME) /
			FORCEFIELD_SPRITE_TIME
		-- sine ease out: https://easings.net/#easeOutSine
		deltaTime = math.sin((deltaTime * math.pi) / 2)

		local spriteSize = FORCEFIELD_SPRITE_SIZE * deltaTime
		render.DrawSprite(muzzleOrigin + self.Owner:GetAimVector() * 30, spriteSize, spriteSize, Color(100, 100, 255))
	end

	-- convert that to local space
	muzzleOrigin = vm:WorldToLocal(muzzleOrigin)

	local indicatorOrigin = vm:GetWorldTransformMatrix()
		* (
			Vector(40, INDICATOR_WIDTH_HU, INDICATOR_HEIGHT_OFFSET + INDICATOR_HEIGHT_HU)
			+ muzzleOrigin
			+ self:GetViewModelSwayVector()
		)

	local viewModelLeft = -vm:GetRight()
	local viewModelUp = vm:GetUp()

	local indicatorAngle = viewModelLeft:AngleEx(viewModelLeft:Cross(-viewModelUp))
	-- flip pitch
	indicatorAngle:RotateAroundAxis(viewModelLeft, 180)
	-- then turn it to face the player
	indicatorAngle:RotateAroundAxis(viewModelUp, 180)

	cam.Start3D2D(indicatorOrigin, indicatorAngle, 0.05) -- 1:20 scale
	draw.SimpleText(
		("%s"):format(gellyx.presets.getActivePreset().Name),
		"DermaLarge",
		0,
		0,
		Color(255, 255, 255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER
	)

	draw.SimpleText(
		"Press R for the menu",
		"DermaLarge",
		0,
		25,
		Color(255, 255, 255),
		TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER
	)

	if input.IsKeyDown(KEY_R) and not self:IsInputBlocked() then
		self:CreateMenu()
	end

	if self:IsParticleLimitNear() then
		-- show the particle progress bar
		local progress = gelly.GetStatus().ActiveParticles
			/ gelly.GetStatus().MaxParticles

		local warningStartColor = Color(230, 100, 0)
		local warningEndColor = Color(255, 0, 0)
		local colorProgress =
			math.Remap(progress, PARTICLE_LIMIT_WARNING_PERCENT, 1, 0, 1)

		local color = Color(
			Lerp(colorProgress, warningStartColor.r, warningEndColor.r),
			Lerp(colorProgress, warningStartColor.g, warningEndColor.g),
			Lerp(colorProgress, warningStartColor.b, warningEndColor.b),
			200
		)

		draw.RoundedBox(8, 0, 50, 200, 10, Color(0, 0, 0, 200))
		draw.RoundedBox(8, 0, 50, 200 * progress, 10, color)
	end

	cam.End3D2D()
end

function SWEP:CreateMenu()
	if GELLY_GUN_MENU then
		return
	end

	GELLY_GUN_MENU = vgui.Create("GellyGunMenu")
end

local function createMenuPanel()
	local PANEL = {}
	PANEL.BlurIterations = 4
	PANEL.MenuOptions = {}
	for _, preset in pairs(gellyx.presets.getAllPresets()) do
		table.insert(PANEL.MenuOptions, {
			Name = preset.Name,
			OnSelect = function()
				gelly.Reset()
				gellyx.presets.select(preset.Name)
			end,
		})
	end

	table.insert(PANEL.MenuOptions, {
		Name = "Clear particles",
		OnSelect = function()
			gelly.Reset()
		end,
	})

	PANEL.ArcSegments = 32
	PANEL.ArcAngleBias = 0 -- This makes it so menu options start out at left and right instead of top and bottom
	PANEL.LastSelectedOption = 1
	PANEL.LastSelectedOptionTime = CurTime()
	PANEL.NeutralZoneRadius = 120 -- neutral zone cancels selection

	function PANEL:Init()
		self:SetSize(ScrW(), ScrH())
		self:Center()
		self:MakePopup()
		self:SetTitle("Gelly Gun Menu")
		self:ShowCloseButton(false)
		self:SetDraggable(false)
	end

	function PANEL:CalculateFadeIn()
		local fadeInTime = 0.1
		local fadeInProgress =
			math.min((CurTime() - self.LastSelectedOptionTime) / fadeInTime, 1)

		return fadeInProgress
	end

	function PANEL:Paint(w, h)
		if not input.IsKeyDown(KEY_R) then
			if self.ActiveOption then
				self.ActiveOption.OnSelect()
				surface.PlaySound("garrysmod/ui_click.wav")
			end

			self:Remove()
			GELLY_GUN_MENU = nil
			return
		end

		-- draw a blurred background
		local x, y = self:LocalToScreen(0, 0)

		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(Material("pp/blurscreen"))
		for i = 1, self.BlurIterations do
			Material("pp/blurscreen"):SetFloat("$blur", (i / self.BlurIterations) * 6)
			Material("pp/blurscreen"):Recompute()
			render.UpdateScreenEffectTexture()
			render.SetScissorRect(x, y, x + w, y + h, true)
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			render.SetScissorRect(0, 0, 0, 0, false)
		end

		-- darken the background
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, 0, w, h)

		local normalizedMouseX = gui.MouseX() / ScrW()
		local normalizedMouseY = gui.MouseY() / ScrH()

		local userCursorAngle =
			math.atan2(gui.MouseY() / ScrH() - 0.5, gui.MouseX() / ScrW() - 0.5)

		-- we just take the sum of the squares of the normalized mouse vector to the center to get the distance
		local isCursorInNeutralZone = math.sqrt(
			(normalizedMouseX - 0.5) ^ 2 + (normalizedMouseY - 0.5) ^ 2
		) < self.NeutralZoneRadius / ScrW()

		if userCursorAngle < 0 then
			userCursorAngle = userCursorAngle + 2 * math.pi
		end

		-- draw a radial menu
		for i, option in ipairs(self.MenuOptions) do
			local angle = math.rad(360 / #self.MenuOptions * i) + self.ArcAngleBias
			local radius = ScrH() / 3
			local arcAnglePadding = math.rad(360 / #self.MenuOptions)

			local centerX = w / 2
			local centerY = h / 2

			local points = {}
			-- in order to have a circle in the middle, we need to render every outer arc point connected to their neighbors,
			-- then a reversed version of the inner arc points, then the outer arc points again in reverse order so that
			-- the GMod triangulation doesn't mess up the inner arc
			for arcSegment = 0, self.ArcSegments do
				local arcX = centerX
					+ math.cos(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* self.NeutralZoneRadius
				local arcY = centerY
					+ math.sin(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* self.NeutralZoneRadius

				-- start the actual arc from the neutral zone
				local extendedArcX = arcX
					+ math.cos(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* (radius - self.NeutralZoneRadius)

				local extendedArcY = arcY
					+ math.sin(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* (radius - self.NeutralZoneRadius)

				table.insert(points, { x = extendedArcX, y = extendedArcY })
			end

			-- revert the points so we can draw the inner arc
			for arcSegment = self.ArcSegments, 0, -1 do
				local arcX = centerX
					+ math.cos(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* self.NeutralZoneRadius
				local arcY = centerY
					+ math.sin(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* self.NeutralZoneRadius

				table.insert(points, { x = arcX, y = arcY })
			end

			-- and revert the points again so we can draw the outer arc
			for arcSegment = self.ArcSegments, 0, -1 do
				local arcX = centerX
					+ math.cos(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* self.NeutralZoneRadius
				local arcY = centerY
					+ math.sin(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* self.NeutralZoneRadius

				local extendedArcX = arcX
					+ math.cos(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* (radius - self.NeutralZoneRadius)

				local extendedArcY = arcY
					+ math.sin(
						angle + (arcAnglePadding / self.ArcSegments) * arcSegment
					)
					* (radius - self.NeutralZoneRadius)

				table.insert(points, { x = extendedArcX, y = extendedArcY })
				table.insert(points, { x = arcX, y = arcY })
			end

			local wrappedAngle = angle
			local wrappedAngleWithPadding = angle + arcAnglePadding

			-- there's an edge case where the angle wraps around 0

			if wrappedAngle >= 2 * math.pi then
				wrappedAngle = wrappedAngle - 2 * math.pi
			end

			if wrappedAngleWithPadding >= 2 * math.pi then
				wrappedAngleWithPadding = wrappedAngleWithPadding - 2 * math.pi
			end

			if
				angle + arcAnglePadding >= 2 * math.pi
				and wrappedAngle < 2 * math.pi
				and wrappedAngle > 0
			then
				wrappedAngleWithPadding = 2 * math.pi
			end

			local isSelected = userCursorAngle > wrappedAngle
				and userCursorAngle < wrappedAngleWithPadding
				and not isCursorInNeutralZone

			if isSelected then
				self.ActiveOption = option

				if self.LastSelectedOption ~= i then
					self.LastSelectedOption = i
					self.LastSelectedOptionTime = CurTime()
					surface.PlaySound("buttons/lightswitch2.wav")
				end
			end

			draw.NoTexture()
			local fade = isSelected and self:CalculateFadeIn() or 1
			surface.SetDrawColor(
				isSelected and Color(50 + 30 * fade, 50 + 30 * fade, 50 + 30 * fade)
				or Color(50, 50, 50)
			)

			surface.DrawPoly(points)

			local arcCenterX = centerX
				+ math.cos(angle + arcAnglePadding / 2) * self.NeutralZoneRadius * 1.5
			local arcCenterY = centerY
				+ math.sin(angle + arcAnglePadding / 2) * self.NeutralZoneRadius * 1.5

			draw.SimpleText(
				option.Name,
				"ChatFont",
				arcCenterX,
				arcCenterY,
				Color(255, 255, 255),
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER
			)
		end
	end

	vgui.Register("GellyGunMenu", PANEL, "DFrame")
end

-- autorefresh support
if gellyx and CLIENT then
	createMenuPanel()
end

hook.Add("GellyLoaded", "rainbow-gellygun.make-menu-panel", function()
	createMenuPanel()
end)
