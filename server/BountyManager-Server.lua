class 'BountyManager'

function BountyManager:__init()
	AlertBracket			=	"*****"	--	The text put on each side of a Bounty Chat Broadcast to catch attention.
										--	This is put on the front and back, so it is suggested to keep it mirrored.
										--	Set to "" to not show.
	SuccessColor			=	Color(0, 250, 0, 200)	--	The color of success notices.
	FailureColor			=	Color(250, 0, 0, 200)	--	The color of failure notices.
	NoticeColor				=	Color(250, 250, 0, 200)	--	The color of information player messages.
	NotificationColor		=	Color(250, 250, 0, 250)	--	The color of Bounty Set/Claimed/Karma Chat Broadcasts.
	ChatCommand				=	"bounty"	--	The Chat activation command, prefixed by "/".
	BountySetElseMessage	=	"Usage: '/" .. ChatCommand .. " set <amount> <player>'."	--	The message shown if a Bounty Set command is written wrong.
	BountyDelElseMessage	=	"Usage: '/" .. ChatCommand .. " del <player>'."			--	The message shown if a Bounty Delete command is written wrong.
	AllowPlayerBountyValues	=	true	--	Allows the system to set Bounty information onto player's values. This is not required, but is useful for having other modules use Bounty information.
	BountyPopupsEnabled		=	true	--	Shows a popup note by the minimap to all players when a bounty is set or claimed.
	
    SQL:Execute("CREATE TABLE IF NOT EXISTS BountyManager_Bounties (targetname VARCHAR, targetid VARCHAR, settername VARCHAR, setterid VARCHAR, bounty INTEGER)")
    SQL:Execute("CREATE TABLE IF NOT EXISTS BountyManager_PlayerStats (playerid VARCHAR UNIQUE, playername VARCHAR, bountyclaimed INTEGER, bountyset INTEGER)")

	--	Bounty Commands	--
	self.sqlSetBounty				=	"INSERT INTO BountyManager_Bounties (targetname, targetid, settername, setterid, bounty) VALUES (?,?,?,?,?)"
    self.sqlRemoveSpecificBounty	= 	"DELETE FROM BountyManager_Bounties WHERE targetid = (?) AND setterid = (?)"
    self.sqlRemoveBounty			= 	"DELETE FROM BountyManager_Bounties WHERE targetid = (?)"
    self.sqlCheckBounty				= 	"SELECT bounty FROM BountyManager_Bounties WHERE targetid = (?) AND setterid = (?)"
    self.sqlCheckTotalBounty		= 	"SELECT targetname, targetid, settername, setterid, bounty FROM BountyManager_Bounties WHERE targetid = (?)"
	self.sqlCheckTotalBountySet	= 	"SELECT targetname, targetid, settername, setterid, bounty FROM BountyManager_Bounties WHERE settername = (?) or setterid = (?) LIMIT 11"
	self.sqlCheckTotalBountySetPage	= 	"SELECT targetname, targetid, settername, setterid, bounty FROM BountyManager_Bounties WHERE settername = (?) or setterid = (?) LIMIT 10 OFFSET (?)"

	--	Stat Commands	--
    self.sqlGetBountyStats			= 	"SELECT playername, bountyclaimed, bountyset FROM BountyManager_PlayerStats WHERE playerid = (?)"
	self.sqlUpdateBountyStats		=	"INSERT OR REPLACE INTO BountyManager_PlayerStats (playerid, playername, bountyclaimed, bountyset) VALUES (?,?,?,?)"
	
	Events:Subscribe("PlayerChat", self, self.ParseChat)
	Events:Subscribe("PlayerDeath", self, self.ClaimBounty)
	Events:Subscribe("ModulesLoad", self, self.BroadcastBountyTable)
	Events:Subscribe("PlayerJoin", self, self.BroadcastBountyTable)
end

function BountyManager:UpdateBountyStats(player, claimedUpdate, setUpdate)
--	print("Changing Claimed by: " ..claimedUpdate)
--	print("Changing Set by: " ..setUpdate)
	local PlayerName	=	player:GetName()
	local PlayerSteamID	=	player:GetSteamId().id
	local PlayerBountyInfo = self:GetBountyStats(player)
	if PlayerBountyInfo then
		ClaimedBounties = PlayerBountyInfo.Claimed + claimedUpdate
		SetBounties = PlayerBountyInfo.Set + setUpdate
	else
		ClaimedBounties = 0 + claimedUpdate
		SetBounties = 0 + setUpdate
	end

--	1: Player.Id	2: PlayerName		3: BountiesClaimed,	4:	BountiesSet
    self.dbCommand = SQL:Command(self.sqlUpdateBountyStats)
    self.dbCommand:Bind(1, PlayerSteamID)
    self.dbCommand:Bind(2, PlayerName)
    self.dbCommand:Bind(3, ClaimedBounties)
    self.dbCommand:Bind(4, SetBounties)
    self.dbCommand:Execute()

	self:BroadcastBountyTable()
    return true
end

function BountyManager:GetBountyStats(player)
	local PlayerName	=	player:GetName()
	local PlayerSteamID	=	player:GetSteamId().id
    self.qbQuery = SQL:Query(self.sqlGetBountyStats)
    self.qbQuery:Bind(1, PlayerSteamID)
    local result = self.qbQuery:Execute()
    if #result > 0 then
		return {
				Name	=	result[1].playername,
				Claimed	=	tonumber(result[1].bountyclaimed),
				Set		=	tonumber(result[1].bountyset)
				}
	end
	return false
end

function BountyManager:GetExtendedBountyStats(player)
	local PlayerName	=	player:GetName()
	local PlayerSteamID	=	player:GetSteamId().id
    self.qbQuery = SQL:Query(self.sqlCheckTotalBountySet)
    self.qbQuery:Bind(1, PlayerName)
	self.qbQuery:Bind(2, PlayerSteamID)
    local result = self.qbQuery:Execute()
    if #result > 0 then
		return result
	end
	return false
end

function BountyManager:GetExtendedBountyStatsPages(player, page)
	local PlayerName	=	player:GetName()
	local PlayerSteamID	=	player:GetSteamId().id
    self.qbQuery = SQL:Query(self.sqlCheckTotalBountySetPage)
    self.qbQuery:Bind(1, PlayerName)
	self.qbQuery:Bind(2, PlayerSteamID)
	self.qbQuery:Bind(3, (tonumber(page)*10))
    local result = self.qbQuery:Execute()
    if #result > 0 then
		return result
	end
	return false
end

function BountyManager:BroadcastBountyTable()
	BountyTable	=	{}
	for players in Server:GetPlayers() do
		local PlayerName		=	players:GetName()
		local PlayerSteamID		=	players:GetSteamId().id
		local PlayerBounty		=	self:CheckTotalBounty(players)
		local PlayerBountyScore	=	self:GetBountyStats(players)
		if PlayerBounty == false then
			PlayerBounty = 0
		end
		if PlayerBountyScore == false then
			PlayerBountyScore = {Claimed = 0, Set = 0}
		end
		BountyTable[PlayerSteamID]	=	{
						Bounty	=	PlayerBounty,
						Claimed	=	PlayerBountyScore.Claimed,
						Set		=	PlayerBountyScore.Set
						}
		local DisplayString	=	"$" .. self:Commas(PlayerBounty) .. " (" .. PlayerBountyScore.Claimed .. "/" .. PlayerBountyScore.Set .. ")"
		if AllowPlayerBountyValues then
			players:SetNetworkValue("BountyDisplay", tostring(DisplayString))
			players:SetNetworkValue("BountyAmount", tonumber(PlayerBounty))
			players:SetNetworkValue("BountyScore", tostring(PlayerBountyScore.Claimed .. "/" .. PlayerBountyScore.Set))
		end
--		print("Adding " .. PlayerName .. "($" .. PlayerBounty .. ", " .. PlayerBountyScore[2] .. "/" .. PlayerBountyScore[3] .. ")...")
	end
--	print("Bounty Information Broadcast.")
	Events:Fire("PluginBountyManagerBroadcast", BountyTable)
end

function BountyManager:RemoveThisBounty(targetObject, setterObject)
	local TargetName	=	targetObject:GetName()
	local TargetSteamID	=	targetObject:GetSteamId().id
	local SetterName	=	setterObject:GetName()
	local SetterSteamID	=	setterObject:GetSteamId().id
	
	local cmd = SQL:Command(self.sqlRemoveSpecificBounty)
	cmd:Bind(1, TargetSteamID)
	cmd:Bind(2, SetterSteamID)
	cmd:Execute()
--	self:BroadcastBountyTable()
	return true
end

function BountyManager:ClaimBounty(args)
	local targetObject	=	args.player
	local hunterObject	=	args.killer
	if hunterObject then
		if targetObject == hunterObject then return end
		local TargetName	=	targetObject:GetName()
		local TargetSteamID	=	targetObject:GetSteamId().id
		local TargetWorth	=	self:CheckTotalBounty(targetObject)
		local HunterName	=	hunterObject:GetName()
		local HunterSteamID	=	hunterObject:GetSteamId().id
		local HunterWorth	=	self:CheckTotalBounty(hunterObject)
		if HunterWorth then
			self.queryRemoveAllBounty = SQL:Query(self.sqlCheckTotalBounty)
			self.queryRemoveAllBounty:Bind(1, HunterSteamID)
			local result = self.queryRemoveAllBounty:Execute()
			if #result > 0 then
				for i = 1, #result do
					if TargetSteamID == result[i].setterid then
						print("Karma: " .. TargetName .. " had set a bounty on " .. HunterName .. "!")
						local HuntedBounty = result[i].bounty
						if self:RemoveThisBounty(hunterObject, targetObject) then
							self:UpdateBountyStats(hunterObject, 1, 0)
							self:SendServerPopup("Karma Strikes! " .. TargetName .. " had set a bounty on " .. HunterName .. " but was killed by them instead!", true)
							self:SendServerPopup(HunterName .. " receives the $" .. self:Commas(HuntedBounty) .. " bounty!", false)
							Chat:Broadcast(AlertBracket .. " Karma Strikes! " .. AlertBracket, NotificationColor)
							Chat:Broadcast(AlertBracket .. " " .. TargetName .. " had set a bounty on " .. HunterName .. " but was killed by them instead! " .. AlertBracket, NotificationColor)
							Chat:Broadcast(AlertBracket .. " " .. HunterName .. " receives the $" .. self:Commas(HuntedBounty) .. " bounty! " .. AlertBracket, NotificationColor)
							hunterObject:SetMoney(hunterObject:GetMoney() + HuntedBounty)
							print(HunterName .. " killed " .. TargetName .. " and received the $" .. self:Commas(HuntedBounty) .. " bounty set on them by " .. TargetName)
							AnnouceBountyScore = true
						end
					end
				end
			end
		end
		if TargetWorth then
			self.queryRemoveAllBounty = SQL:Query(self.sqlCheckTotalBounty)
			self.queryRemoveAllBounty:Bind(1, TargetSteamID)
			local result = self.queryRemoveAllBounty:Execute()
			if #result > 0 then
				for i = 1, #result do
					local cmd = SQL:Command(self.sqlRemoveBounty)
					cmd:Bind(1, TargetSteamID)
					cmd:Execute()
					self:UpdateBountyStats(hunterObject, 1, 0)
					print("Claiming " .. result[i].settername .. "'s $" .. result[i].bounty .. " bounty on " .. TargetName)
				end
			end
			self:SendServerPopup("Bounty Claimed! " .. HunterName .. " receives $" .. self:Commas(TargetWorth) .. " for killing " .. TargetName .. "!", false)
			Chat:Broadcast(AlertBracket .. " Bounty Claimed! " .. HunterName .. " receives $" .. self:Commas(TargetWorth) .. " for killing " .. TargetName .. "! " .. AlertBracket, NotificationColor)
			hunterObject:SetMoney(hunterObject:GetMoney() + TargetWorth)
			print("Bounty Claimed: " .. HunterName .. " killed " .. TargetName .. " and received a bounty of $" .. self:Commas(TargetWorth))
			AnnouceBountyScore = true
		end
		if AnnouceBountyScore then
			local BountyScore = self:GetBountyStats(hunterObject)
			Chat:Broadcast(AlertBracket .. " " .. HunterName .. "'s Bounty Hunter Score is now " .. BountyScore.Claimed .. " Claimed / " .. BountyScore.Set .. " Set! " .. AlertBracket, NotificationColor)
			AnnouceBountyScore = false
		end
	end
end

function BountyManager:CheckTotalBounty(targetObject)
	local TargetName	=	targetObject:GetName()
	local TargetSteamID	=	targetObject:GetSteamId().id
    self.queryCheckTotalBounty = SQL:Query(self.sqlCheckTotalBounty)
    self.queryCheckTotalBounty:Bind(1, TargetSteamID)
    local result = self.queryCheckTotalBounty:Execute()
    if #result > 0 then
		local TotalBounty = 0
		for i = 1, #result do
			TotalBounty = TotalBounty + result[i].bounty
		end
		return TotalBounty
	end
	return false
end

function BountyManager:CheckBounty(targetObject, setterObject)
	local TargetName	=	targetObject:GetName()
	local TargetSteamID	=	targetObject:GetSteamId().id
	local SetterName	=	setterObject:GetName()
	local SetterSteamID	=	setterObject:GetSteamId().id
    self.queryCheckBounty = SQL:Query(self.sqlCheckBounty)
    self.queryCheckBounty:Bind(1, TargetSteamID)
    self.queryCheckBounty:Bind(2, SetterSteamID)
    local result = self.queryCheckBounty:Execute()
    if #result > 0 then
		return result[1].bounty
	end
	return false
end

function BountyManager:SetBounty(targetObject, setterObject, bountyAmount)
	local TargetName	=	targetObject:GetName()
	local TargetSteamID	=	targetObject:GetSteamId().id
	local SetterName	=	setterObject:GetName()
	local SetterSteamID	=	setterObject:GetSteamId().id

--	1: TargetName	2: TargetSteamId.id		3: SetterName,	4:	SetterSteamId.id, 5: Bounty
    self.queryAddSetBounty = SQL:Command(self.sqlSetBounty)
    self.queryAddSetBounty:Bind(1, TargetName)
    self.queryAddSetBounty:Bind(2, TargetSteamID)
    self.queryAddSetBounty:Bind(3, SetterName)
    self.queryAddSetBounty:Bind(4, SetterSteamID)
    self.queryAddSetBounty:Bind(5, bountyAmount)
    self.queryAddSetBounty:Execute()
    print("Wanted: " .. SetterName .. " set a bounty of $" .. bountyAmount .. " on " .. TargetName)
	self:UpdateBountyStats(setterObject, 0, 1)
	local TargetTotalBounty	=	self:CheckTotalBounty(targetObject)
	if TargetTotalBounty > bountyAmount then
		Chat:Broadcast(AlertBracket .. " Bounty Increased! " .. AlertBracket, NotificationColor)
	end
	self:SendServerPopup("Wanted: " .. TargetName .. " - Reward: $" .. self:Commas(TargetTotalBounty) .. "!", false)
	Chat:Broadcast(AlertBracket .. " Wanted: " .. TargetName .. " - Reward: $" .. self:Commas(TargetTotalBounty) .. "! " .. AlertBracket, NotificationColor)
--	self:BroadcastBountyTable()
    return true
end

function BountyManager:SendServerPopup(text, icon)
	if not BountyPopupsEnabled then return end
	for players in Server:GetPlayers() do
		self:SendPopup(players, text, icon)
	end
end

function BountyManager:SendPopup(player, text, icon)
	Network:Send(player, "ShowPopup", {Text = text, Icon = icon})
end

function BountyManager:ParseChat(args)
	local msg				=	string.split(args.text, " ")	--	Split at Spaces.
	local mySelf			=	args.player						--	Sender's Player Object.
	local mySteamID			=	args.player:GetSteamId().id		--	Sender's Steam ID.
	local mySteamString		=	args.player:GetSteamId().string	--	Sender's Steam ID.
	local myName			=	args.player:GetName()			--	Sender's Name.
	local myMoney			=	args.player:GetMoney()			--	Sender's Name.
	if string.lower(msg[1]) == "/" .. ChatCommand then
		if table.count(msg) >= 2 then
			if msg[2] == "set" then
				if table.count(msg) >= 4 then
					if msg[3] == nil then
						mySelf:SendChatMessage(BountySetElseMessage, NoticeColor )
					return end
					local RoughBounty = msg[3]:gsub("%$", "")
					local RoughBounty = RoughBounty:gsub("%,", "")
					local RoughBounty = RoughBounty:gsub("-", "")
					local Bounty = tonumber(RoughBounty)
					if Bounty == nil then
						mySelf:SendChatMessage("Bounty amount must be a number.", FailureColor )
					return end
					if Bounty > myMoney then
						mySelf:SendChatMessage("You only have $" .. self:Commas(myMoney) .. ", you can't afford to set a $" .. self:Commas(Bounty) .. " bounty.", FailureColor )
					return end
					AffectedPlayer = self:GetPlayerByTableInput(msg, 3, mySelf)
					if not IsValid(AffectedPlayer) then return end
					if self:CheckBounty(AffectedPlayer, mySelf) then
						local Bounty = tonumber(self:CheckBounty(AffectedPlayer, mySelf))
						mySelf:SendChatMessage("You have already set a bounty of $" .. self:Commas(Bounty) .. " on " .. AffectedPlayer:GetName() .. ".", NoticeColor )
					else
						if self:SetBounty(AffectedPlayer, mySelf, Bounty) then
							mySelf:SetMoney(mySelf:GetMoney() - Bounty)
							mySelf:SendChatMessage("You have set a bounty of $" .. self:Commas(Bounty) .. " on " .. AffectedPlayer:GetName() .. ".", SuccessColor )
						end
					end
				else
					mySelf:SendChatMessage(BountySetElseMessage, NoticeColor )
				end
			elseif msg[2] == "del" then
				if table.count(msg) >= 3 then
					AffectedPlayer = self:GetPlayerByTableInput(msg, 2, mySelf)
					if not IsValid(AffectedPlayer) then return end
					local Bounty = tonumber(self:CheckBounty(AffectedPlayer, mySelf))
					if Bounty then
						mySelf:SetMoney(mySelf:GetMoney() + Bounty)
						self:RemoveThisBounty(AffectedPlayer, mySelf)
						self:UpdateBountyStats(mySelf, 0, -1)
						print(myName .. " has removed their $" .. Bounty .. " bounty on " .. AffectedPlayer:GetName())
						mySelf:SendChatMessage("You have removed the $" .. self:Commas(Bounty) .. " bounty you had placed on " .. AffectedPlayer:GetName() .. ".", SuccessColor )
					else
						mySelf:SendChatMessage("You have not placed a bounty on " .. AffectedPlayer:GetName() .. ".", NoticeColor )
					end
				else
					mySelf:SendChatMessage(BountyDelElseMessage, NoticeColor )
				end
			elseif msg[2] == "stats" then
				local PlayerBounty		=	self:CheckTotalBounty(mySelf)
				if PlayerBounty then
					mySelf:SendChatMessage("You have a $" .. PlayerBounty .. " Bounty on your head!", NoticeColor )
				else
					mySelf:SendChatMessage("You do not currently have a Bounty.", NoticeColor )
				end
				local PlayerBountyScore	=	self:GetBountyStats(mySelf)
				if PlayerBountyScore then
					mySelf:SendChatMessage("Your Bounty Score is: " .. PlayerBountyScore.Claimed .. " Claimed and " .. PlayerBountyScore.Set .. " Set!", NoticeColor )
				end
			elseif msg[2] == "exstats" then
				if msg[3] != false and msg[3] != nil then
					PlayerStatPage = tonumber(msg[3])
					PlayerStats = self:GetExtendedBountyStatsPages(mySelf, PlayerStatPage - 1)
				else 
					PlayerStatPage = 1
					PlayerStats = self:GetExtendedBountyStats(mySelf)
				end
				if PlayerStats != false then 
					mySelf:SendChatMessage(AlertBracket .. " Bounties set by you. Page " .. PlayerStatPage .. " " .. AlertBracket, NoticeColor )
					for i = 1, #PlayerStats do
						if i == 11 then
							mySelf:SendChatMessage("Say /bounty exstats " .. (PlayerStatPage + 1) .." to get the next page", NoticeColor )
							break
						else
							mySelf:SendChatMessage(i .. ". " .. PlayerStats[i].targetname .. " : $" .. PlayerStats[i].bounty, NoticeColor )
						end
					end
				else
					mySelf:SendChatMessage("There is nothing to show.", NoticeColor )
				end
			else
				mySelf:SendChatMessage("Invalid Command given.", NoticeColor )
			end
		else
			mySelf:SendChatMessage(BountySetElseMessage, NoticeColor )
			mySelf:SendChatMessage(BountyDelElseMessage, NoticeColor )
			mySelf:SendChatMessage("Usage: '/bounty stats' to see your Bounty Score.", NoticeColor )
			mySelf:SendChatMessage("Usage: '/bounty exstats' to see the bounties set by you.", NoticeColor )
		end
	end
end

function BountyManager:GetPlayerByTableInput(tableinput, number, requester)
	local number = tonumber(number)
--	print("Drop " .. number .. " table entries.")
	local i = 1
	while i <= number do
--		print("Dropped table Input:",tableinput[1])
		table.remove(tableinput, 1)
		i = i + 1
	end
	if tableinput[#tableinput] ~= "" then
	else
	table.remove(tableinput, #tableinput)
	end
	local names = ""
	for k, v in pairs(tableinput) do
		names = names .. " " .. v
--		print("Name: " .. names)
	end
	local PlayerFullNameObject = names:gsub("^%s*(.-)%s*$", "%1")
--	print("Full Name: |" .. PlayerFullNameObject.."|")
	if PlayerFullNameObject then
		for p in Server:GetPlayers() do
			if PlayerFullNameObject == p:GetName() then
				return p
			end
		end
	end
	--	Attempt to find a name by partial match.
	local MatchAttempt	=	Player.Match(PlayerFullNameObject)
	if table.count(MatchAttempt) > 0 then
		if table.count(MatchAttempt) > 1 then
			local NamesString	=	""
			for _, possibleplayers in ipairs(MatchAttempt) do
				NamesString = NamesString .. possibleplayers:GetName() .. ", "
			end
			requester:SendChatMessage("There is more than one player with '" .. PlayerFullNameObject .. "' in their name, please type their full name for clarity.", NoticeColor)
			requester:SendChatMessage("Candidates: " .. NamesString, NoticeColor)
			return false
		else
			return MatchAttempt[1]
		end
	end
	requester:SendChatMessage("No player found with the name '" .. PlayerFullNameObject .. "'. Please try typing part of their name and then hitting the TAB key to auto-complete it.", NoticeColor)
	return false
end

function BountyManager:EmptyFunction()

end

function BountyManager:Commas(num)
  assert (type (num) == "number" or
          type (num) == "string")
  
  local result = ""
  local sign, before, after =
    string.match (tostring (num), "^([%+%-]?)(%d*)(%.?.*)$")
  while string.len (before) > 3 do
    result = "," .. string.sub (before, -3, -1) .. result
    before = string.sub (before, 1, -4)  -- remove last 3 digits
  end
  return sign .. before .. result .. after
end

BountyManager = BountyManager()