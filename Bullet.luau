-- // cool bullet.luau - predict bullet path
-- requirements:
-- 	BulEnd : Attachment - where the bullet ends
-- 	BulStart : Attachment - where the bullet starts

task.wait(3) -- // you can remove this

-- // future variables
local rays = {}
-- function visualizeRay -> RayCast
--		@param start - Start position of the ray [Vector3]
--		@param dir - Direction of the ray [Vector3]
local function visualizeRay(start : Vector3,dir : Vector3)
	local ray = Instance.new("Part")
	local raycast = workspace:Raycast(start,dir*512)
	local raysize
	if raycast then
		local hit = raycast.Position
		raysize = (hit - start).Magnitude
	else
		raysize = 512
	end
	ray.Size = Vector3.new(0.1,0.1,raysize)
	ray.Anchored = true
	ray.CanCollide = false
	ray.Material = Enum.Material.Neon
	ray.Color = Color3.new(1,1,1)
	ray.Transparency = 0.95
	ray.CFrame = CFrame.new(start + dir*(raysize/2), start + dir)
	ray.Parent = workspace
	ray.CanQuery = false
	table.insert(rays,ray)
	return raycast
end
-- function shatterWall -> nil
--		@param originalWall - The wall to shatter [BasePart]
--		@param rows - Number of rows for the wall [number]
--		@param columns - Number of columns for the wall [number]
local function shatterWall(originalWall: BasePart, rows: number, columns: number)
	if not originalWall or not originalWall:IsA("BasePart") then return end
	local transp = originalWall.Transparency
	local size = originalWall.Size
	local cframe = originalWall.CFrame
	local isXAxis = size.X > size.Z
	local wallWidth = isXAxis and size.X or size.Z
	local wallThickness = isXAxis and size.Z or size.X
	local wallHeight = size.Y
	local pieceWidth = wallWidth / columns
	local pieceHeight = wallHeight / rows
	local pieceSize = isXAxis
		and Vector3.new(pieceWidth, pieceHeight, wallThickness)
		or Vector3.new(wallThickness, pieceHeight, pieceWidth)
	originalWall.Transparency = 1
	originalWall.CanCollide = false
	local piecesFolder = Instance.new("Folder")
	piecesFolder.Name = originalWall.Name .. "_Pieces"
	piecesFolder.Parent = originalWall.Parent
	for r = 1, rows do
		for c = 1, columns do
			local localX = (c - 0.5 - (columns / 2)) * pieceWidth
			local localY = (r - 0.5 - (rows / 2)) * pieceHeight
			local localOffset = isXAxis 
				and Vector3.new(localX, localY, 0)
				or Vector3.new(0, localY, localX)

			local piece = Instance.new("Part")
			piece.Size = pieceSize
			piece.CFrame = cframe * CFrame.new(localOffset)
			piece.Color = originalWall.Color
			piece.Material = originalWall.Material
			piece.Transparency = transp
			piece.Anchored = false
			piece.CanCollide = true
			piece.Parent = piecesFolder
		end

	end
	originalWall:Destroy()
end
-- // services
local TweeenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
-- // bullet variables
local speed = 15
local lasthitPos = script.Parent.BulEnd.WorldPosition
local lastdir = script.Parent.BulEnd.WorldCFrame.RightVector
local lastHitInstance
local points = {}
-- // predict bullet path
while task.wait() do
	if lasthitPos then
		local newray = visualizeRay(lasthitPos,lastdir)
		if newray == nil then
			table.insert(points,lasthitPos + lastdir*512)
			break
		end
		local reflectedDir = lastdir - (2 * lastdir:Dot(newray.Normal) * newray.Normal)
		if newray.Instance ~= nil then
			if newray.Instance:IsA("BasePart") then
				if newray.Instance.Material ~= Enum.Material.Glass then
					lasthitPos = newray.Position
					table.insert(points,lasthitPos)
					lastdir = reflectedDir
				else
					lastHitInstance = newray.Instance
					table.insert(points, newray.Position)
					break
				end
			end
		end
	end
end
-- // visualize bullet path
local currentBulletPos = script.Parent.BulEnd.WorldPosition
for i, v in pairs(points) do
	local segmentLength = (v - currentBulletPos).Magnitude
	script.Parent.CFrame = CFrame.new(currentBulletPos, v) * CFrame.Angles(0, math.rad(-90), 0)
	local duration = segmentLength / speed
	local anim = TweeenService:Create(script.Parent, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = v})
	anim:Play()
	local activeRay = rays[i]
	local raycon
	raycon = RunService.Heartbeat:Connect(function()
		local bulStart = script.Parent.BulStart.WorldPosition
		local remaining = v - bulStart
		local raysize = remaining.Magnitude
		activeRay.Size = Vector3.new(0.1,0.1,raysize)
		activeRay.CFrame = CFrame.new(bulStart + remaining.Unit*(raysize/2), v)
	end)
	anim.Completed:Wait()
	raycon:Disconnect()
	activeRay:Destroy()
	currentBulletPos = v
end
-- // shatter glass wall if it was found
if lastHitInstance ~= nil then
	shatterWall(lastHitInstance,7,7)
	script.Parent.Anchored = false
	script.Parent.AssemblyLinearVelocity = lastdir * 500
	script:Destroy()
end