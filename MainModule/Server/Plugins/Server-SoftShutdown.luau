--// Originally written by Merely
--// Edited by GitHub@LolloDev5123 and Irreflexive
--// GitHub@Expertcoderz was here to make things look better

return function(Vargs, GetEnv)
	local server = Vargs.Server
	local service = Vargs.Service

	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	local TeleportService: TeleportService = service.TeleportService
	local Players: Players = service.Players
	local teleportedPlayers = setmetatable({}, {__mode = "k"})
	local isReservedServer = #game.PrivateServerId > 0 and game.PrivateServerOwnerId == 0

	local PARAMETER_NAME = "ADONIS_SOFTSHUTDOWN"
	local PARAMETER_2_NAME = "ADONIS_SHUTDOWN_REJOIN"
	local MAX_RETRIES = 4
	local RETRY_WAIT = 1.5

	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		if teleportedPlayers[player] and placeId == game.PlaceId and not table.find({Enum.TeleportResult.Success, Enum.TeleportResult.IsTeleporting}, result) then
			if teleportedPlayers[player] < MAX_RETRIES then
				task.wait(RETRY_WAIT * teleportedPlayers[player])
				teleportedPlayers[player] += 1
				Logs:AddLog("Script", `Failed to teleport {player.Name} {isReservedServer and "back to the main game" or "to a temporary softshutdown server"} due to {result.Name}. Retrying... Details: {message}`)
				Functions.Notification("Teleport failed", `SoftShutdown failed to teleport {isReservedServer and "back to the main game" or "to a temporary softshutdown server"}. Retrying...`, {player}, 10, "MatIcon://Warning")
				TeleportService:Teleport(game.PlaceId, player, {[PARAMETER_2_NAME] = true})
			else
				Logs:AddLog("Script", `Failed to teleport {player.Name} {isReservedServer and "back to the main game" or "to a temporary softshutdown server"} due to {result.Name}. Details: {message}`)
				Logs:AddLog("Errors", `Failed to teleport {player.Name} {isReservedServer and "back to the main game" or "to a temporary softshutdown server"} to {result.Name}. Details: {message}`)
				Functions.Notification("Teleport failed", `SoftShutdown failed to teleport {isReservedServer and "back to the main game" or "to a temporary softshutdown server"}. Details {message}`, {player}, 35, "MatIcon://Error")
			end
		end
	end)

	if isReservedServer then
		task.defer(function()
			local waitTime = 5
			local playersToTeleport = {}

			local jobid
			local startTask, TeleportTask = service.Threads.NewTask("Teleport Players", function()
				jobid = TeleportService:TeleportPartyAsync(game.PlaceId, playersToTeleport, {[PARAMETER_2_NAME] = true})
				Logs:AddLog("Script", `Teleported {#playersToTeleport} players back to the main game`)
			end)

			local function sendMessage(player)
				task.defer(function()
					repeat task.wait(0.25) until not player or not player.Parent or teleportedPlayers[player] or Remote.Clients[tostring(player.UserId)] and Remote.Clients[tostring(player.UserId)].FinishedLoading
					Functions.Message("Adonis", Settings.SystemTitle, "Teleporting back to main game...", "MatIcon://Hourglass empty", {player}, false, 1000)
				end)
			end

			local function teleport(player)
				local joindata = player:GetJoinData()
				local data = type(joindata) == "table" and joindata.TeleportData

				if type(data) == "table" and data[PARAMETER_NAME] then
					sendMessage(player)
					task.wait(waitTime + 5)
					waitTime /= 2

					Logs:AddLog("Script", `Teleporting {player.Name} back to the main game`)
					teleportedPlayers[player] = 1
					table.insert(playersToTeleport, player)
				end
			end

			if #service.Players:GetPlayers() == 0 then
				service.Players.PlayerAdded:Wait()
			end

			service.Players.PlayerAdded:Connect(function(player)
				local joindata = player:GetJoinData()
				local data = type(joindata) == "table" and joindata.TeleportData

				if type(data) == "table" and data[PARAMETER_NAME] then
					sendMessage(player)
					if TeleportTask.Running then
						TeleportTask.Finished:wait()
					end

					if not jobid then
						repeat task.wait(1) until jobid ~= nil
					end

					if not player or not player.Parent then
						return
					end

					TeleportService:TeleportToPlaceInstance(game.PlaceId, jobid, player, "", {[PARAMETER_2_NAME] = true})
				end
			end)

			for _, player in service.Players:GetPlayers() do
				teleport(player)
			end

			if #playersToTeleport > 0 then
				Logs:AddLog("Script", `Teleporting {#playersToTeleport} players back to the main game`)
				task.wait(1)
				startTask()
			end
		end)
	end

	Remote.Terminal.Commands.SoftShutdown = {
		Usage = "restart";
		Command = "restart";
		Arguments = 0;
		Description = "Restart the server, placing all of the players in a reserved server and teleporting each of them to the new server";
		Function = function(p,args,data)
			if service.RunService:IsStudio() and not server.Core.DebugMode then return end
			if #Players:GetPlayers() == 0 then return end

			local newserver = TeleportService:ReserveServer(game.PlaceId)
			Functions.Message("Adonis", Settings.SystemTitle, "The server is restarting, please wait...", "MatIcon://Hourglass empty", service.GetPlayers(), false, 1000)
		
			task.wait(2)

			for _, v in Players:GetPlayers() do
				teleportedPlayers[v] = 1
			end

			Logs:AddLog("Script", `Teleporting {#Players:GetPlayers()} players to a temporary softshutdown server`)
			TeleportService:TeleportToPrivateServer(game.PlaceId, newserver, Players:GetPlayers(), "", {[PARAMETER_NAME] = true})
			Players.PlayerAdded:Connect(function(player)
				Logs:AddLog("Script", `Teleporting {player.Name} to a temporary softshutdown server`)
				teleportedPlayers[player] = 1
				TeleportService:TeleportToPrivateServer(game.PlaceId, newserver, { player }, "", {[PARAMETER_NAME] = true})
			end)
			task.delay(60, function()
				Variables.ServerLock = true
			end)

			while #Players:GetPlayers() > 0 do
				Players.PlayerRemoving:Wait()
			end
		end
	}
	Commands.SoftShutdown = {
		Prefix = Settings.Prefix;
		Commands = {"softshutdown", "restart", "sshutdown", "restartserver"};
		Args = {"reason"};
		Description = "Restarts the server";
		Filter = true;
		NoStudio = true; --// TeleportService does not work in Studio
		AdminLevel = "Admins";
		Function = function(plr: Player, args: {string})
			if #Players:GetPlayers() == 0 then return end

			local newserver = TeleportService:ReserveServer(game.PlaceId)
			Functions.Message("Adonis", Settings.SystemTitle, "The server is restarting, please wait...", "MatIcon://Hourglass empty", service.GetPlayers(), false, 1000)

			if Core.DataStore then
				Core.UpdateData("ShutdownLogs", function(logs)
					if plr then
						table.insert(logs, 1, {
							User = plr.Name,
							Restart = true,
							Time = os.time(),
							Reason = args[1] or "N/A"
						})
					else
						table.insert(logs, 1, {
							User = "[Server]",
							Restart = true,
							Time = os.time(),
							Reason = args[1] or "N/A"
						})
					end

					if #logs > Logs.OldCommandLogsLimit then
						table.remove(logs, #logs)
					end

					return logs
				end)
			end

			task.wait(1)

			for _, v in Players:GetPlayers() do
				teleportedPlayers[v] = 1
			end

			Logs:AddLog("Script", `Teleporting {#Players:GetPlayers()} players to a temporary softshutdown server`)
			TeleportService:TeleportToPrivateServer(game.PlaceId, newserver, Players:GetPlayers(), "", {[PARAMETER_NAME] = true})
			Players.PlayerAdded:Connect(function(player)
				Logs:AddLog("Script", `Teleporting {player.Name} to a temporary softshutdown server`)
				teleportedPlayers[player] = 1
				TeleportService:TeleportToPrivateServer(game.PlaceId, newserver, { player }, "", {[PARAMETER_NAME] = true})
			end)
			task.delay(60, function()
				Variables.ServerLock = true
			end)
			while #Players:GetPlayers() > 0 do
				Players.PlayerRemoving:Wait()
			end
		end
	}
	Commands.GlobalSoftShutdown = {
		Prefix = Settings.Prefix;
		Commands = {"globalsoftshutdown", "globalrestart", "globalsshutdown", "grestart"};
		Args = {"reason (default: none)", "time<s,m> (default: instant)", "abortable (default: true)"};
		Description = "Performs a global restart on all servers after set time. (Abortable specifies whether VIP server owners can abort the restart on their own servers.)";
		Filter = true;
		AdminLevel = "HeadAdmins";
		CrossServerDenied = true;
		IsCrossServer = true;
		Function = function(plr: Player, args: {string})
			local time
			if args[2] then
				time = string.lower(args[2])
				if string.sub(time, -1, -1) == "s" then
					time = tonumber(string.sub(time, 1, -2))
				elseif string.sub(time, -1, -1) == "m" then
					time = tonumber(string.sub(time, 1, -2)) * 60
				elseif time == ("#"):rep(string.len(time)) then -- This arg can sometimes be filtered.
					error("Specified time was filtered by roblox. Try again.");
				elseif time ~= "instant" then
					time = nil -- This will force the error below if they do not use correct usage.
				end
				assert(time, "Invalid time specified. Example usage: 60s, 5m or \"instant\"");
			end
			if not Core.CrossServer("GlobalRestartRequest",
				args[1] or "No reason specified.",
				tonumber(time),
				if args[3] then (string.lower(args[3]) == "no" or string.lower(args[3]) == "false") else true
				)
			then
				error("CrossServer handler not ready (try again later)")
			end
		end
	}
	Commands.AbortGlobalSoftShutdown = {
		Prefix = Settings.Prefix;
		Commands = {"abortglobalsoftshutdown", "abortglobalrestart", "abortglobalsshutdown", "abortgrestart"};
		Args = {};
		Description = "Aborts a global shutdown on all servers.";
		Filter = true;
		AdminLevel = "HeadAdmins";
		CrossServerDenied = true;
		IsCrossServer = true;
		Function = function(plr: Player, args: {string})
			if not Core.CrossServer("GlobalRestartAbort") then
				error("CrossServer handler not ready (try again later)")
			end
		end
	}
	Commands.VIPAbortGlobalServerRestart = {
		Prefix = Settings.PlayerPrefix;
		Commands = {"abortrestart"};
		Args = {};
		Description = "Aborts a global server restart";
		NoStudio = true;
		AdminLevel = "Players";
		Disabled = game.PrivateServerOwnerId == 0; -- enabled only on VIP servers.
		Function = function(plr: Player, args: {string})
			assert(plr.UserId == game.PrivateServerOwnerId, "You don't have permission to run this command.")
			assert(Core.CrossServerCommands.GlobalRestartAbort())
		end
	}

	Logs:AddLog("Script", "Soft Shutdown Module Loaded");
end
