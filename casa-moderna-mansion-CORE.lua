--[[
	LUXURY MODERN MANSION - construcción procedural en Luau
	Colocar en un Script dentro de ServerScriptService. Al ejecutar, la casa se construye en Workspace.
	Solo piezas nativas (Part, Cylinder, Ball, Wedge). Sin assets externos.
	Fachada principal hacia Z negativo. Piscina y terraza en la parte trasera (Z positivo).
]]

local Workspace = game:GetService("Workspace")

local old = Workspace:FindFirstChild("LuxuryModernMansion")
if old then old:Destroy() end

local Mansion = Instance.new("Model")
Mansion.Name = "LuxuryModernMansion"
Mansion.Parent = Workspace

local function newModel(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or Mansion
	return m
end

local Exterior = newModel("Exterior")
local Structure = newModel("Structure")
local GroundFloor = newModel("GroundFloor")
local UpperFloor = newModel("UpperFloor")
local Furniture = newModel("Furniture")
local Lighting = newModel("Lighting")
local Garden = newModel("Garden")
local Pool = newModel("Pool")
local Garage = newModel("Garage")
local Decorations = newModel("Decorations")

local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = {
	warmWhite = rgb(242, 239, 232), white = rgb(245, 245, 245), concrete = rgb(125, 125, 125),
	dark = rgb(48, 51, 55), black = rgb(24, 25, 27), wood = rgb(135, 92, 58), woodLight = rgb(190, 153, 112),
	beige = rgb(210, 198, 177), stone = rgb(221, 216, 205), green = rgb(65, 110, 74),
	glass = rgb(170, 205, 220), greenDark = rgb(45, 85, 55), greenLight = rgb(88, 140, 90),
	gray = rgb(150, 150, 150), lightGray = rgb(200, 200, 200), water = rgb(40, 165, 205),
	warmLight = rgb(255, 214, 160), neutralLight = rgb(255, 244, 232), cream = rgb(232, 222, 202),
	navy = rgb(52, 62, 82), rust = rgb(168, 92, 60), mustard = rgb(201, 160, 70),
}

-- Constantes de altura
local G = 1.2        -- nivel de piso terminado, planta baja
local FL = 1.0       -- parte superior de la losa de cimentación
local S1 = 16.2      -- cara inferior de la losa del segundo piso
local F2 = 17.4      -- nivel de piso terminado, segundo piso
local S2 = 30.4      -- altura de muros alas oeste
local S2E = 28.9     -- altura de muros ala este
local HT = 32.0      -- altura volumen central (hall)
local TE, TI = 0.8, 0.4 -- grosor muro exterior / interior

---------------------------------------------------------------------
-- FUNCIONES BASE
---------------------------------------------------------------------
local function fix(a, b)
	if a > b then a, b = b, a end
	if b - a < 0.05 then local m = (a + b) / 2 return m - 0.025, m + 0.025 end
	return a, b
end

-- createPart: pieza por límites (x0..x1, y0..y1, z0..z1)
local function box(parent, name, x0, x1, y0, y1, z0, z1, mat, col, o)
	o = o or {}
	x0, x1 = fix(x0, x1); y0, y1 = fix(y0, y1); z0, z1 = fix(z0, z1)
	local p = Instance.new(o.wedge and "WedgePart" or "Part")
	p.Name = name
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	local cf = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	if o.rot then
		cf = cf * CFrame.Angles(math.rad(o.rot.X), math.rad(o.rot.Y), math.rad(o.rot.Z))
	end
	p.CFrame = cf
	p.Material = mat
	p.Color = col
	p.Anchored = true
	p.CanCollide = o.collide ~= false
	p.CastShadow = o.shadow ~= false
	p.Transparency = o.transp or 0
	if o.refl then p.Reflectance = o.refl end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- cilindro vertical (eje Y)
local function cyl(parent, name, cx, y0, y1, cz, d, mat, col, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(math.max(y1 - y0, 0.05), d, d)
	p.CFrame = CFrame.new(cx, (y0 + y1) / 2, cz) * CFrame.Angles(0, 0, math.rad(90))
	p.Material = mat
	p.Color = col
	p.Anchored = true
	p.CanCollide = o.collide ~= false
	p.CastShadow = o.shadow ~= false
	p.Transparency = o.transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(parent, name, x, y, z, d, mat, col, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, o.dy or d, d)
	p.CFrame = CFrame.new(x, y, z)
	p.Material = mat
	p.Color = col
	p.Anchored = true
	p.CanCollide = o.collide == true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- pieza con CFrame libre (rotaciones)
local function cfPart(parent, name, size, cf, mat, col, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Material = mat
	p.Color = col
	p.Anchored = true
	p.CanCollide = o.collide ~= false
	p.Transparency = o.transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function addLight(p, kind, brightness, range, col, face)
	local l = Instance.new(kind)
	l.Brightness = brightness
	l.Range = range
	l.Color = col or C.warmLight
	if kind == "SpotLight" then
		l.Angle = 100
		l.Face = face or Enum.NormalId.Bottom
	end
	l.Shadows = false
	l.Parent = p
	return l
end

-- downlight empotrado en techo
local function downlight(parent, x, ceilY, z, col, bright, range)
	local p = cyl(parent, "Downlight", x, ceilY - 0.15, ceilY, z, 0.9, M.Neon, col or C.warmLight, { collide = false, shadow = false })
	addLight(p, "PointLight", bright or 0.7, range or 14, col or C.warmLight)
	return p
end

-- sub-modelo ordenado
local function sub(parent, name) return newModel(name, parent) end

-- segmento de muro con grosor t (eje "x": muro a lo largo de X en z=c; eje "z": a lo largo de Z en x=c)
local function seg(parent, name, axis, c, t, a0, a1, y0, y1, mat, col)
	if a1 - a0 < 0.03 or y1 - y0 < 0.03 then return nil end
	if axis == "x" then
		return box(parent, name, a0, a1, y0, y1, c - t / 2, c + t / 2, mat, col)
	else
		return box(parent, name, c - t / 2, c + t / 2, y0, y1, a0, a1, mat, col)
	end
end

-- createWall: muro con vanos {a, b, yInferior, ySuperior}
local function createWall(parent, name, axis, c, a0, a1, y0, y1, t, mat, col, openings)
	openings = openings or {}
	table.sort(openings, function(p, q) return p[1] < q[1] end)
	local cur = a0
	for i, op in ipairs(openings) do
		seg(parent, name .. "_seg" .. i, axis, c, t, cur, op[1], y0, y1, mat, col)
		seg(parent, name .. "_sill" .. i, axis, c, t, op[1], op[2], y0, op[3], mat, col)
		seg(parent, name .. "_head" .. i, axis, c, t, op[1], op[2], op[4], y1, mat, col)
		cur = op[2]
	end
	seg(parent, name .. "_end", axis, c, t, cur, a1, y0, y1, mat, col)
end

-- createWindow: marco negro + vidrio + parteluces
local function createWindow(parent, name, axis, c, a, b, y0, y1, noTransom)
	local ft = 0.35
	local m = sub(parent, name)
	seg(m, "FrameL", axis, c, 0.7, a, a + ft, y0, y1, M.Metal, C.black)
	seg(m, "FrameR", axis, c, 0.7, b - ft, b, y0, y1, M.Metal, C.black)
	seg(m, "FrameB", axis, c, 0.7, a, b, y0, y0 + ft, M.Metal, C.black)
	seg(m, "FrameT", axis, c, 0.7, a, b, y1 - ft, y1, M.Metal, C.black)
	if y0 > 4 then
		seg(m, "Sill", axis, c, 1.5, a - 0.25, b + 0.25, y0 - 0.3, y0, M.Concrete, C.warmWhite)
	end
	local g = seg(m, "Glass", axis, c, 0.12, a + ft, b - ft, y0 + ft, y1 - ft, M.Glass, C.glass)
	if g then g.Transparency = 0.55 g.Reflectance = 0.05 end
	local n = math.max(1, math.floor((b - a) / 6.5 + 0.5))
	local step = (b - a) / n
	for i = 1, n - 1 do
		seg(m, "Mullion" .. i, axis, c, 0.5, a + i * step - 0.15, a + i * step + 0.15, y0, y1, M.Metal, C.black)
	end
	if (y1 - y0) > 9 and not noTransom then
		local ty = y0 + (y1 - y0) * 0.72
		seg(m, "Transom", axis, c, 0.5, a, b, ty - 0.15, ty + 0.15, M.Metal, C.black)
	end
	return m
end

-- ventanal corredizo: vidrio a ambos lados con paso central libre
local function createSlider(parent, name, axis, c, a, b, y0, y1, gap)
	local mid = (a + b) / 2
	createWindow(parent, name .. "_L", axis, c, a, mid - gap / 2, y0, y1)
	createWindow(parent, name .. "_R", axis, c, mid + gap / 2, b, y0, y1)
	seg(parent, name .. "_Head", axis, c, 0.7, mid - gap / 2, mid + gap / 2, y1 - 0.35, y1, M.Metal, C.black)
end

-- createDoor: marco negro + hoja(s) abiertas contra el muro. dir = lado hacia donde abre (+1/-1)
local function createDoor(parent, name, axis, c, t, a, b, y0, y1, dir, double, mat, col)
	local m = sub(parent, name)
	seg(m, "JambA", axis, c, t + 0.1, a, a + 0.22, y0, y1, M.Metal, C.black)
	seg(m, "JambB", axis, c, t + 0.1, b - 0.22, b, y0, y1, M.Metal, C.black)
	seg(m, "Head", axis, c, t + 0.1, a, b, y1 - 0.25, y1, M.Metal, C.black)
	local function leaf(hinge, len, tag)
		local s0 = c + dir * (t / 2)
		local s1 = c + dir * (t / 2 + len)
		local lo, hi = math.min(s0, s1), math.max(s0, s1)
		local lf, hd
		if axis == "x" then
			lf = box(m, "Leaf" .. tag, hinge - 0.12, hinge + 0.12, y0, y1 - 0.3, lo, hi, mat, col)
			hd = box(m, "Handle" .. tag, hinge - 0.2, hinge + 0.2, y0 + 3.6, y0 + 4.2, (dir > 0 and hi - 0.6 or lo + 0.2), (dir > 0 and hi - 0.2 or lo + 0.6), M.Metal, C.black)
		else
			lf = box(m, "Leaf" .. tag, lo, hi, y0, y1 - 0.3, hinge - 0.12, hinge + 0.12, mat, col)
			hd = box(m, "Handle" .. tag, (dir > 0 and hi - 0.6 or lo + 0.2), (dir > 0 and hi - 0.2 or lo + 0.6), y0 + 3.6, y0 + 4.2, hinge - 0.2, hinge + 0.2, M.Metal, C.black)
		end
	end
	if double then
		local w = (b - a - 0.44) / 2
		leaf(a + 0.34, w, "A")
		leaf(b - 0.34, w, "B")
	else
		leaf(a + 0.34, b - a - 0.5, "A")
	end
	return m
end

-- revestimiento vertical de madera sobre un muro (side = +1/-1 hacia donde sobresale)
local function woodCladding(parent, name, axis, c, side, a0, a1, y0, y1, t)
	local m = sub(parent, name)
	local off0, off1 = c + side * (t / 2), c + side * (t / 2 + 0.35)
	local lo, hi = math.min(off0, off1), math.max(off0, off1)
	local function put(nm, p0, p1, q0, q1, mat, col)
		if axis == "x" then box(m, nm, p0, p1, y0, y1, q0, q1, mat, col)
		else box(m, nm, q0, q1, y0, y1, p0, p1, mat, col) end
	end
	put("Base", a0, a1, lo, hi, M.WoodPlanks, C.wood)
	local x = a0 + 0.6
	local i = 0
	while x < a1 - 0.5 do
		i = i + 1
		local o0, o1 = c + side * (t / 2 + 0.35), c + side * (t / 2 + 0.55)
		put("Slat" .. i, x, x + 0.35, math.min(o0, o1), math.max(o0, o1), M.Wood, C.woodLight)
		x = x + 1.9
	end
end

---------------------------------------------------------------------
-- MOBILIARIO PROCEDURAL (coordenadas locales: +Z = frente del mueble)
---------------------------------------------------------------------
local function L(parent, cx, cz, rot, yb)
	local function tr(lx, lz)
		if rot == 0 then return cx + lx, cz + lz
		elseif rot == 90 then return cx + lz, cz - lx
		elseif rot == 180 then return cx - lx, cz - lz
		else return cx - lz, cz + lx end
	end
	return function(name, lx0, lx1, y0, y1, lz0, lz1, mat, col, o)
		local ax, az = tr(lx0, lz0)
		local bx, bz = tr(lx1, lz1)
		return box(parent, name, math.min(ax, bx), math.max(ax, bx), yb + y0, yb + y1, math.min(az, bz), math.max(az, bz), mat, col, o)
	end
end

local function lighten(c, k) return Color3.new(math.min(c.R + k, 1), math.min(c.G + k, 1), math.min(c.B + k, 1)) end

local function createSofa(parent, cx, cz, rot, yb, w, col)
	local m = sub(parent, "Sofa")
	local b = L(m, cx, cz, rot, yb)
	local h = w / 2
	b("Base", -h, h, 0.4, 1.4, -1.7, 1.7, M.Fabric, col)
	b("Back", -h, h, 1.4, 3.5, -1.7, -0.75, M.Fabric, col)
	b("ArmL", -h, -h + 0.7, 1.4, 2.6, -0.75, 1.7, M.Fabric, col)
	b("ArmR", h - 0.7, h, 1.4, 2.6, -0.75, 1.7, M.Fabric, col)
	local n = math.max(1, math.floor((w - 1.4) / 3))
	local cw = (w - 1.4) / n
	for i = 1, n do
		local x0 = -h + 0.7 + (i - 1) * cw
		b("SeatCushion" .. i, x0 + 0.05, x0 + cw - 0.05, 1.4, 2.0, -0.7, 1.65, M.Fabric, lighten(col, 0.05))
		b("BackCushion" .. i, x0 + 0.1, x0 + cw - 0.1, 2.0, 3.3, -0.75, -0.05, M.Fabric, lighten(col, 0.1))
	end
	for _, sx in ipairs({ -h + 0.3, h - 0.6 }) do
		for _, sz in ipairs({ -1.5, 1.3 }) do
			b("Leg", sx, sx + 0.3, 0, 0.4, sz, sz + 0.3, M.Metal, C.black)
		end
	end
	return m
end

local function createTable(parent, name, cx, cz, rot, yb, w, d, h, topMat, topCol, legCol)
	local m = sub(parent, name)
	local b = L(m, cx, cz, rot, yb)
	b("Top", -w / 2, w / 2, h - 0.3, h, -d / 2, d / 2, topMat, topCol)
	b("Apron", -w / 2 + 0.3, w / 2 - 0.3, h - 0.7, h - 0.3, -d / 2 + 0.3, d / 2 - 0.3, M.Wood, legCol)
	for _, sx in ipairs({ -w / 2 + 0.2, w / 2 - 0.5 }) do
		for _, sz in ipairs({ -d / 2 + 0.2, d / 2 - 0.5 }) do
			b("Leg", sx, sx + 0.3, 0, h - 0.3, sz, sz + 0.3, M.Metal, legCol)
		end
	end
	return m
end

local function createChair(parent, cx, cz, rot, yb, col, tall)
	local m = sub(parent, "Chair")
	local b = L(m, cx, cz, rot, yb)
	local sh = tall or 1.7
	b("Seat", -0.8, 0.8, sh, sh + 0.3, -0.8, 0.8, M.Fabric, col)
	b("Back", -0.8, 0.8, sh + 0.3, sh + 2.0, -0.8, -0.55, M.Fabric, col)
	for _, sx in ipairs({ -0.8, 0.6 }) do
		for _, sz in ipairs({ -0.8, 0.6 }) do
			b("Leg", sx, sx + 0.2, 0, sh, sz, sz + 0.2, M.Wood, C.wood)
		end
	end
	return m
end

local function createRug(parent, cx, cz, yb, w, d, col, rot)
	local b = L(parent, cx, cz, rot or 0, yb)
	b("Rug", -w / 2, w / 2, 0, 0.12, -d / 2, d / 2, M.Fabric, col)
	b("RugBorder", -w / 2 + 0.5, w / 2 - 0.5, 0.12, 0.16, -d / 2 + 0.5, d / 2 - 0.5, M.Fabric, lighten(col, 0.08))
end

local function createPlant(parent, x, z, yb, scale)
	scale = scale or 1
	local m = sub(parent, "Plant")
	cyl(m, "Pot", x, yb, yb + 1.3 * scale, z, 1.5 * scale, M.Concrete, C.white)
	cyl(m, "Soil", x, yb + 1.3 * scale, yb + 1.4 * scale, z, 1.2 * scale, M.Slate, C.black)
	ball(m, "LeavesA", x, yb + 2.6 * scale, z, 2.2 * scale, M.Grass, C.green)
	ball(m, "LeavesB", x + 0.5 * scale, yb + 3.4 * scale, z - 0.3 * scale, 1.7 * scale, M.Grass, C.greenLight)
	ball(m, "LeavesC", x - 0.5 * scale, yb + 3.0 * scale, z + 0.4 * scale, 1.5 * scale, M.Grass, C.greenDark)
	return m
end

local function createLamp(parent, x, z, yb, h)
	local m = sub(parent, "FloorLamp")
	h = h or 5.5
	cyl(m, "Base", x, yb, yb + 0.2, z, 1.2, M.Metal, C.black)
	cyl(m, "Pole", x, yb + 0.2, yb + h, z, 0.18, M.Metal, C.black)
	local sh = cyl(m, "Shade", x, yb + h - 0.3, yb + h + 0.9, z, 1.4, M.Neon, C.warmLight, { collide = false })
	sh.Transparency = 0.15
	addLight(sh, "PointLight", 0.8, 12, C.warmLight)
	return m
end

local function createPendant(parent, x, z, y, ceil, d)
	local m = sub(parent, "PendantLamp")
	cyl(m, "Cord", x, y + 0.9, ceil, z, 0.1, M.Metal, C.black, { collide = false })
	cyl(m, "Shade", x, y, y + 0.9, z, d or 2, M.Metal, C.black, { collide = false })
	local bulb = cyl(m, "Bulb", x, y - 0.12, y + 0.05, z, (d or 2) * 0.8, M.Neon, C.warmLight, { collide = false })
	addLight(bulb, "PointLight", 0.9, 14, C.warmLight)
	return m
end

local function createPainting(parent, cx, cz, rot, yb, w, h, seed)
	local m = sub(parent, "Painting")
	local b = L(m, cx, cz, rot, yb)
	b("Frame", -w / 2, w / 2, 0, h, 0, 0.18, M.Metal, C.black)
	local pal = { C.rust, C.mustard, C.navy, C.cream, C.green }
	b("Canvas", -w / 2 + 0.2, w / 2 - 0.2, 0.2, h - 0.2, 0.18, 0.24, M.SmoothPlastic, C.beige)
	for i = 1, 3 do
		local k = ((seed or 1) + i) % #pal + 1
		local x0 = -w / 2 + 0.4 + (i - 1) * (w - 0.8) / 3
		b("Shape" .. i, x0, x0 + (w - 0.8) / 3 - 0.2, 0.5 + i * h * 0.1, h * 0.5 + i * h * 0.12, 0.24, 0.3, M.SmoothPlastic, pal[k])
	end
end

local function createBookshelf(parent, cx, cz, rot, yb, w, h)
	local m = sub(parent, "Bookshelf")
	local b = L(m, cx, cz, rot, yb)
	b("Back", -w / 2, w / 2, 0, h, 0, 0.2, M.Wood, C.wood)
	b("SideL", -w / 2, -w / 2 + 0.25, 0, h, 0, 1.3, M.Wood, C.wood)
	b("SideR", w / 2 - 0.25, w / 2, 0, h, 0, 1.3, M.Wood, C.wood)
	local rows = math.max(2, math.floor(h / 1.7))
	local pal = { C.navy, C.rust, C.cream, C.mustard, C.green, C.dark }
	for r = 0, rows do
		local y = r * (h - 0.25) / rows
		b("Shelf" .. r, -w / 2, w / 2, y, y + 0.25, 0, 1.3, M.Wood, C.woodLight)
		if r < rows then
			local x = -w / 2 + 0.5
			local k = 0
			while x < w / 2 - 1.0 and k < 9 do
				k = k + 1
				local bw = 0.3 + (k % 3) * 0.12
				b("Book" .. r .. "_" .. k, x, x + bw, y + 0.25, y + 1.1 + (k % 2) * 0.25, 0.3, 1.0, M.SmoothPlastic, pal[(k + r) % #pal + 1])
				x = x + bw + 0.12
				if k % 4 == 0 then x = x + 1.2 end
			end
		end
	end
end

local function createCabinet(parent, name, cx, cz, rot, yb, w, h, d, col, doors)
	local m = sub(parent, name)
	local b = L(m, cx, cz, rot, yb)
	b("Carcass", -w / 2, w / 2, 0, h, 0, d, M.Wood, col)
	local n = doors or math.max(1, math.floor(w / 2.4))
	local dw = w / n
	for i = 1, n do
		local x0 = -w / 2 + (i - 1) * dw
		b("Door" .. i, x0 + 0.06, x0 + dw - 0.06, 0.15, h - 0.15, d, d + 0.1, M.SmoothPlastic, lighten(col, 0.04))
		b("Handle" .. i, x0 + dw - 0.45, x0 + dw - 0.3, h * 0.4, h * 0.4 + 1.0, d + 0.1, d + 0.25, M.Metal, C.black)
	end
	return m
end

local function createTV(parent, cx, cz, rot, yb, w)
	local m = sub(parent, "Television")
	local b = L(m, cx, cz, rot, yb)
	local h = w * 0.56
	b("Bezel", -w / 2, w / 2, 0, h, 0, 0.3, M.Metal, C.black)
	b("Screen", -w / 2 + 0.15, w / 2 - 0.15, 0.15, h - 0.15, 0.3, 0.34, M.Glass, rgb(14, 18, 24))
end

local function createBed(parent, cx, cz, rot, yb, w, sheet, accent)
	local m = sub(parent, "Bed")
	local b = L(m, cx, cz, rot, yb)
	local hw = w / 2
	b("Frame", -hw - 0.2, hw + 0.2, 0.5, 1.4, 0, 7.6, M.Wood, C.wood)
	b("Mattress", -hw, hw, 1.4, 2.4, 0.3, 7.5, M.Fabric, C.white)
	b("Headboard", -hw - 0.6, hw + 0.6, 0.5, 5.2, -0.4, 0.3, M.Fabric, accent)
	b("HeadboardTrim", -hw - 0.6, hw + 0.6, 5.2, 5.4, -0.4, 0.3, M.Wood, C.wood)
	b("PillowL", -hw + 0.3, -0.1, 2.4, 3.1, 0.6, 2.0, M.Fabric, C.white)
	b("PillowR", 0.1, hw - 0.3, 2.4, 3.1, 0.6, 2.0, M.Fabric, C.white)
	b("Blanket", -hw - 0.05, hw + 0.05, 2.4, 2.8, 3.2, 7.55, M.Fabric, sheet)
	b("Throw", -hw * 0.5, hw * 0.5, 2.8, 3.0, 5.4, 6.3, M.Fabric, accent)
	for _, sx in ipairs({ -hw - 0.2, hw - 0.1 }) do
		for _, sz in ipairs({ 0, 7.3 }) do
			b("Leg", sx, sx + 0.3, 0, 0.5, sz, sz + 0.3, M.Metal, C.black)
		end
	end
	return m
end

local function createNightstand(parent, cx, cz, rot, yb)
	local m = sub(parent, "Nightstand")
	local b = L(m, cx, cz, rot, yb)
	b("Body", -1, 1, 0.4, 2.2, -1, 1, M.Wood, C.woodLight)
	b("Drawer", -0.85, 0.85, 0.7, 1.9, 1, 1.1, M.SmoothPlastic, C.beige)
	b("Pull", -0.3, 0.3, 1.2, 1.4, 1.1, 1.25, M.Metal, C.black)
	b("LegA", -0.9, -0.6, 0, 0.4, -0.9, -0.6, M.Metal, C.black)
	b("LegB", 0.6, 0.9, 0, 0.4, 0.6, 0.9, M.Metal, C.black)
	cyl(m, "LampBase", cx, yb + 2.2, yb + 2.7, cz, 0.7, M.Metal, C.black)
	local sh = cyl(m, "LampShade", cx, yb + 2.7, yb + 3.6, cz, 1.1, M.Neon, C.warmLight, { collide = false })
	sh.Transparency = 0.2
	addLight(sh, "PointLight", 0.6, 9, C.warmLight)
end

local function createWardrobe(parent, cx, cz, rot, yb, w, h, col)
	return createCabinet(parent, "Wardrobe", cx, cz, rot, yb, w, h, 2.2, col or C.woodLight, math.max(2, math.floor(w / 2.2)))
end

local function createDesk(parent, cx, cz, rot, yb, w)
	-- mesa en local z 0..3, silla en z -3.5 mirando +Z
	local m = sub(parent, "DeskSet")
	local b = L(m, cx, cz, rot, yb)
	b("Top", -w / 2, w / 2, 2.5, 2.8, 0, 3, M.Wood, C.woodLight)
	b("PanelL", -w / 2 + 0.1, -w / 2 + 0.4, 0, 2.5, 0.2, 2.8, M.Metal, C.black)
	b("PanelR", w / 2 - 0.4, w / 2 - 0.1, 0, 2.5, 0.2, 2.8, M.Metal, C.black)
	b("Drawer", w / 2 - 2.6, w / 2 - 0.4, 0.8, 2.5, 0.2, 2.8, M.Wood, C.wood)
	b("MonitorStand", -0.3, 0.3, 2.8, 3.4, 1.2, 1.7, M.Metal, C.black)
	b("Monitor", -1.7, 1.7, 3.3, 5.3, 1.3, 1.5, M.Metal, C.black)
	b("MonitorScreen", -1.6, 1.6, 3.4, 5.2, 1.2, 1.3, M.Glass, rgb(20, 40, 70))
	b("Keyboard", -1.1, 1.1, 2.8, 2.95, 0.4, 1.0, M.SmoothPlastic, C.dark)
	b("PC", w / 2 - 1.3, w / 2 - 0.5, 2.8, 4.4, 1.2, 2.4, M.Metal, C.dark)
	cyl(m, "DeskLampBase", cx + 0, yb + 2.8, yb + 2.9, cz + 0.5, 0.5, M.Metal, C.black)
	createChair(m, cx, cz - 3.4, rot, yb, C.dark, 1.6)
end

local function createStool(parent, x, z, yb)
	cyl(parent, "StoolSeat", x, yb + 2.3, yb + 2.6, z, 1.4, M.Fabric, C.dark)
	cyl(parent, "StoolPole", x, yb, yb + 2.3, z, 0.2, M.Metal, C.black)
	cyl(parent, "StoolBase", x, yb, yb + 0.15, z, 1.1, M.Metal, C.black)
end

local function createLounger(parent, cx, cz, rot, yb)
	local m = sub(parent, "SunLounger")
	local b = L(m, cx, cz, rot, yb)
	b("Frame", -1.1, 1.1, 0.5, 0.9, -3.2, 2.9, M.Metal, C.white)
	b("Cushion", -1.0, 1.0, 0.9, 1.25, -3.1, 0.7, M.Fabric, C.cream)
	b("BackRestA", -1.0, 1.0, 1.25, 1.75, 0.6, 1.4, M.Fabric, C.cream)
	b("BackRestB", -1.0, 1.0, 1.75, 2.35, 1.4, 2.2, M.Fabric, C.cream)
	b("BackRestC", -1.0, 1.0, 2.35, 2.9, 2.2, 2.9, M.Fabric, C.cream)
	b("LegA", -1.0, -0.8, 0, 0.5, -3.1, -2.9, M.Metal, C.white)
	b("LegB", 0.8, 1.0, 0, 0.5, 2.6, 2.8, M.Metal, C.white)
end

---------------------------------------------------------------------
-- FUNCIONES GENÉRICAS ADICIONALES
---------------------------------------------------------------------
local createPart = box

-- createFloor: piso por límites en planta (x0..x1, z0..z1) entre alturas y0..y1
local function createFloor(parent, name, x0, x1, z0, z1, y0, y1, mat, col)
	return box(parent, name, x0, x1, y0, y1, z0, z1, mat, col)
end

-- createFurniture: mueble genérico a partir de una lista de piezas locales
-- cada pieza: { x0, x1, y0, y1, z0, z1, material, color }
local function createFurniture(parent, name, cx, cz, rot, yb, parts)
	local m = sub(parent, name)
	local b = L(m, cx, cz, rot, yb)
	for i, p in ipairs(parts) do
		b(name .. "_P" .. i, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
	end
	return m
end

-- createRoom: zócalos negros y moldura de techo (sin colisión) en el perímetro interior de una habitación
-- skip[lado] = true omite el lado completo; skip[lado] = { {a,b}, ... } deja huecos en el zócalo (puertas/aberturas)
-- lados: front (z0), back (z1), west (x0), east (x1)
local function createRoom(parent, name, x0, x1, z0, z1, yFloor, yCeil, skip)
	skip = skip or {}
	local m = sub(parent, name)
	local o = { collide = false }
	local bh, bt = 0.6, 0.15
	local function pieces(a0, a1, gaps)
		local out, cur = {}, a0
		table.sort(gaps, function(p, q) return p[1] < q[1] end)
		for _, g in ipairs(gaps) do
			if g[1] > cur then table.insert(out, { cur, g[1] }) end
			cur = math.max(cur, g[2])
		end
		if a1 > cur then table.insert(out, { cur, a1 }) end
		return out
	end
	local function side(tag, axis, c0, c1, a0, a1, k0, k1)
		local s = skip[tag]
		if s == true then return end
		local gaps = (type(s) == "table") and s or {}
		for i, pc in ipairs(pieces(a0, a1, gaps)) do
			if axis == "x" then
				box(m, "Base_" .. tag .. i, pc[1], pc[2], yFloor, yFloor + bh, c0, c1, M.SmoothPlastic, C.dark, o)
			else
				box(m, "Base_" .. tag .. i, c0, c1, yFloor, yFloor + bh, pc[1], pc[2], M.SmoothPlastic, C.dark, o)
			end
		end
		if axis == "x" then
			box(m, "Crown_" .. tag, a0, a1, yCeil - 0.4, yCeil, k0, k1, M.SmoothPlastic, C.warmWhite, o)
		else
			box(m, "Crown_" .. tag, k0, k1, yCeil - 0.4, yCeil, a0, a1, M.SmoothPlastic, C.warmWhite, o)
		end
	end
	side("front", "x", z0, z0 + bt, x0, x1, z0, z0 + 0.3)
	side("back", "x", z1 - bt, z1, x0, x1, z1 - 0.3, z1)
	side("west", "z", x0, x0 + bt, z0, z1, x0, x0 + 0.3)
	side("east", "z", x1 - bt, x1, z0, z1, x1 - 0.3, x1)
	return m
end

---------------------------------------------------------------------
-- UTILIDADES DE ESTRUCTURA
---------------------------------------------------------------------
local UY = F2 - 0.2 -- cara superior de la losa del segundo piso (17.2)

local function createArch(parent, name, axis, c, t, a, b, y0, y1)
	seg(parent, name .. "_JambA", axis, c, t + 0.1, a, a + 0.2, y0, y1, M.Metal, C.black)
	seg(parent, name .. "_JambB", axis, c, t + 0.1, b - 0.2, b, y0, y1, M.Metal, C.black)
	seg(parent, name .. "_Head", axis, c, t + 0.1, a, b, y1 - 0.25, y1, M.Metal, C.black)
end

-- barandilla de vidrio con pasamanos negro
local function createRail(parent, name, axis, c, a0, a1, yb, h)
	h = h or 3.5
	local g = seg(parent, name .. "_Glass", axis, c, 0.12, a0, a1, yb + 0.3, yb + h, M.Glass, C.glass)
	if g then g.Transparency = 0.6 end
	seg(parent, name .. "_TopRail", axis, c, 0.3, a0, a1, yb + h, yb + h + 0.2, M.Metal, C.black)
	seg(parent, name .. "_BaseRail", axis, c, 0.3, a0, a1, yb, yb + 0.3, M.Metal, C.black)
	local n = math.max(1, math.floor((a1 - a0) / 6))
	for i = 0, n do
		local a = a0 + i * (a1 - a0) / n
		seg(parent, name .. "_Post" .. i, axis, c, 0.3, a - 0.12, a + 0.12, yb, yb + h, M.Metal, C.black)
	end
end

local function slopedGlass(parent, name, x, z0, y0, z1, y1)
	if z1 < z0 then z0, z1 = z1, z0; y0, y1 = y1, y0 end
	local dz, dy = z1 - z0, y1 - y0
	local len = math.sqrt(dz * dz + dy * dy)
	local ang = math.atan2(dy, dz)
	local mz, my = (z0 + z1) / 2, (y0 + y1) / 2 + 1.7
	cfPart(parent, name, Vector3.new(0.12, 3.2, len), CFrame.new(x, my, mz) * CFrame.Angles(-ang, 0, 0), M.Glass, C.glass, { transp = 0.6 })
	cfPart(parent, name .. "_Rail", Vector3.new(0.22, 0.22, len), CFrame.new(x, my + 1.6, mz) * CFrame.Angles(-ang, 0, 0), M.Metal, C.black)
end

---------------------------------------------------------------------
-- CIMENTACIÓN Y PISOS
---------------------------------------------------------------------
box(Structure, "Foundation", -33, 33, 0, FL, -25, 25, M.Concrete, C.dark)

local GF = sub(GroundFloor, "Floors")
createFloor(GF, "Living_Floor", -32, -6, -24, 0, FL, G, M.Marble, C.stone)
createFloor(GF, "Hall_Floor", -6, 8, -24, 0, FL, G, M.Marble, C.white)
createFloor(Garage, "Garage_Floor", 8, 32, -24, 0, FL, G, M.Concrete, C.concrete)
createFloor(GF, "Office_Floor", -32, -14, 0, 24, FL, G, M.WoodPlanks, C.wood)
createFloor(GF, "Dining_Floor", -14, 4, 0, 24, FL, G, M.WoodPlanks, C.woodLight)
createFloor(GF, "Kitchen_Floor", 4, 22, 0, 24, FL, G, M.Marble, C.stone)
createFloor(GF, "GuestBath_Floor", 22, 32, 0, 10, FL, G, M.Marble, C.lightGray)
createFloor(GF, "Pantry_Floor", 22, 32, 10, 24, FL, G, M.Concrete, C.gray)

-- losa del segundo piso (con vacío para la escalera) + acabado de madera
local slabRects = {
	{ -32.4, 0.2, -24.4, 24.4 }, { 0.2, 3.7, -24.4, -16 }, { 0.2, 3.7, -4.6, 24.4 },
	{ 3.7, 8, -24.4, -22.5 }, { 3.7, 8, -4.6, 24.4 }, { 8, 32.4, -24.4, 24.4 },
}
for i, r in ipairs(slabRects) do
	box(Structure, "UpperSlab" .. i, r[1], r[2], S1, UY, r[3], r[4], M.Concrete, C.warmWhite)
	local fz0 = r[3]
	if i == 6 then fz0 = -12 end -- la terraza frontal tiene su propio deck
	box(UpperFloor, "UpperFloorFinish" .. i, r[1], r[2], UY, F2, fz0, r[4], M.WoodPlanks, C.woodLight)
end
local UF = sub(UpperFloor, "FloorOverlays")
createFloor(UF, "MasterBath_Floor", -20, -8, 0.3, 11.8, F2, F2 + 0.08, M.Marble, C.stone)
createFloor(UF, "Closet_Floor", -32, -20, 0.3, 11.8, F2, F2 + 0.08, M.Fabric, C.beige)
createFloor(UF, "Cinema_Floor", 8.3, 32, -12, 8, F2, F2 + 0.08, M.Fabric, rgb(58, 54, 62))

---------------------------------------------------------------------
-- MUROS EXTERIORES: PLANTA BAJA
---------------------------------------------------------------------
local GW = sub(GroundFloor, "ExteriorWalls")
local WH = C.warmWhite
createWall(GW, "FrontWall", "x", -24, -32.4, 32.4, FL, S1, TE, M.Concrete, WH,
	{ { -30, -8.5, FL, 14.8 }, { -4, 4, FL, 11.2 }, { 10.6, 29.4, FL, 11.4 } })
createWindow(GW, "Living_FrontWindow", "x", -24, -30, -8.5, FL, 14.8)
createDoor(GW, "MainEntrance_DoubleDoor", "x", -24, TE, -4, 4, FL, 11.2, 1, true, M.WoodPlanks, C.wood)
-- portón seccional del garaje
local gd = sub(Garage, "GarageDoor")
for i = 1, 5 do
	local y0 = FL + (i - 1) * (10.4 / 5)
	box(gd, "Panel" .. i, 10.6, 29.4, y0 + 0.05, y0 + 10.4 / 5 - 0.05, -24.15, -23.85, M.Metal, C.dark)
	box(gd, "Window" .. i, 12, 28, y0 + 0.8, y0 + 1.3, -24.2, -24.1, M.Glass, C.glass, { transp = 0.4 })
end
-- acabados de fachada principal
woodCladding(Exterior, "Front_WoodLeft", "x", -24, -1, -32.4, -30.2, FL, S1, TE)
woodCladding(Exterior, "Front_WoodRight", "x", -24, -1, 4.4, 7.9, FL, 13.2, TE)
box(Exterior, "Front_GaragePanelTop", 9.6, 30.4, 11.4, S1, -24.65, -24.4, M.Concrete, C.concrete)
box(Exterior, "Front_GarageFrameL", 9.6, 10.6, FL, 11.4, -24.65, -24.4, M.Concrete, C.concrete)
box(Exterior, "Front_GarageFrameR", 29.4, 30.4, FL, 11.4, -24.65, -24.4, M.Concrete, C.concrete)
box(Exterior, "Front_GarageSideStrip", 30.4, 32.4, FL, S1, -24.65, -24.4, M.Concrete, C.dark)
box(Exterior, "Front_BlackPanelEntrance", -8.5, -4, 11.2, S1, -24.65, -24.4, M.Metal, C.dark)

createWall(GW, "BackWall", "x", 24, -32.4, 32.4, FL, S1, TE, M.Concrete, WH,
	{ { -30, -16, 5, 13.5 }, { -12, 2, FL, 12.5 }, { 10.5, 15.5, 5.2, 12.5 }, { 25, 29, 8, 13 } })
createWindow(GW, "Office_BackWindow", "x", 24, -30, -16, 5, 13.5)
createSlider(GW, "Dining_Slider", "x", 24, -12, 2, FL, 12.5, 4)
createWindow(GW, "Kitchen_BackWindow", "x", 24, 10.5, 15.5, 5.2, 12.5)
createWindow(GW, "Pantry_BackWindow", "x", 24, 25, 29, 8, 13)
woodCladding(Exterior, "Back_WoodA", "x", 24, 1, 4.5, 10, FL, S1, TE)
woodCladding(Exterior, "Back_WoodB", "x", 24, 1, 16, 21.5, FL, S1, TE)
woodCladding(Exterior, "Back_WoodC", "x", 24, 1, 29.5, 32.4, FL, S1, TE)

createWall(GW, "WestWall", "z", -32, -24.4, 24.4, FL, S1, TE, M.Concrete, WH,
	{ { -22, -3.5, FL, 14.4 }, { 5, 20, 5, 13.5 } })
createWindow(GW, "Living_WestWindow", "z", -32, -22, -3.5, FL, 14.4)
createWindow(GW, "Office_WestWindow", "z", -32, 5, 20, 5, 13.5)

createWall(GW, "EastWall", "z", 32, -24.4, 24.4, FL, S1, TE, M.Concrete, C.concrete,
	{ { -20, -8, 10.5, 13.5 }, { 2.5, 7.5, 9, 13.5 } })
createWindow(GW, "Garage_EastWindow", "z", 32, -20, -8, 10.5, 13.5)
createWindow(GW, "GuestBath_EastWindow", "z", 32, 2.5, 7.5, 9, 13.5)

---------------------------------------------------------------------
-- MUROS INTERIORES: PLANTA BAJA
---------------------------------------------------------------------
local GI = sub(GroundFloor, "InteriorWalls")
local IW = C.warmWhite
createWall(GI, "Living_Hall_Wall", "z", -6, -24, 0, FL, S1, TI, M.SmoothPlastic, IW, { { -16, -6, FL, 11.2 } })
createArch(GI, "Living_Hall_Arch", "z", -6, TI, -16, -6, FL, 11.2)
createWall(GI, "Hall_Garage_Wall", "z", 8, -24, 0, FL, S1, TI, M.SmoothPlastic, C.concrete, { { -5.5, -1.5, FL, 10.2 } })
createDoor(Garage, "Garage_Door_Interior", "z", 8, TI, -5.5, -1.5, FL, 10.2, 1, false, M.Metal, C.dark)
createWall(GI, "Living_Office_Wall", "x", 0, -32, -14, FL, S1, TI, M.SmoothPlastic, IW, { { -18, -14.5, FL, 10.2 } })
createDoor(GI, "OfficeDoor", "x", 0, TI, -18, -14.5, FL, 10.2, 1, false, M.Wood, C.woodLight)
createWall(GI, "Hall_Dining_Wall", "x", 0, -6, 8, FL, S1, TI, M.SmoothPlastic, IW, { { -2, 5, FL, 11 } })
createArch(GI, "Hall_Dining_Arch", "x", 0, TI, -2, 5, FL, 11)
createWall(Garage, "Garage_Back_Wall", "x", 0, 8, 32, FL, S1, TI, M.SmoothPlastic, C.concrete)
createWall(GI, "Office_Dining_Wall", "z", -14, 0, 24, FL, S1, TI, M.SmoothPlastic, IW, { { 9, 13, FL, 10.5 } })
createArch(GI, "Office_Dining_Arch", "z", -14, TI, 9, 13, FL, 10.5)
createWall(GI, "Kitchen_East_Wall", "z", 22, 0, 24, FL, S1, TI, M.SmoothPlastic, IW, { { 2, 5, FL, 9.8 }, { 15, 18, FL, 9.8 } })
createDoor(GI, "GuestBathDoor", "z", 22, TI, 2, 5, FL, 9.8, -1, false, M.Wood, C.woodLight)
createDoor(GI, "PantryDoor", "z", 22, TI, 15, 18, FL, 9.8, -1, false, M.Wood, C.woodLight)
createWall(GI, "Bath_Pantry_Wall", "x", 10, 22, 32, FL, S1, TI, M.SmoothPlastic, IW)

-- vigas decorativas en el arco sala-comedor
box(GI, "LivingDining_Beam", -14, -6, 12.2, 13.4, -0.3, 0.3, M.Metal, C.black)

---------------------------------------------------------------------
-- ESCALERA FLOTANTE EN "U" (madera + estructura negra + vidrio)
---------------------------------------------------------------------
local function createStaircase()
local ST = sub(GroundFloor, "Staircase")
local rise = (F2 - G) / 20
for i = 1, 9 do
	local z0 = -21 + (i - 1) * 1.1
	local top = G + i * rise
	box(ST, "A_Block" .. i, 4.2, 7.7, FL, top - 0.35, z0, z0 + 1.1, M.Concrete, C.dark)
	box(ST, "A_Tread" .. i, 4.2, 7.7, top - 0.35, top, z0 - 0.1, z0 + 1.1, M.WoodPlanks, C.woodLight)
end
local top10 = G + 10 * rise
box(ST, "Landing_Block", 0.2, 7.7, FL, top10 - 0.35, -11.1, -6.1, M.Concrete, C.dark)
box(ST, "Landing_Wood", 0.2, 7.7, top10 - 0.35, top10, -11.1, -6.1, M.WoodPlanks, C.woodLight)
for i = 11, 19 do
	local z1 = -6.1 - (i - 11) * 1.1
	local top = G + i * rise
	box(ST, "B_Block" .. i, 0.2, 3.7, FL, top - 0.35, z1 - 1.1, z1, M.Concrete, C.dark)
	box(ST, "B_Tread" .. i, 0.2, 3.7, top - 0.35, top, z1 - 1.1, z1 + 0.1, M.WoodPlanks, C.woodLight)
end
slopedGlass(ST, "A_WestRail", 4.15, -21, G + rise, -11.1, G + 9 * rise)
slopedGlass(ST, "B_EastRail", 3.75, -6.1, G + 11 * rise, -16, G + 19 * rise)
slopedGlass(ST, "B_WestRail", 0.25, -6.1, G + 11 * rise, -16, G + 19 * rise)
createRail(ST, "Landing_WestRail", "z", 0.25, -11.1, -6.1, top10, 3.2)
createRail(ST, "Landing_SouthRail", "x", -6.15, 3.7, 7.7, top10, 3.2)
-- barandillas del vacío de la escalera (segundo piso)
local VR = sub(UpperFloor, "StairVoidRails")
createRail(VR, "Void_W1", "z", 3.7, -22.5, -16, F2, 3.4)
createRail(VR, "Void_N", "x", -22.5, 3.7, 8, F2, 3.4)
createRail(VR, "Void_W2", "z", 0.2, -16, -4.6, F2, 3.4)
createRail(VR, "Void_S", "x", -4.6, 0.2, 8, F2, 3.4)
-- iluminación integrada en peldaños
for i = 1, 9, 2 do
	local top = G + i * rise
	local s = box(ST, "A_StepLight" .. i, 7.0, 7.65, top - 0.5, top - 0.35, -21 + (i - 1) * 1.1, -21 + i * 1.1 - 0.2, M.Neon, C.warmLight, { collide = false, shadow = false })
	addLight(s, "PointLight", 0.35, 8, C.warmLight)
end

end
createStaircase()

---------------------------------------------------------------------
-- SEGUNDO PISO: MUROS EXTERIORES
---------------------------------------------------------------------
local UW = sub(UpperFloor, "ExteriorWalls")
createWall(UW, "Up_FrontWest", "x", -24, -32.4, -8, UY, S2, TE, M.Concrete, WH, { { -30, -10, F2, 28 } })
createSlider(UW, "Master_FrontSlider", "x", -24, -30, -10, F2, 28, 4)
createWall(UW, "Up_FrontHall", "x", -24, -8, 8, UY, HT, TE, M.Concrete, WH, { { -5.5, 5.5, F2, 31.2 } })
createWindow(UW, "Hall_FrontWindow", "x", -24, -5.5, 5.5, F2, 31.2)
woodCladding(Exterior, "UpFront_WoodA", "x", -24, -1, -32.4, -30.2, UY, S2, TE)
woodCladding(Exterior, "UpFront_WoodB", "x", -24, -1, -9.8, -8, UY, S2, TE)
woodCladding(Exterior, "UpFront_WoodC", "x", -24, -1, 5.8, 8, UY, HT, TE)
box(Exterior, "UpFront_BlackBand", -30, -10, 28, S2, -24.65, -24.4, M.Metal, C.dark)

createWall(UW, "Up_BackWest", "x", 24, -32.4, -8, UY, S2, TE, M.Concrete, WH, { { -28, -12, 20.9, 28 } })
createWindow(UW, "Bed2_BackWindow", "x", 24, -28, -12, 20.9, 28)
createWall(UW, "Up_BackHall", "x", 24, -8, 8, UY, HT, TE, M.Concrete, WH, { { -6, 6, F2, 31.3 } })
createWindow(UW, "Hall_BackWindow", "x", 24, -6, 6, F2, 31.3)
createWall(UW, "Up_BackEast", "x", 24, 8, 32.4, UY, S2E, TE, M.Concrete, WH, { { 10.5, 15.5, 20.9, 27 }, { 18, 30, F2, 27.4 } })
createWindow(UW, "Bed3_BackWindow", "x", 24, 10.5, 15.5, 20.9, 27)
createSlider(UW, "Bed3_BackSlider", "x", 24, 18, 30, F2, 27.4, 4)
woodCladding(Exterior, "UpBack_WoodA", "x", 24, 1, -32.4, -28.5, UY, S2, TE)
woodCladding(Exterior, "UpBack_WoodB", "x", 24, 1, -11.5, -8, UY, S2, TE)
woodCladding(Exterior, "UpBack_WoodC", "x", 24, 1, -8, -6.2, UY, HT, TE)
woodCladding(Exterior, "UpBack_WoodD", "x", 24, 1, 6.2, 8, UY, HT, TE)
woodCladding(Exterior, "UpBack_WoodE", "x", 24, 1, 8, 10.2, UY, S2E, TE)
woodCladding(Exterior, "UpBack_WoodF", "x", 24, 1, 30.2, 32.4, UY, S2E, TE)

createWall(UW, "Up_WestWall", "z", -32, -24.4, 24.4, UY, S2, TE, M.Concrete, WH, { { -22, -3, F2, 28 }, { 3, 8, 24, 28 }, { 15, 21, 21, 28 } })
createWindow(UW, "Master_WestWindow", "z", -32, -22, -3, F2, 28)
createWindow(UW, "Closet_WestWindow", "z", -32, 3, 8, 24, 28)
createWindow(UW, "Bed2_WestWindow", "z", -32, 15, 21, 21, 28)
createWall(UW, "Up_EastWall", "z", 32, -12.4, 24.4, UY, S2E, TE, M.Concrete, C.dark, { { 11, 21, 21, 27 } })
createWindow(UW, "Bed3_EastWindow", "z", 32, 11, 21, 21, 27)
createWall(UW, "Cinema_FrontWall", "x", -12, 8, 32.4, UY, S2E, TE, M.Concrete, WH, { { 16, 28, F2, 27.4 } })
createSlider(UW, "Cinema_TerraceSlider", "x", -12, 16, 28, F2, 27.4, 4)

---------------------------------------------------------------------
-- SEGUNDO PISO: MUROS INTERIORES
---------------------------------------------------------------------
local UI = sub(UpperFloor, "InteriorWalls")
createWall(UI, "Hall_West_Wall", "z", -8, -24.4, 24.4, UY, HT, 0.6, M.SmoothPlastic, IW, { { -22, -18.5, F2, 26.4 }, { 16, 19.5, F2, 26.4 } })
createDoor(UI, "MasterDoor", "z", -8, 0.6, -22, -18.5, F2, 26.4, 1, false, M.Wood, C.woodLight)
createDoor(UI, "Bed2Door", "z", -8, 0.6, 16, 19.5, F2, 26.4, 1, false, M.Wood, C.woodLight)
createWall(UI, "Hall_East_Wall_Low", "z", 8, -24.4, 24.4, UY, 30.5, 0.6, M.SmoothPlastic, IW, { { 0.5, 4.5, F2, 26.4 }, { 14, 17.5, F2, 26.4 } })
createWall(UI, "Hall_East_Wall_High", "z", 8, -24.4, 24.4, 30.5, HT, 0.6, M.SmoothPlastic, IW, { { -20, 20, 30.5, 31.7 } })
createDoor(UI, "CinemaDoor", "z", 8, 0.6, 0.5, 4.5, F2, 26.4, 1, false, M.Wood, C.dark)
createDoor(UI, "Bed3Door", "z", 8, 0.6, 14, 17.5, F2, 26.4, 1, false, M.Wood, C.woodLight)
createWindow(UI, "Hall_Clerestory", "z", 8, -20, 20, 30.5, 31.7, true)
createWall(UI, "Master_Closet_Wall", "x", 0, -32, -8, UY, S2, TI, M.SmoothPlastic, IW, { { -29.5, -25.5, F2, 26.4 }, { -17, -13.4, F2, 26.4 } })
createDoor(UI, "ClosetDoor", "x", 0, TI, -29.5, -25.5, F2, 26.4, -1, false, M.Wood, C.woodLight)
createDoor(UI, "MasterBathDoor", "x", 0, TI, -17, -13.4, F2, 26.4, -1, false, M.Wood, C.woodLight)
createWall(UI, "Closet_Bath_Wall", "z", -20, 0, 12, UY, S2, TI, M.SmoothPlastic, IW, { { 5, 8.5, F2, 26.4 } })
createArch(UI, "Closet_Bath_Arch", "z", -20, TI, 5, 8.5, F2, 26.4)
createWall(UI, "Bed2_Wall", "x", 12, -32, -8, UY, S2, TI, M.SmoothPlastic, IW)
createWall(UI, "Cinema_Bed3_Wall", "x", 8, 8, 32, UY, S2E, TI, M.SmoothPlastic, IW)

---------------------------------------------------------------------
-- BALCONES, TERRAZAS, CANOPY, COLUMNAS
---------------------------------------------------------------------
local BAL = sub(Exterior, "Balconies")
-- balcón de la suite principal (frente)
box(BAL, "MasterBalcony_Slab", -31, -9, S1, UY, -29, -24.4, M.Concrete, C.warmWhite)
box(BAL, "MasterBalcony_Deck", -31, -9, UY, F2, -29, -24.4, M.WoodPlanks, C.woodLight)
box(BAL, "MasterBalcony_Edge", -31, -9, S1 - 0.5, S1, -29, -28.4, M.Metal, C.black)
createRail(BAL, "MasterBalcony_RailFront", "x", -28.9, -31, -9, F2, 3.6)
createRail(BAL, "MasterBalcony_RailW", "z", -30.9, -29, -24.4, F2, 3.6)
createRail(BAL, "MasterBalcony_RailE", "z", -9.1, -29, -24.4, F2, 3.6)
box(BAL, "MasterBalcony_ColumnW", -31, -30.4, FL, S1 - 0.5, -29, -28.4, M.Metal, C.black)
box(BAL, "MasterBalcony_ColumnE", -9.6, -9, FL, S1 - 0.5, -29, -28.4, M.Metal, C.black)
-- terraza frontal sobre el garaje
box(BAL, "Terrace_Deck", 8, 32.4, UY, F2, -24.4, -12, M.WoodPlanks, C.wood)
createRail(BAL, "Terrace_RailFront", "x", -24.2, 8, 32.4, F2, 3.6)
createRail(BAL, "Terrace_RailEast", "z", 32.2, -24.4, -12.4, F2, 3.6)
-- balcón trasero del dormitorio 3
box(BAL, "RearBalcony_Slab", 17, 31, S1, UY, 24.4, 29.5, M.Concrete, C.warmWhite)
box(BAL, "RearBalcony_Deck", 17, 31, UY, F2, 24.4, 29.5, M.WoodPlanks, C.woodLight)
createRail(BAL, "RearBalcony_RailBack", "x", 29.4, 17, 31, F2, 3.6)
createRail(BAL, "RearBalcony_RailW", "z", 17.1, 24.4, 29.5, F2, 3.6)
createRail(BAL, "RearBalcony_RailE", "z", 30.9, 24.4, 29.5, F2, 3.6)
box(BAL, "RearBalcony_ColumnW", 17, 17.6, FL, S1, 28.9, 29.5, M.Metal, C.black)
box(BAL, "RearBalcony_ColumnE", 30.4, 31, FL, S1, 28.9, 29.5, M.Metal, C.black)
-- canopy de entrada y columnas "blade" negras
box(BAL, "Entrance_Canopy", -6, 8.4, 13.4, 14.4, -30, -24.4, M.Concrete, C.warmWhite)
box(BAL, "Entrance_CanopyEdge", -6, 8.4, 14.4, 14.7, -30, -29.7, M.Metal, C.black)
box(BAL, "Entrance_ColumnL", -5.9, -5.3, FL, 13.4, -29.8, -29.2, M.Metal, C.black)
box(BAL, "Entrance_ColumnR", 7.7, 8.3, FL, 13.4, -29.8, -29.2, M.Metal, C.black)
box(Exterior, "Blade_Column_A", 8.4, 10, 0, 33.8, -27, -24.4, M.Metal, C.black)
box(Exterior, "Blade_Column_B", -7.6, -6, 0, 33.8, -27, -24.4, M.Metal, C.black)
box(Exterior, "Blade_Column_Back", 8.4, 10, 0, 33.8, 24.4, 27, M.Metal, C.black)
box(Exterior, "Blade_Column_BackB", -7.6, -6, 0, 33.8, 24.4, 27, M.Metal, C.black)
for i = 1, 3 do
	downlight(Lighting, -4.5 + (i - 1) * 4.7, 13.4, -27.2, C.warmLight, 0.9, 15)
end

---------------------------------------------------------------------
-- TECHOS CON DIFERENTES ALTURAS
---------------------------------------------------------------------
local RF = sub(Exterior, "Roofs")
-- ala oeste
box(RF, "WestCeiling", -32.4, -8.4, S2, S2 + 0.3, -24.4, 24.4, M.SmoothPlastic, C.warmWhite)
box(RF, "WestRoof", -33.4, -9.6, S2 + 0.3, S2 + 1.3, -25.4, 25.4, M.Concrete, C.dark)
box(RF, "WestRoofFascia", -33.4, -9.6, S2 + 0.3, S2 + 0.5, -25.4, -25.1, M.Metal, C.black)
-- volumen central (más alto)
box(RF, "HallCeiling", -8.4, 8.4, HT, HT + 0.3, -24.4, 24.4, M.SmoothPlastic, C.warmWhite)
box(RF, "HallRoof", -9.6, 9.6, HT + 0.3, HT + 1.3, -26, 26, M.Concrete, C.dark)
box(RF, "HallRoofFascia", -9.6, 9.6, HT + 0.3, HT + 0.5, -26, -25.7, M.Metal, C.black)
-- ala este (más baja)
box(RF, "EastCeiling", 8.4, 32.4, S2E, S2E + 0.3, -12.4, 24.4, M.SmoothPlastic, C.warmWhite)
box(RF, "EastRoof", 9.6, 33.4, S2E + 0.3, S2E + 1.3, -14, 25.4, M.Concrete, C.dark)
box(RF, "EastRoofFascia", 9.6, 33.4, S2E + 0.3, S2E + 0.5, -14, -13.7, M.Metal, C.black)
-- parapeto decorativo (pérgola) sobre la terraza frontal
for i = 0, 5 do
	box(RF, "TerracePergolaBeam" .. i, 9 + i * 4.5, 9.4 + i * 4.5, 27.4, 27.8, -24.2, -12.4, M.Wood, C.wood)
end
for _, p in ipairs({ { 9, -24.2 }, { 31.8, -24.2 }, { 9, -12.7 }, { 31.8, -12.7 } }) do
	box(RF, "TerracePergolaPost", p[1] - 0.2, p[1] + 0.2, F2, 27.8, p[2] - 0.2, p[2] + 0.2, M.Metal, C.black)
end
box(RF, "TerracePergolaFrameA", 8.8, 32, 27.8, 28.1, -24.4, -24, M.Metal, C.black)
box(RF, "TerracePergolaFrameB", 8.8, 32, 27.8, 28.1, -12.9, -12.5, M.Metal, C.black)

---------------------------------------------------------------------
-- DETALLES ARQUITECTÓNICOS ADICIONALES (profundidad de fachada y cubiertas)
---------------------------------------------------------------------
-- bandas horizontales de losa que marcan los dos niveles
local BD = sub(Exterior, "SlabBands")
box(BD, "Band_Front", -32.75, 32.75, 15.9, 17.5, -24.75, -24.4, M.Concrete, C.dark)
box(BD, "Band_Back", -32.75, 32.75, 15.9, 17.5, 24.4, 24.75, M.Concrete, C.dark)
box(BD, "Band_West", -32.75, -32.4, 15.9, 17.5, -24.4, 24.4, M.Concrete, C.dark)
box(BD, "Band_East", 32.4, 32.75, 15.9, 17.5, -24.4, 24.4, M.Concrete, C.dark)
-- zócalo de piedra en la base de la fachada
box(BD, "Plinth_West", -32.7, -32.4, 0, 2.2, -24.7, 24.7, M.Slate, rgb(95, 92, 88))
box(BD, "Plinth_East", 32.4, 32.7, 0, 2.2, -24.7, 24.7, M.Slate, rgb(95, 92, 88))
box(BD, "Plinth_BackA", -32.4, -12.3, 0, 2.2, 24.4, 24.7, M.Slate, rgb(95, 92, 88))
box(BD, "Plinth_BackB", 2.3, 32.4, 0, 2.2, 24.4, 24.7, M.Slate, rgb(95, 92, 88))
-- escalones entre el comedor y la terraza de la piscina
box(BD, "Back_StepStone", -12.5, 2.5, 0, 0.8, 24.4, 25.8, M.Marble, C.stone)

-- pretiles (labios) en las cubiertas
local function roofLip(parent, name, x0, x1, z0, z1, y)
	box(parent, name .. "_F", x0, x1, y, y + 0.6, z0, z0 + 0.3, M.Metal, C.black)
	box(parent, name .. "_B", x0, x1, y, y + 0.6, z1 - 0.3, z1, M.Metal, C.black)
	box(parent, name .. "_W", x0, x0 + 0.3, y, y + 0.6, z0, z1, M.Metal, C.black)
	box(parent, name .. "_E", x1 - 0.3, x1, y, y + 0.6, z0, z1, M.Metal, C.black)
end
roofLip(RF, "WestRoofLip", -33.4, -9.6, -25.4, 25.4, S2 + 1.3)
roofLip(RF, "HallRoofLip", -9.6, 9.6, -26, 26, HT + 1.3)
roofLip(RF, "EastRoofLip", 9.6, 33.4, -14, 25.4, S2E + 1.3)

-- equipos y paneles solares sobre la cubierta este
local RE = sub(RF, "RoofEquipment")
local ry = S2E + 1.3
for i, x in ipairs({ 13, 18.5 }) do
	box(RE, "ACUnit" .. i, x, x + 3.6, ry, ry + 2.4, 18, 20.6, M.Metal, rgb(190, 192, 196))
	cyl(RE, "ACFan" .. i, x + 1.8, ry + 2.4, ry + 2.55, 19.3, 2.2, M.Metal, C.dark)
end
for row = 0, 1 do
	for i = 0, 3 do
		local x = 12.5 + i * 4.6
		local z = -4 + row * 4
		cfPart(RE, "SolarPanel", Vector3.new(4.2, 0.2, 2.8), CFrame.new(x + 2.1, ry + 1.0, z) * CFrame.Angles(math.rad(-18), 0, 0), M.Metal, rgb(28, 42, 78))
		box(RE, "SolarStandBack", x + 0.4, x + 3.8, ry, ry + 1.7, z + 1.1, z + 1.3, M.Metal, C.dark)
		box(RE, "SolarStandFront", x + 0.4, x + 3.8, ry, ry + 0.5, z - 1.3, z - 1.1, M.Metal, C.dark)
	end
end

---------------------------------------------------------------------
-- UTILIDADES DE INTERIOR
---------------------------------------------------------------------
local function createToilet(parent, cx, cz, rot, yb)
	local m = sub(parent, "Toilet")
	local b = L(m, cx, cz, rot, yb)
	b("Tank", -0.7, 0.7, 0.6, 3.0, -1.0, -0.2, M.SmoothPlastic, C.white)
	b("Bowl", -0.7, 0.7, 0, 1.6, -0.2, 1.5, M.SmoothPlastic, C.white)
	b("Seat", -0.65, 0.65, 1.6, 1.75, 0, 1.45, M.SmoothPlastic, C.lightGray)
	b("FlushButton", -0.2, 0.2, 3.0, 3.1, -0.7, -0.4, M.Metal, C.black)
end

local function createMirror(parent, name, x0, x1, y0, y1, z0, z1)
	local g = box(parent, name, x0, x1, y0, y1, z0, z1, M.Metal, rgb(225, 232, 238), { collide = false })
	g.Reflectance = 0.45
	return g
end

local function neonStrip(parent, name, x0, x1, y0, y1, z0, z1, col, bright, range)
	local s = box(parent, name, x0, x1, y0, y1, z0, z1, M.Neon, col or C.warmLight, { collide = false, shadow = false })
	addLight(s, "PointLight", bright or 0.6, range or 10, col or C.warmLight)
	return s
end

local sofaCol = rgb(176, 166, 150)
local sofaDark = rgb(92, 96, 104)

---------------------------------------------------------------------
-- PLANTA BAJA: SALA
---------------------------------------------------------------------
local FLiv = sub(Furniture, "Living")
box(Decorations, "Living_TVWoodPanel", -31.6, -18.4, G, G + 10, -0.6, -0.2, M.WoodPlanks, C.wood)
createTV(FLiv, -25.2, -0.6, 180, G + 3.2, 7.5)
createCabinet(FLiv, "Living_MediaConsole", -25.2, -0.6, 180, G, 7, 1.8, 1.6, C.dark, 3)
createBookshelf(FLiv, -30.4, -0.6, 180, G, 2.4, 9)
createBookshelf(FLiv, -19.9, -0.6, 180, G, 2.6, 9)
neonStrip(Lighting, "Living_TVLedStrip", -31, -18.8, G + 10, G + 10.2, -0.9, -0.5, C.warmLight, 0.5, 12)
createRug(FLiv, -24.5, -11.5, G, 14, 10, rgb(214, 205, 188))
createSofa(FLiv, -25, -16, 0, G, 12, sofaCol)
createSofa(FLiv, -29.9, -9, 90, G, 7, sofaCol)
createSofa(FLiv, -17.6, -8, 270, G, 3.6, sofaDark)
createSofa(FLiv, -17.6, -12.6, 270, G, 3.6, sofaDark)
createTable(FLiv, "Living_CoffeeTable", -25, -9.5, 0, G, 6, 3.5, 1.4, M.Marble, C.white, C.black)
createTable(FLiv, "Living_SideTable", -17.8, -16.4, 0, G, 2, 2, 2.2, M.Marble, C.white, C.black)
createTable(FLiv, "Living_SideTable2", -30.5, -19, 0, G, 1.6, 1.6, 2.0, M.Wood, C.woodLight, C.black)
createLamp(FLiv, -31, -22.6, G, 6)
createPlant(Decorations, -31, -2, G, 1.4)
createPlant(Decorations, -9.5, -22.6, G, 1.2)
createPainting(Decorations, -6.2, -20.3, 270, G + 5.5, 4, 4, 1)
for _, p in ipairs({ { -28, -18 }, { -20, -18 }, { -28, -6 }, { -20, -6 }, { -12, -12 } }) do
	downlight(Lighting, p[1], S1, p[2])
end

---------------------------------------------------------------------
-- PLANTA BAJA: COMEDOR
---------------------------------------------------------------------
local FDin = sub(Furniture, "Dining")
createRug(FDin, -5, 13, G, 15, 9, rgb(150, 150, 148))
createTable(FDin, "Dining_Table", -5, 13, 0, G, 12, 5, 2.8, M.Wood, C.wood, C.black)
for i = 1, 3 do
	local x = -5 - 3.6 + (i - 1) * 3.6
	createChair(FDin, x, 9.9, 0, G, C.beige)
	createChair(FDin, x, 16.1, 180, G, C.beige)
end
createChair(FDin, -12, 13, 90, G, C.beige)
createChair(FDin, 2, 13, 270, G, C.beige)
cyl(Decorations, "Dining_Vase", -5, G + 2.8, G + 3.8, 13, 0.8, M.SmoothPlastic, C.white)
ball(Decorations, "Dining_Flowers", -5, G + 4.4, 13, 1.4, M.Grass, C.greenLight)
cyl(Decorations, "Dining_CandleA", -7, G + 2.8, G + 3.4, 13, 0.3, M.SmoothPlastic, C.cream)
cyl(Decorations, "Dining_CandleB", -3, G + 2.8, G + 3.4, 13, 0.3, M.SmoothPlastic, C.cream)
for _, x in ipairs({ -9, -5, -1 }) do
	createPendant(FDin, x, 13, G + 11.4, S1, 2.2)
end
createCabinet(FDin, "Dining_Sideboard", -13.8, 19, 90, G, 6, 3, 1.8, C.wood, 4)
box(Decorations, "Dining_SideboardTop", -13.8, -11.8, G + 3, G + 3.2, 16, 22, M.Marble, C.white)
createPainting(Decorations, -13.8, 19, 90, G + 5, 5, 3.2, 4)
createPlant(Decorations, -13.1, 23, G, 1.2)
createPlant(Decorations, 3.1, 22.8, G, 1.2)
for _, p in ipairs({ { -9, 6 }, { -1, 6 }, { -9, 20 }, { -1, 20 } }) do
	downlight(Lighting, p[1], S1, p[2])
end

---------------------------------------------------------------------
-- PLANTA BAJA: COCINA
---------------------------------------------------------------------
local FKit = sub(Furniture, "Kitchen")
box(FKit, "Kitchen_Plinth", 5, 19.4, G, G + 0.4, 21.5, 23.5, M.Metal, C.black)
box(FKit, "Kitchen_LowerBody", 5, 19.4, G + 0.4, G + 3.2, 21.2, 23.6, M.SmoothPlastic, C.warmWhite)
for i = 0, 5 do
	local x0 = 5.1 + i * 2.4
	box(FKit, "Kitchen_Drawer" .. i, x0, x0 + 2.3, G + 0.5, G + 3.1, 21.1, 21.2, M.SmoothPlastic, (i % 2 == 0) and C.woodLight or C.lightGray)
	box(FKit, "Kitchen_DrawerPull" .. i, x0 + 0.5, x0 + 1.8, G + 2.7, G + 2.85, 21.0, 21.1, M.Metal, C.black)
end
box(FKit, "Kitchen_Countertop", 5, 19.4, G + 3.2, G + 3.5, 21.0, 23.6, M.Marble, C.white)
box(FKit, "Kitchen_Backsplash", 5, 19.4, G + 3.5, G + 5.6, 23.4, 23.6, M.Marble, C.stone)
box(FKit, "Kitchen_SinkBasin", 12.3, 14.7, G + 3.45, G + 3.55, 22, 23.1, M.Metal, rgb(170, 172, 176))
cyl(FKit, "Kitchen_FaucetPost", 13.5, G + 3.5, G + 4.9, 23.2, 0.25, M.Metal, C.black)
box(FKit, "Kitchen_FaucetSpout", 13.4, 13.6, G + 4.7, G + 4.9, 22.4, 23.2, M.Metal, C.black)
box(FKit, "Kitchen_Cooktop", 6, 9.4, G + 3.5, G + 3.62, 21.7, 23.2, M.Glass, C.black)
for i, p in ipairs({ { 6.9, 22.0 }, { 8.5, 22.0 }, { 6.9, 22.9 }, { 8.5, 22.9 } }) do
	cyl(FKit, "Kitchen_Burner" .. i, p[1], G + 3.62, G + 3.68, p[2], 0.8, M.Metal, C.dark)
end
box(FKit, "Kitchen_OvenPanel", 6, 9.4, G + 0.7, G + 2.7, 21.0, 21.1, M.Glass, C.black)
box(FKit, "Kitchen_OvenHandle", 6.2, 9.2, G + 2.5, G + 2.65, 20.9, 21.0, M.Metal, C.lightGray)
box(FKit, "Kitchen_Hood", 5.8, 9.6, G + 8.5, G + 10.6, 22.2, 23.6, M.Metal, C.dark)
box(FKit, "Kitchen_HoodChimney", 6.8, 8.6, G + 10.6, S1, 22.8, 23.6, M.Metal, C.dark)
box(FKit, "Kitchen_DishwasherPanel", 16, 18.8, G + 0.5, G + 3.1, 21.0, 21.1, M.Metal, rgb(170, 172, 176))
box(FKit, "Kitchen_Microwave", 16.2, 18.6, G + 3.5, G + 4.9, 22, 23.3, M.Metal, C.dark)
box(FKit, "Kitchen_MicrowaveGlass", 16.4, 17.8, G + 3.7, G + 4.7, 21.95, 22, M.Glass, rgb(20, 24, 30))
box(FKit, "Kitchen_UpperCabinets", 16, 19.4, G + 5.8, G + 10, 22.4, 23.6, M.SmoothPlastic, C.warmWhite)
box(FKit, "Kitchen_UpperDoorA", 16.05, 17.65, G + 5.9, G + 9.9, 22.3, 22.4, M.SmoothPlastic, C.woodLight)
box(FKit, "Kitchen_UpperDoorB", 17.75, 19.35, G + 5.9, G + 9.9, 22.3, 22.4, M.SmoothPlastic, C.woodLight)
neonStrip(Lighting, "Kitchen_UnderCabinetLight", 16.1, 19.3, G + 5.65, G + 5.8, 22.6, 23.3, C.neutralLight, 0.6, 9)
-- refrigerador
box(FKit, "Kitchen_Fridge", 19.6, 21.8, G, G + 7.2, 20.2, 23.6, M.Metal, rgb(192, 194, 198))
box(FKit, "Kitchen_FridgeSplit", 19.6, 21.8, G + 2.4, G + 2.5, 20.1, 20.2, M.Metal, C.black)
box(FKit, "Kitchen_FridgeHandleA", 19.8, 19.95, G + 3.0, G + 6.2, 20.0, 20.2, M.Metal, C.black)
box(FKit, "Kitchen_FridgeHandleB", 19.8, 19.95, G + 0.6, G + 1.8, 20.0, 20.2, M.Metal, C.black)
-- isla central con barra
box(FKit, "Island_Body", 8, 17, G, G + 3.2, 10, 14.5, M.SmoothPlastic, C.dark)
box(FKit, "Island_WoodEndW", 7.9, 8.2, G, G + 3.5, 9.9, 14.6, M.WoodPlanks, C.wood)
box(FKit, "Island_WoodEndE", 16.8, 17.1, G, G + 3.5, 9.9, 14.6, M.WoodPlanks, C.wood)
box(FKit, "Island_Top", 7.8, 17.2, G + 3.2, G + 3.5, 9.8, 15.2, M.Marble, C.white)
box(FKit, "Island_BarSupportA", 9, 9.4, G, G + 3.2, 14.5, 15.0, M.Metal, C.black)
box(FKit, "Island_BarSupportB", 15.6, 16, G, G + 3.2, 14.5, 15.0, M.Metal, C.black)
for i = 0, 3 do
	createStool(FKit, 9.5 + i * 2.1, 16.3, G)
end
cyl(Decorations, "Island_FruitBowl", 10.5, G + 3.5, G + 3.9, 12.2, 1.8, M.SmoothPlastic, C.beige)
ball(Decorations, "Fruit_Red", 10.2, G + 4.1, 12.1, 0.6, M.SmoothPlastic, rgb(190, 45, 40))
ball(Decorations, "Fruit_Yellow", 10.8, G + 4.1, 12.3, 0.6, M.SmoothPlastic, rgb(230, 200, 70))
ball(Decorations, "Fruit_Green", 10.5, G + 4.3, 12.6, 0.6, M.SmoothPlastic, C.greenLight)
createPlant(Decorations, 14.8, 12.2, G + 3.5, 0.45)
createPendant(FKit, 10.5, 12.2, G + 10.4, S1, 1.6)
createPendant(FKit, 14.5, 12.2, G + 10.4, S1, 1.6)
createPlant(Decorations, 4.9, 23, G, 1.1)
for _, p in ipairs({ { 8, 5 }, { 14, 5 }, { 20, 5 }, { 11, 18 }, { 17, 18 } }) do
	downlight(Lighting, p[1], S1, p[2], C.neutralLight)
end

---------------------------------------------------------------------
-- PLANTA BAJA: BAÑO DE INVITADOS Y DESPENSA
---------------------------------------------------------------------
local FBath = sub(Furniture, "GuestBath")
box(GF, "GuestBath_StoneWall", 22.4, 31.6, G, G + 10, 9.5, 9.8, M.Slate, rgb(130, 125, 120))
createCabinet(FBath, "GuestBath_Vanity", 27, 9.5, 180, G, 5, 3, 2, C.wood, 2)
box(FBath, "GuestBath_VanityTop", 24.4, 29.6, G + 3, G + 3.3, 7.3, 9.5, M.Marble, C.white)
cyl(FBath, "GuestBath_Sink", 27, G + 3.3, G + 3.7, 8.4, 1.8, M.SmoothPlastic, C.white)
cyl(FBath, "GuestBath_Faucet", 27, G + 3.3, G + 4.6, 9.2, 0.22, M.Metal, C.black)
createMirror(FBath, "GuestBath_Mirror", 24.8, 29.2, G + 5.2, G + 9, 9.4, 9.5)
neonStrip(Lighting, "GuestBath_MirrorLight", 24.8, 29.2, G + 9.1, G + 9.3, 9.3, 9.5, C.warmLight, 0.6, 9)
createToilet(FBath, 30.8, 5, 270, G)
box(FBath, "GuestBath_TowelRail", 24, 27, G + 4.5, G + 4.7, 0.2, 0.5, M.Metal, C.black)
box(FBath, "GuestBath_Towel", 24.5, 26, G + 2.5, G + 4.5, 0.5, 0.7, M.Fabric, C.beige)
createPlant(Decorations, 23.5, 1.6, G, 0.8)
downlight(Lighting, 27, S1, 5, C.neutralLight)

local FPan = sub(Furniture, "Pantry")
createBookshelf(FPan, 31.6, 17, 270, G, 12, 8)
box(FPan, "Washer", 23, 25.6, G, G + 3.3, 21.6, 23.6, M.SmoothPlastic, C.white)
box(FPan, "WasherDoor", 23.5, 25.1, G + 0.8, G + 2.4, 21.5, 21.6, M.Glass, rgb(40, 50, 60))
box(FPan, "Dryer", 26, 28.6, G, G + 3.3, 21.6, 23.6, M.SmoothPlastic, C.white)
box(FPan, "DryerDoor", 26.5, 28.1, G + 0.8, G + 2.4, 21.5, 21.6, M.Glass, rgb(40, 50, 60))
box(FPan, "LaundryCounter", 22.4, 28.8, G + 3.3, G + 3.6, 21.4, 23.6, M.Wood, C.woodLight)
downlight(Lighting, 27, S1, 17, C.neutralLight)

---------------------------------------------------------------------
-- PLANTA BAJA: ENTRADA PRINCIPAL (HALL)
---------------------------------------------------------------------
local FHall = sub(Furniture, "EntranceHall")
createCabinet(FHall, "Hall_Console", -5.8, -19.5, 90, G, 3.5, 2.8, 1.2, C.woodLight, 2)
cyl(Decorations, "Hall_Vase", -5.2, G + 2.8, G + 4.2, -19.5, 0.8, M.SmoothPlastic, C.white)
ball(Decorations, "Hall_VaseLeaves", -5.2, G + 5, -19.5, 1.4, M.Grass, C.greenLight)
createPainting(Decorations, -5.8, -19.5, 90, G + 5.5, 3.8, 3.5, 2)
createPlant(Decorations, -4.6, -22.8, G, 1.0)
createPlant(Decorations, -4.6, -16, G, 1.0)
for i, p in ipairs({ { -3.6, -10.5, 9.5 }, { -2.5, -10.5, 8.2 }, { -1.4, -10.5, 9.0 } }) do
	createPendant(FHall, p[1], p[2], G + p[3], S1, 1.4)
end
for _, x in ipairs({ -4.9, 4.9 }) do
	local s = box(FHall, "Entrance_Sconce", x - 0.2, x + 0.2, G + 6.8, G + 8, -23.7, -23.4, M.Neon, C.warmLight, { collide = false })
	addLight(s, "PointLight", 0.7, 12, C.warmLight)
end
for _, p in ipairs({ { -3, -20 }, { -3, -4 }, { 2, -3 } }) do
	downlight(Lighting, p[1], S1, p[2])
end

---------------------------------------------------------------------
-- PLANTA BAJA: OFICINA
---------------------------------------------------------------------
local FOff = sub(Furniture, "Office")
createRug(FOff, -22, 14, G, 10, 8, rgb(88, 96, 110))
createDesk(FOff, -22, 20.6, 0, G, 8)
createBookshelf(FOff, -25.25, 0.2, 0, G, 11.5, 9)
createBookshelf(FOff, -14.2, 17.5, 270, G, 8, 8)
createSofa(FOff, -29.9, 9, 90, G, 4.4, sofaDark)
createLamp(FOff, -15.5, 5, G, 6)
createPlant(Decorations, -15.5, 22.8, G, 1.2)
createPlant(Decorations, -31, 22.8, G, 1.2)
createPainting(Decorations, -14.2, 5.5, 270, G + 5, 4, 3, 5)
for _, p in ipairs({ { -26, 6 }, { -20, 6 }, { -26, 18 }, { -20, 18 } }) do
	downlight(Lighting, p[1], S1, p[2], C.neutralLight)
end

---------------------------------------------------------------------
-- GARAJE
---------------------------------------------------------------------
for _, z in ipairs({ -18, -8 }) do
	box(Garage, "Garage_Pillar", 19.6, 20.4, FL, S1, z - 0.4, z + 0.4, M.Metal, C.dark)
end
createCabinet(Garage, "Garage_StorageCabinetA", 31.6, -16, 270, G, 12, 7, 1.8, rgb(70, 73, 78), 5)
createCabinet(Garage, "Garage_StorageCabinetB", 31.6, -5, 270, G, 6, 7, 1.8, rgb(70, 73, 78), 3)
createBookshelf(Garage, 20, -0.2, 180, G, 14, 8)
box(Garage, "Garage_Pegboard", 8.2, 8.35, G + 4, G + 9, -22, -9, M.Wood, C.woodLight)
for i = 1, 6 do
	local z = -21 + (i - 1) * 2.2
	box(Garage, "Garage_Tool" .. i, 8.35, 8.6, G + 5 + (i % 3) * 1.1, G + 6.8 + (i % 3) * 1.1, z, z + 0.35, M.Metal, (i % 2 == 0) and C.rust or C.black)
end
box(Garage, "Garage_EVCharger", 31.2, 31.6, G + 4, G + 6.5, -23, -22, M.SmoothPlastic, C.white)
for _, z in ipairs({ -19, -8 }) do
	for _, x0 in ipairs({ 11, 21 }) do
		neonStrip(Lighting, "Garage_StripLight", x0, x0 + 8, S1 - 0.2, S1, z - 0.2, z + 0.2, C.neutralLight, 0.9, 16)
	end
end

---------------------------------------------------------------------
-- SEGUNDO PISO: SUITE PRINCIPAL
---------------------------------------------------------------------
local FMas = sub(Furniture, "MasterSuite")
local Y = F2
box(Decorations, "Master_WoodHeadWall", -31.6, -31.4, Y, Y + 10, -18, -6, M.WoodPlanks, C.wood)
createRug(FMas, -24.5, -12, Y + 0.08, 13, 11, C.cream)
createBed(FMas, -31.2, -12, 90, Y, 6.5, rgb(200, 196, 188), C.cream)
createNightstand(FMas, -30.6, -17.7, 90, Y)
createNightstand(FMas, -30.6, -6.3, 90, Y)
box(FMas, "Master_BenchSeat", -23.3, -21.5, Y + 1.5, Y + 2.1, -14.8, -9.2, M.Fabric, C.navy)
for _, p in ipairs({ { -23.2, -14.7 }, { -21.7, -14.7 }, { -23.2, -9.4 }, { -21.7, -9.4 } }) do
	box(FMas, "Master_BenchLeg", p[1], p[1] + 0.2, Y, Y + 1.5, p[2], p[2] + 0.2, M.Metal, C.black)
end
createTV(FMas, -8.4, -12, 270, Y + 3.2, 7)
createCabinet(FMas, "Master_MediaConsole", -8.3, -12, 270, Y, 7, 1.8, 1.6, C.wood, 3)
createCabinet(FMas, "Master_Dresser", -21, -0.2, 180, Y, 5, 3, 1.8, C.woodLight, 3)
createMirror(Decorations, "Master_DresserMirror", -23.5, -18.5, Y + 4.5, Y + 8.5, -0.3, -0.2)
createSofa(FMas, -12.5, -21, 180, Y, 3.6, sofaCol)
createTable(FMas, "Master_SideTable", -15.8, -21.5, 0, Y, 1.8, 1.8, 2, M.Wood, C.woodLight, C.black)
createLamp(FMas, -9, -3, Y, 6)
createPlant(Decorations, -9.5, -4.5, Y, 1.2)
createPlant(Decorations, -31, -22.5, Y, 1.3)
for _, p in ipairs({ { -28, -18 }, { -20, -18 }, { -14, -6 }, { -26, -6 }, { -18, -12 } }) do
	downlight(Lighting, p[1], S2, p[2])
end
-- mobiliario del balcón principal
createTable(FMas, "MasterBalcony_Table", -20, -27, 0, Y, 2.6, 2.6, 2.4, M.Metal, C.dark, C.black)
createChair(FMas, -22.8, -27, 90, Y, C.beige)
createChair(FMas, -17.2, -27, 270, Y, C.beige)
local lan = cyl(Decorations, "MasterBalcony_Lantern", -20, Y + 2.4, Y + 3.2, -27, 0.7, M.Neon, C.warmLight, { collide = false })
addLight(lan, "PointLight", 0.6, 12, C.warmLight)
createPlant(Decorations, -30, -28, Y, 1.2)
createPlant(Decorations, -10, -28, Y, 1.2)

-- vestidor
local FClo = sub(Furniture, "WalkInCloset")
createWardrobe(FClo, -31.6, 6, 90, Y, 10, 6.5, C.woodLight)
do
	local rack = {
		{ -4, -3.8, 0, 8.6, 0, 2.2, M.Wood, C.woodLight },
		{ 3.8, 4, 0, 8.6, 0, 2.2, M.Wood, C.woodLight },
		{ -4, 4, 8.3, 8.6, 0, 2.2, M.Wood, C.woodLight },
		{ -4, 4, 0.3, 0.5, 0, 2.2, M.Wood, C.woodLight },
		{ -4, 4, 3.4, 3.6, 0, 2.2, M.Wood, C.woodLight },
		{ -4, 4, 6.9, 7.1, 1.0, 1.2, M.Metal, C.black },
		{ -4, 4, 5.2, 5.4, 1.0, 1.2, M.Metal, C.black },
		{ -4, 4, 0, 8.6, 0, 0.15, M.Wood, C.wood },
	}
	local pal = { C.navy, C.cream, C.rust, C.dark, C.beige, C.green, C.mustard, C.white }
	for i = 1, 8 do
		local x0 = -3.6 + (i - 1) * 0.9
		table.insert(rack, { x0, x0 + 0.5, 3.9, 6.9, 0.9, 1.3, M.Fabric, pal[i] })
		table.insert(rack, { x0, x0 + 0.5, 2.3, 5.2, 0.9, 1.3, M.Fabric, pal[(i + 3) % 8 + 1] })
	end
	for i = 1, 4 do
		local x0 = -3.5 + (i - 1) * 1.8
		table.insert(rack, { x0, x0 + 1.2, 0.5, 0.9, 0.3, 1.8, M.Fabric, pal[i] })
		table.insert(rack, { x0, x0 + 1.2, 3.6, 4.0, 0.3, 1.8, M.Fabric, pal[i + 2] })
	end
	createFurniture(FClo, "Closet_HangingRack", -24.9, 11.8, 180, Y, rack)
end
-- ropa colgada en el armario oeste (visible a través de puertas con vidrio)
for i = 1, 4 do
	box(FClo, "Closet_ShelfClothes" .. i, -29.4, -29.3, Y + 4.0, Y + 6.2, 1.2 + (i - 1) * 2.5, 3.0 + (i - 1) * 2.5, M.Fabric, ({ C.navy, C.cream, C.rust, C.dark })[i], { collide = false })
end
createCabinet(FClo, "Closet_Island", -25, 3.8, 0, Y, 4.5, 2.8, 2.4, C.wood, 3)
box(FClo, "Closet_IslandTop", -27.4, -22.6, Y + 2.8, Y + 3.0, 3.7, 6.3, M.Marble, C.white)
createMirror(Decorations, "Closet_Mirror", -24.8, -21.2, Y + 3.4, Y + 9, 0.2, 0.3)
createCabinet(FClo, "Closet_ShoeRack", -22.2, 0.2, 0, Y, 2.6, 3, 1.2, C.wood, 2)
downlight(Lighting, -26, S2, 5, C.neutralLight)
downlight(Lighting, -22, S2, 8, C.neutralLight)
neonStrip(Lighting, "Closet_LightStrip", -31, -26, S2 - 0.2, S2, 8, 8.3, C.neutralLight, 0.7, 10)

-- baño principal
local FMB = sub(Furniture, "MasterBath")
box(UpperFloor, "MasterBath_StoneWall", -19.8, -14.5, Y, Y + 9, 11.6, 11.8, M.Slate, rgb(110, 106, 102))
createCabinet(FMB, "MasterBath_DoubleVanity", -8.3, 3.8, 270, Y, 5.5, 3, 2.2, C.wood, 2)
box(FMB, "MasterBath_VanityTop", -10.8, -8.3, Y + 3, Y + 3.3, 0.95, 6.65, M.Marble, C.white)
for i, z in ipairs({ 2.4, 5.2 }) do
	cyl(FMB, "MasterBath_Sink" .. i, -9.6, Y + 3.3, Y + 3.7, z, 1.7, M.SmoothPlastic, C.white)
	cyl(FMB, "MasterBath_Faucet" .. i, -8.8, Y + 3.3, Y + 4.7, z, 0.22, M.Metal, C.black)
	createMirror(FMB, "MasterBath_Mirror" .. i, -8.45, -8.3, Y + 4.3, Y + 9, z - 1.1, z + 1.1)
end
neonStrip(Lighting, "MasterBath_MirrorLight", -8.5, -8.3, Y + 9.1, Y + 9.3, 1.2, 6.2, C.warmLight, 0.6, 10)
-- bañera independiente
box(FMB, "Tub_Base", -18.6, -15.4, Y + 0.3, Y + 2.2, 5.25, 11.75, M.SmoothPlastic, C.white)
box(FMB, "Tub_Inside", -18.2, -15.8, Y + 2.2, Y + 2.3, 5.65, 11.35, M.SmoothPlastic, rgb(235, 240, 245))
box(FMB, "Tub_FootA", -18.4, -17.8, Y, Y + 0.3, 5.5, 6.1, M.Metal, C.black)
box(FMB, "Tub_FootB", -16.2, -15.6, Y, Y + 0.3, 10.9, 11.5, M.Metal, C.black)
cyl(FMB, "Tub_Faucet", -17, Y + 2.2, Y + 5.2, 5.5, 0.25, M.Metal, C.black)
-- ducha
createFloor(FMB, "Shower_Floor", -13, -8.3, 7.5, 11.8, Y + 0.08, Y + 0.2, M.Slate, rgb(90, 90, 92))
local sg = box(FMB, "Shower_GlassW", -13.06, -12.94, Y + 0.2, Y + 9, 7.5, 11.8, M.Glass, C.glass, { transp = 0.6 })
box(FMB, "Shower_GlassS", -13, -10.5, Y + 0.2, Y + 9, 7.44, 7.56, M.Glass, C.glass, { transp = 0.6 })
box(FMB, "Shower_FrameTop", -13.1, -10.4, Y + 9, Y + 9.2, 7.4, 7.6, M.Metal, C.black)
cyl(FMB, "Shower_Pipe", -8.6, Y + 6.5, Y + 9.2, 9.6, 0.2, M.Metal, C.black)
box(FMB, "Shower_Head", -9.8, -8.6, Y + 9.1, Y + 9.3, 9.4, 9.8, M.Metal, C.black)
box(FMB, "Shower_Niche", -12, -10, Y + 4.5, Y + 6.5, 11.7, 11.8, M.Marble, C.beige)
neonStrip(Lighting, "Shower_NicheLight", -12, -10, Y + 4.35, Y + 4.5, 11.6, 11.75, C.warmLight, 0.5, 8)
createToilet(FMB, -11.5, 1.3, 0, Y)
box(FMB, "MasterBath_TowelRail", -19.8, -19.5, Y + 4.5, Y + 4.7, 2, 5, M.Metal, C.black)
box(FMB, "MasterBath_Towel", -19.8, -19.6, Y + 2.2, Y + 4.5, 2.4, 4.6, M.Fabric, C.beige)
createPlant(Decorations, -19, 1.6, Y, 0.9)
for _, p in ipairs({ { -16, 3 }, { -14, 9 }, { -10, 9 } }) do
	downlight(Lighting, p[1], S2, p[2], C.warmLight, 0.6, 12)
end

-- dormitorio secundario 1
local FB2 = sub(Furniture, "Bedroom2")
createRug(FB2, -24, 18, Y + 0.08, 10, 8, rgb(140, 152, 165))
createBed(FB2, -31.2, 18, 90, Y, 5.2, C.white, rgb(110, 128, 150))
createNightstand(FB2, -30.6, 13.2, 90, Y)
createNightstand(FB2, -30.6, 22.5, 90, Y)
createWardrobe(FB2, -17, 12.2, 0, Y, 9, 9, C.woodLight)
createDesk(FB2, -16, 20.6, 0, Y, 7)
createLamp(FB2, -9.5, 13.8, Y, 5.5)
createPlant(Decorations, -9.5, 22.8, Y, 1.2)
for _, p in ipairs({ { -24, 15 }, { -24, 21 }, { -14, 18 } }) do
	downlight(Lighting, p[1], S2, p[2])
end

-- dormitorio secundario 2
local FB3 = sub(Furniture, "Bedroom3")
createRug(FB3, 24.5, 16, Y + 0.08, 12, 9, rgb(170, 160, 148))
createBed(FB3, 31.2, 16, 270, Y, 6.5, rgb(168, 160, 150), rgb(80, 82, 88))
createNightstand(FB3, 30.6, 11, 270, Y)
createNightstand(FB3, 30.6, 21, 270, Y)
createWardrobe(FB3, 18, 8.2, 0, Y, 10, 9, C.wood)
createDesk(FB3, 13, 20.6, 0, Y, 5)
createSofa(FB3, 27, 10.2, 0, Y, 3.6, sofaDark)
createLamp(FB3, 30.5, 9.4, Y, 5.5)
createPlant(Decorations, 9.2, 22.8, Y, 1.2)
createPlant(Decorations, 31, 22.8, Y, 1.0)
for _, p in ipairs({ { 14, 12 }, { 14, 18 }, { 24, 12 }, { 24, 20 }, { 20, 10 } }) do
	downlight(Lighting, p[1], S2E, p[2])
end
-- mobiliario del balcón trasero
createTable(FB3, "RearBalcony_Table", 24, 27, 0, Y, 2.4, 2.4, 2.4, M.Metal, C.dark, C.black)
createChair(FB3, 21.2, 27, 90, Y, C.beige)
createChair(FB3, 26.8, 27, 270, Y, C.beige)
createPlant(Decorations, 18.2, 28.6, Y, 1.1)
createPlant(Decorations, 29.8, 28.6, Y, 1.1)

---------------------------------------------------------------------
-- SEGUNDO PISO: SALA DE CINE Y TERRAZA
---------------------------------------------------------------------
local FCin = sub(Furniture, "Cinema")
box(FCin, "Cinema_ScreenFrame", 31.2, 31.6, Y + 2.8, Y + 11.2, -9.2, 5.2, M.Metal, C.black)
box(FCin, "Cinema_Screen", 31.1, 31.2, Y + 3, Y + 11, -9, 5, M.SmoothPlastic, rgb(28, 32, 40))
createCabinet(FCin, "Cinema_MediaConsole", 31.6, -2, 270, Y, 14, 1.6, 1.6, C.dark, 5)
for i, z in ipairs({ -10.4, 6.4 }) do
	box(FCin, "Cinema_SpeakerStand" .. i, 30.6, 31.2, Y, Y + 1.2, z - 0.4, z + 0.4, M.Metal, C.black)
	box(FCin, "Cinema_Speaker" .. i, 30.4, 31.4, Y + 1.2, Y + 5.2, z - 0.55, z + 0.55, M.SmoothPlastic, C.black)
	box(FCin, "Cinema_SpeakerGrille" .. i, 30.3, 30.4, Y + 1.5, Y + 4.9, z - 0.4, z + 0.4, M.Fabric, C.dark)
end
createSofa(FCin, 19.5, -2, 90, Y, 12, sofaDark)
createSofa(FCin, 14, -2.5, 90, Y, 11, sofaDark)
createTable(FCin, "Cinema_Table", 24.5, -2, 0, Y, 2.4, 3.6, 1.4, M.Wood, C.wood, C.black)
createTable(FCin, "Cinema_SideTableA", 19.5, 5.6, 0, Y, 1.8, 1.8, 2, M.Wood, C.wood, C.black)
createTable(FCin, "Cinema_SideTableB", 19.5, -9.6, 0, Y, 1.8, 1.8, 2, M.Wood, C.wood, C.black)
createBookshelf(FCin, 20, 7.8, 180, Y, 14, 8)
createPlant(Decorations, 9.6, 6.8, Y, 1.0)
for _, z in ipairs({ -11.5, 7.5 }) do
	neonStrip(Lighting, "Cinema_LedCove", 8.6, 31.4, S2E - 0.2, S2E, z - 0.15, z + 0.15, rgb(255, 170, 90), 0.5, 14)
end
downlight(Lighting, 13, S2E, -2, rgb(255, 190, 120), 0.4, 10)
downlight(Lighting, 22, S2E, -2, rgb(255, 190, 120), 0.4, 10)

local FTer = sub(Furniture, "Terrace")
createTable(FTer, "Terrace_Table", 24, -18, 0, Y, 3, 3, 2.6, M.Metal, C.dark, C.black)
createChair(FTer, 24, -15.6, 180, Y, C.beige)
createChair(FTer, 24, -20.4, 0, Y, C.beige)
createChair(FTer, 21, -18, 90, Y, C.beige)
createChair(FTer, 27, -18, 270, Y, C.beige)
createSofa(FTer, 13.5, -14.5, 180, Y, 7, sofaCol)
createPlant(Decorations, 10.2, -22.6, Y, 1.3)
createPlant(Decorations, 31, -22.6, Y, 1.3)
createPlant(Decorations, 31, -13.6, Y, 1.3)
for i, x in ipairs({ 13, 22, 30 }) do
	local l = box(Lighting, "Terrace_PergolaLight" .. i, x - 0.4, x + 0.4, 27.6, 27.8, -18.2, -17.8, M.Neon, C.warmLight, { collide = false })
	addLight(l, "PointLight", 0.6, 14, C.warmLight)
end

---------------------------------------------------------------------
-- SEGUNDO PISO: PASILLO / DISTRIBUIDOR
---------------------------------------------------------------------
local FUH = sub(Furniture, "UpperHall")
createRug(FUH, -4, 8, Y + 0.08, 4, 14, rgb(176, 166, 150))
createPainting(Decorations, -7.7, 6.5, 90, Y + 5, 5, 3.6, 3)
createPlant(Decorations, -6.6, -22, Y, 1.3)
createPlant(Decorations, -6.6, 22.4, Y, 1.3)
createPlant(Decorations, 6.6, 22.4, Y, 1.3)
createLamp(FUH, 6.6, 10, Y, 5.5)
for i, p in ipairs({ { 5.9, -19, 22.5 }, { 5.9, -15, 24.5 }, { 5.9, -11, 23.2 } }) do
	createPendant(FUH, p[1], p[2], Y + p[3] - F2, HT, 1.6)
end
for _, p in ipairs({ { -4, -18 }, { -4, -6 }, { -4, 6 }, { -4, 18 }, { 3, 10 }, { 3, 20 } }) do
	downlight(Lighting, p[1], HT, p[2], C.warmLight, 0.8, 16)
end

---------------------------------------------------------------------
-- ZÓCALOS Y MOLDURAS DE TECHO
---------------------------------------------------------------------
local TR = sub(Decorations, "Trim")
createRoom(TR, "Living_Trim", -31.6, -6.2, -23.6, -0.2, G, S1, { front = true, back = { { -18, -14.5 }, { -14, -6.2 } }, west = { { -22, -3.5 } }, east = { { -16, -6 } } })
createRoom(TR, "Hall_Trim", -5.8, 7.8, -23.6, -0.2, G, S1, { front = { { -4, 4 } }, back = { { -2, 5 } }, west = { { -16, -6 } }, east = { { -5.5, -1.5 } } })
createRoom(TR, "Office_Trim", -31.6, -14.2, 0.2, 23.6, G, S1, { front = { { -18, -14.5 } }, east = { { 9, 13 } } })
createRoom(TR, "GuestBath_Trim", 22.2, 31.6, 0.2, 9.8, G, S1, { west = { { 2, 5 } } })
createRoom(TR, "Pantry_Trim", 22.2, 31.6, 10.2, 23.6, G, S1, { west = { { 15, 18 } } })
createRoom(TR, "Master_Trim", -31.6, -8.3, -23.6, -0.2, Y, S2, { front = { { -30, -10 } }, back = { { -29.5, -25.5 }, { -17, -13.4 } }, east = { { -22, -18.5 } } })
createRoom(TR, "Closet_Trim", -31.6, -20.2, 0.2, 11.8, Y, S2, { front = { { -29.5, -25.5 } }, east = { { 5, 8.5 } } })
createRoom(TR, "MasterBath_Trim", -19.8, -8.3, 0.2, 11.8, Y, S2, { front = { { -17, -13.4 } }, west = { { 5, 8.5 } } })
createRoom(TR, "Bed2_Trim", -31.6, -8.3, 12.2, 23.6, Y, S2, { east = { { 16, 19.5 } } })
createRoom(TR, "Bed3_Trim", 8.3, 31.6, 8.2, 23.6, Y, S2E, { west = { { 14, 17.5 } }, back = { { 18, 30 } } })
createRoom(TR, "Cinema_Trim", 8.3, 31.6, -11.8, 7.8, Y, S2E, { front = { { 16, 28 } }, west = { { 0.5, 4.5 } } })

---------------------------------------------------------------------
-- VEGETACIÓN Y MOBILIARIO EXTERIOR
---------------------------------------------------------------------
local function createTree(parent, x, z, h, kind)
	local m = sub(parent, "Tree")
	local trunkH = h * 0.5
	cyl(m, "Trunk", x, 0, trunkH, z, math.max(0.9, h * 0.07), M.Wood, rgb(98, 70, 46))
	local d = h * 0.55
	ball(m, "CanopyMain", x, trunkH + d * 0.35, z, d, M.Grass, (kind == 1) and C.greenLight or C.green)
	ball(m, "CanopyA", x + d * 0.28, trunkH + d * 0.15, z + d * 0.1, d * 0.7, M.Grass, C.greenDark)
	ball(m, "CanopyB", x - d * 0.25, trunkH + d * 0.55, z - d * 0.12, d * 0.65, M.Grass, C.greenLight)
	return m
end

local function createPalm(parent, x, z, h)
	local m = sub(parent, "Palm")
	local segs = 6
	for i = 1, segs do
		local y0 = (i - 1) * h / segs
		local lean = (i / segs) * 0.5
		cyl(m, "Trunk" .. i, x + lean, y0, y0 + h / segs + 0.05, z, 1.3 - i * 0.1, M.Wood, (i % 2 == 0) and rgb(120, 92, 64) or rgb(104, 78, 54))
	end
	local top = Vector3.new(x + 0.5, h, z)
	for k = 0, 7 do
		local yaw = math.rad(k * 45)
		local cf = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(22 + (k % 2) * 12), 0, 0) * CFrame.new(0, 0, 3.2)
		cfPart(m, "Frond" .. k, Vector3.new(1.7, 0.15, 6.4), cf, M.Grass, (k % 2 == 0) and C.green or C.greenLight, { collide = false })
	end
	ball(m, "Crown", top.X, top.Y, top.Z, 1.4, M.Wood, rgb(90, 66, 44))
	return m
end

local function createBush(parent, x, z, d)
	local b = ball(parent, "Bush", x, d * 0.35, z, d, M.Grass, C.green)
	ball(parent, "BushB", x + d * 0.35, d * 0.28, z + d * 0.1, d * 0.7, M.Grass, C.greenLight)
	return b
end

local function createPlanter(parent, x0, x1, z0, z1, h)
	box(parent, "Planter", x0, x1, 0, h, z0, z1, M.Concrete, C.warmWhite)
	box(parent, "PlanterSoil", x0 + 0.2, x1 - 0.2, h, h + 0.15, z0 + 0.2, z1 - 0.2, M.Slate, C.black)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	ball(parent, "PlanterShrubA", cx - (x1 - x0) * 0.2, h + 0.7, cz, 1.8, M.Grass, C.green)
	ball(parent, "PlanterShrubB", cx + (x1 - x0) * 0.2, h + 0.6, cz, 1.5, M.Grass, C.greenLight)
end

local function createBench(parent, cx, cz, rot, yb)
	local m = sub(parent, "GardenBench")
	local b = L(m, cx, cz, rot, yb)
	b("Seat", -2.5, 2.5, 1.5, 1.8, -0.8, 0.8, M.WoodPlanks, C.woodLight)
	b("Back", -2.5, 2.5, 1.8, 3.4, -0.8, -0.55, M.WoodPlanks, C.woodLight)
	b("LegL", -2.3, -2.0, 0, 1.5, -0.7, 0.7, M.Metal, C.black)
	b("LegR", 2.0, 2.3, 0, 1.5, -0.7, 0.7, M.Metal, C.black)
end

local function createBollard(parent, x, z)
	cyl(parent, "Bollard", x, 0, 2.2, z, 0.5, M.Metal, C.black)
	local t = cyl(parent, "BollardLight", x, 2.2, 2.45, z, 0.6, M.Neon, C.warmLight, { collide = false })
	addLight(t, "PointLight", 0.5, 11, C.warmLight)
end

---------------------------------------------------------------------
-- TERRENO Y PISCINA
---------------------------------------------------------------------
local function createPool()
	local grass = rgb(86, 132, 72)
	local GR = sub(Garden, "Ground")
	box(GR, "Lawn_Main", -60, 60, -3, 0, -56, 26.8, M.Grass, grass)
	box(GR, "Lawn_Back", -60, 60, -3, 0, 45.2, 56, M.Grass, grass)
	box(GR, "Lawn_PoolLeft", -60, -22.4, -3, 0, 26.8, 45.2, M.Grass, grass)
	box(GR, "Lawn_PoolRight", 10.4, 60, -3, 0, 26.8, 45.2, M.Grass, grass)

	local tile = rgb(150, 205, 220)
	-- vaso de la piscina (30 x 16, 3 de profundidad visual)
	box(Pool, "Basin_Floor", -21, 9, -3.2, -2.8, 28, 44, M.SmoothPlastic, tile)
	box(Pool, "Basin_WallW", -22.4, -21, -3.2, 0, 26.8, 45.2, M.SmoothPlastic, tile)
	box(Pool, "Basin_WallE", 9, 10.4, -3.2, 0, 26.8, 45.2, M.SmoothPlastic, tile)
	box(Pool, "Basin_WallS", -21, 9, -3.2, 0, 26.8, 28, M.SmoothPlastic, tile)
	box(Pool, "Basin_WallN", -21, 9, -3.2, 0, 44, 45.2, M.SmoothPlastic, tile)
	local w = box(Pool, "Water", -21, 9, -2.8, -0.35, 28, 44, M.Glass, C.water, { collide = false, shadow = false })
	w.Transparency = 0.4
	w.Reflectance = 0.1
	-- bordes de piedra
	box(Pool, "Coping_S", -22.4, 10.4, 0, 0.4, 26.8, 28, M.Marble, C.stone)
	box(Pool, "Coping_N", -22.4, 10.4, 0, 0.4, 44, 45.2, M.Marble, C.stone)
	box(Pool, "Coping_W", -22.4, -21, 0, 0.4, 28, 44, M.Marble, C.stone)
	box(Pool, "Coping_E", 9, 10.4, 0, 0.4, 28, 44, M.Marble, C.stone)
	-- escalones de acceso
	box(Pool, "Step_A", -21, -19.8, -2.8, -0.9, 31, 41, M.SmoothPlastic, tile)
	box(Pool, "Step_B", -19.8, -18.6, -2.8, -1.6, 31, 41, M.SmoothPlastic, tile)
	box(Pool, "Step_C", -18.6, -17.4, -2.8, -2.3, 31, 41, M.SmoothPlastic, tile)
	-- iluminación subacuática
	for i, p in ipairs({ { -14, 28.15 }, { -2, 28.15 }, { -14, 43.85 }, { -2, 43.85 } }) do
		local l = box(Pool, "UnderwaterLight" .. i, p[1] - 0.4, p[1] + 0.4, -2.0, -1.6, p[2] - 0.1, p[2] + 0.1, M.Neon, rgb(120, 220, 255), { collide = false, shadow = false })
		addLight(l, "PointLight", 1.2, 18, rgb(120, 220, 255))
	end
	-- terraza de madera alrededor de la piscina
	box(Pool, "Deck_Left", -28, -22.4, 0, 0.4, 25, 50, M.WoodPlanks, C.woodLight)
	box(Pool, "Deck_Right", 10.4, 22, 0, 0.4, 25, 50, M.WoodPlanks, C.woodLight)
	box(Pool, "Deck_Front", -22.4, 10.4, 0, 0.4, 25, 26.8, M.WoodPlanks, C.woodLight)
	box(Pool, "Deck_Back", -22.4, 10.4, 0, 0.4, 45.2, 50, M.WoodPlanks, C.woodLight)
	for i = 0, 5 do
		box(Pool, "Deck_Accent" .. i, -27.5 + i * 9.5, -27.3 + i * 9.5, 0.4, 0.45, 25, 26.8, M.Wood, C.wood, { collide = false })
	end
	-- zona de descanso: tumbonas, mesa y sombrilla
	local FP = sub(Furniture, "PoolArea")
	createLounger(FP, 15.5, 31.5, 90, 0.4)
	createLounger(FP, 15.5, 35.5, 90, 0.4)
	createTable(FP, "Pool_SideTable", 18.5, 33.5, 0, 0.4, 1.6, 1.6, 1.8, M.Wood, C.wood, C.black)
	createLounger(FP, 15.5, 41, 90, 0.4)
	cyl(FP, "Umbrella_Pole", 18.5, 0.4, 9.5, 38.5, 0.25, M.Metal, C.black)
	cyl(FP, "Umbrella_Canopy", 18.5, 9.2, 9.6, 38.5, 9, M.Fabric, C.cream, { collide = false })
	cyl(FP, "Umbrella_Top", 18.5, 9.6, 9.9, 38.5, 3, M.Fabric, C.beige, { collide = false })
	createTable(FP, "Umbrella_Table", 18.5, 38.5, 0, 0.4, 3, 3, 2.6, M.Metal, C.dark, C.black)
	createChair(FP, 18.5, 36.2, 0, 0.4, C.beige)
	createChair(FP, 18.5, 40.8, 180, 0.4, C.beige)
	createSofa(FP, -26.6, 36, 90, 0.4, 8, sofaCol)
	createTable(FP, "Pool_LoungeTable", -23.4, 36, 0, 0.4, 1.8, 4, 1.4, M.Marble, C.white, C.black)
	-- luces de piso en la terraza
	for i, p in ipairs({ { -27, 30 }, { -27, 44 }, { 21, 30 }, { 21, 44 }, { -15, 49 }, { 3, 49 } }) do
		local l = box(Lighting, "DeckLight" .. i, p[1] - 0.3, p[1] + 0.3, 0.4, 0.55, p[2] - 0.3, p[2] + 0.3, M.Neon, C.warmLight, { collide = false })
		addLight(l, "PointLight", 0.5, 12, C.warmLight)
	end
end

---------------------------------------------------------------------
-- JARDÍN Y PAISAJISMO
---------------------------------------------------------------------
local function createGarden()
	local GP = sub(Garden, "Paths")
	-- camino de acceso
	for i = 0, 5 do
		local z0 = -56 + i * 3.8
		box(GP, "PathSlab" .. i, -3, 3, 0, 0.15, z0, z0 + 3.2, M.Concrete, C.stone)
	end
	-- escalones y plataforma de entrada
	box(GP, "EntranceStep1", -9, 9, 0, 0.3, -33.6, -32.4, M.Marble, C.stone)
	box(GP, "EntranceStep2", -9, 9, 0, 0.6, -32.4, -31.2, M.Marble, C.stone)
	box(GP, "EntranceStep3", -9, 9, 0, 0.9, -31.2, -30, M.Marble, C.stone)
	box(GP, "EntrancePlatform", -9, 9, 0, G, -30, -24.4, M.Marble, C.stone)
	-- entrada de vehículos
	box(GP, "Driveway", 10.6, 29.4, 0, 0.12, -56, -24.4, M.Concrete, rgb(138, 138, 138))
	for i = 1, 3 do
		box(GP, "DrivewayJoint" .. i, 10.6, 29.4, 0.12, 0.14, -56 + i * 8, -55.8 + i * 8, M.Concrete, C.dark, { collide = false })
	end
	-- sendero lateral hacia la piscina
	for i = 0, 4 do
		box(GP, "SidePathSlab" .. i, 33.5, 36.5, 0, 0.15, -10 + i * 7, -7.2 + i * 7, M.Concrete, C.stone)
	end
	for i = 0, 3 do
		box(GP, "SidePathTurn" .. i, 36.5 - (i + 1) * 3.6, 36.5 - i * 3.6 - 0.4, 0, 0.15, 22.4, 25.2, M.Concrete, C.stone)
	end
	-- parterres de flores a ambos lados del camino de entrada
	local FB = sub(Garden, "FlowerBeds")
	local fpal = { rgb(224, 110, 150), rgb(240, 205, 70), rgb(245, 245, 245), rgb(150, 100, 190), rgb(230, 130, 60) }
	for _, bed in ipairs({ { -9.5, -4.8 }, { 4.8, 9.5 } }) do
		box(FB, "FlowerBedSoil", bed[1], bed[2], 0, 0.3, -50, -36, M.Slate, rgb(60, 45, 36))
		for k = 0, 17 do
			local fx = bed[1] + 0.6 + ((k * 37) % 10) / 10 * (bed[2] - bed[1] - 1.2)
			local fz = -49.4 + k * 0.76
			ball(FB, "Flower" .. k, fx, 0.75, fz, 0.8, M.Grass, fpal[k % #fpal + 1])
			ball(FB, "FlowerLeaf" .. k, fx, 0.45, fz, 0.9, M.Grass, C.greenDark)
		end
	end
	-- jardineras simétricas a la entrada
	createPlanter(Garden, -8.8, -6.2, -28.4, -27.2, 1.4)
	createPlanter(Garden, 6.2, 8.2, -28.4, -27.2, 1.4)
	-- jardineras a lo largo de la fachada
	createPlanter(Garden, -30, -10, -27.8, -26.4, 1.0)
	-- árboles ornamentales, agrupados con diferentes alturas
	local TG = sub(Garden, "Trees")
	for _, t in ipairs({ { -45, -44, 14, 1 }, { -38, -38, 10, 2 }, { -50, -32, 12, 2 }, { 40, -44, 13, 1 }, { 46, -36, 11, 2 }, { 36, -34, 9, 1 },
		{ -46, 0, 13, 1 }, { -41, 12, 10, 2 }, { -51, 22, 12, 1 }, { 46, 2, 12, 2 }, { 42, 14, 10, 1 }, { 50, 28, 13, 2 },
		{ 40, 46, 11, 1 }, { -44, 40, 12, 2 }, { -36, 50, 9, 1 } }) do
		createTree(TG, t[1], t[2], t[3], t[4])
	end
	-- palmeras
	local PG = sub(Garden, "Palms")
	for _, p in ipairs({ { -7.5, -42, 16 }, { 7.5, -42, 14 }, { -18, -34, 15 }, { -31, 29, 15 }, { -31, 46, 13 }, { 24, 48, 15 }, { 27, 30, 13 }, { 33, -28, 14 } }) do
		createPalm(PG, p[1], p[2], p[3])
	end
	-- arbustos y plantas en grupos
	local BG = sub(Garden, "Shrubs")
	for _, b in ipairs({ { -42, -40, 3 }, { -36, -44, 2.4 }, { -47, -38, 2.6 }, { -24, -35, 2.2 }, { -20, -38, 3 }, { -14, -31, 2 }, { 14, -33, 2.4 },
		{ 38, -38, 2.8 }, { 43, -41, 2.2 }, { -43, 6, 2.8 }, { -48, 14, 2.2 }, { 44, 8, 2.6 }, { 48, 20, 2.2 }, { -34, 33, 2.4 }, { 30, 36, 2.6 },
		{ -10, 54, 2.4 }, { -4, 54, 2.4 }, { 2, 54, 2.4 }, { 8, 54, 2.4 } }) do
		createBush(BG, b[1], b[2], b[3])
	end
	-- piedras decorativas
	for i, r in ipairs({ { -5.5, -50 }, { 5.8, -47 }, { -6, -38 }, { -22, -30 }, { 34, -30 }, { -29, 52 } }) do
		ball(Garden, "DecorativeRock" .. i, r[1], 0.4, r[2], 1.6 + (i % 3) * 0.5, M.Slate, rgb(110, 108, 104), { dy = 1.1 })
	end
	-- bancos y zona de descanso
	createBench(Garden, -26, -42, 0, 0)
	createBench(Garden, -44, 30, 90, 0)
	-- iluminación del camino y del jardín
	local LG = sub(Lighting, "GardenLights")
	for i = 0, 3 do
		createBollard(LG, -3.9, -54 + i * 6)
		createBollard(LG, 3.9, -54 + i * 6)
	end
	for i = 0, 2 do
		createBollard(LG, 9.8, -52 + i * 9)
		createBollard(LG, 30.2, -52 + i * 9)
	end
	for _, p in ipairs({ { -45, -40 }, { 42, -40 }, { -44, 8 }, { 45, 10 } }) do
		local l = cyl(LG, "GardenUplight", p[1], 0, 0.4, p[2], 0.8, M.Neon, C.neutralLight, { collide = false })
		addLight(l, "PointLight", 0.6, 16, C.neutralLight)
	end
end

createPool()
createGarden()

---------------------------------------------------------------------
-- ILUMINACIÓN ARQUITECTÓNICA EXTERIOR
---------------------------------------------------------------------
local LE = sub(Lighting, "ExteriorLights")
for _, x in ipairs({ 9.2, 30.8 }) do
	local s = box(LE, "Garage_WallLight", x - 0.25, x + 0.25, 12.3, 13.7, -24.9, -24.65, M.Neon, C.warmLight, { collide = false })
	addLight(s, "PointLight", 0.8, 16, C.warmLight)
end
for _, x in ipairs({ -13.2, 3.2 }) do
	local s = box(LE, "Dining_BackWallLight", x - 0.25, x + 0.25, 9, 10.4, 24.65, 24.9, M.Neon, C.warmLight, { collide = false })
	addLight(s, "PointLight", 0.8, 16, C.warmLight)
end
neonStrip(LE, "Facade_EntranceCoveLight", -5.5, 8, 13.3, 13.4, -29.6, -24.6, C.warmLight, 0.8, 18)
neonStrip(LE, "Facade_MasterBalconyLight", -30.6, -9.4, S1 - 0.1, S1, -28.9, -28.7, C.warmLight, 0.7, 16)
neonStrip(LE, "Facade_RearBalconyLight", 17.5, 30.5, S1 - 0.1, S1, 29.0, 29.2, C.warmLight, 0.7, 14)
neonStrip(LE, "Facade_HallBladeLight", 8.5, 9.9, 20, 20.2, -27.1, -26.9, C.neutralLight, 0.6, 14)

---------------------------------------------------------------------
-- PÉRGOLA SOBRE LA ZONA DE ESTAR JUNTO A LA PISCINA
---------------------------------------------------------------------
local PGL = sub(Pool, "LoungePergola")
for i, p in ipairs({ { -28.2, 31.2 }, { -28.2, 40.8 }, { -22.9, 31.2 }, { -22.9, 40.8 } }) do
	box(PGL, "PergolaPost" .. i, p[1] - 0.2, p[1] + 0.2, 0.4, 9, p[2] - 0.2, p[2] + 0.2, M.Metal, C.black)
end
box(PGL, "PergolaBeamW", -28.4, -28, 9, 9.4, 31, 41, M.Metal, C.black)
box(PGL, "PergolaBeamE", -23.1, -22.7, 9, 9.4, 31, 41, M.Metal, C.black)
for i = 0, 9 do
	box(PGL, "PergolaSlat" .. i, -28.6, -22.5, 9.4, 9.7, 31.2 + i * 1.0, 31.5 + i * 1.0, M.Wood, C.wood)
end
local pl = box(PGL, "PergolaLight", -25.8, -25.2, 8.9, 9, 35.7, 36.3, M.Neon, C.warmLight, { collide = false })
addLight(pl, "PointLight", 0.7, 14, C.warmLight)

---------------------------------------------------------------------
-- FINAL
---------------------------------------------------------------------
local count = 0
for _, d in ipairs(Mansion:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
print(string.format("[LuxuryModernMansion] Construida correctamente: %d piezas.", count))
