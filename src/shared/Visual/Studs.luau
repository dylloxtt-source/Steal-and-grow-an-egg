--[[
	Классический «студ-стиль» Roblox: детали из пластика со студами сверху и
	впадинами (Inlet) снизу. Применяется ко всей карте и лобби одним проходом.
	Не трогает неон, стекло, лёд, полупрозрачные и невидимые детали (вода, барьеры).
]]

local Studs = {}

local KEEP = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Ice] = true,
}

function Studs.ApplyPart(part: BasePart)
	if KEEP[part.Material] or part.Transparency >= 0.3 then
		return
	end
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
end

function Studs.Apply(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			Studs.ApplyPart(d)
		end
	end
end

-- Классические цвета BrickColor
Studs.Colors = {
	BrightGreen = Color3.fromRGB(75, 151, 75),
	DarkGreen = Color3.fromRGB(40, 127, 71),
	BrickYellow = Color3.fromRGB(215, 197, 154),
	Nougat = Color3.fromRGB(204, 142, 105),
	ReddishBrown = Color3.fromRGB(105, 64, 40),
	BrightOrange = Color3.fromRGB(218, 133, 65),
	BrightRed = Color3.fromRGB(196, 40, 28),
	BrightBlue = Color3.fromRGB(13, 105, 172),
	BrightYellow = Color3.fromRGB(245, 205, 48),
	MediumStoneGrey = Color3.fromRGB(163, 162, 165),
	DarkStoneGrey = Color3.fromRGB(99, 95, 98),
	LightStoneGrey = Color3.fromRGB(229, 228, 223),
	White = Color3.fromRGB(242, 243, 243),
	PastelBlue = Color3.fromRGB(128, 187, 219),
	Black = Color3.fromRGB(27, 42, 53),
	ReallyBlack = Color3.fromRGB(17, 17, 17),
}

return Studs
