-- Version 6.0.2
-- (Perhaps) Fixed for Warlords of Draenor (Patch 6.0.2)
-- (Perhaps) Cleaned up codebase
-- (Perhaps) Added in the ability to start and stop rolls via chat
-- (TODO) Add in ability to remotely start and stop rolls via whisper or a global channel
-- (TODO) Change reset button to roll type button
-- (TODO) Add in suicide rolls


-- Version 5.4.7
-- (Subrand0m) Fixed for WoW 5.4.7
-- (Subrand0m) Rebuilt Layout
-- (Subrand0m) Added in Reset button for Stats

-- Version 4.20
-- (Karatebear) no longer lists as out of date addon
-- (Karatebear) changed button fake/real to raid/party to use in respective group chat selection instead
-- (Karatebear, Chaos) /gcg ban <name>, /gcg unban <name>; blocks or unblocks entries from specified user /listban; lists banned users
-- (Karatebear, Chaos) tiebreaker bug fixed

-- Ropetown changelog:
--   #2 :
--     /gcg show|hide will save between sessions
--     added [x] in corner for quick close (will reshow on next reload, or can /gcg show)
--     stats now do top/bottom 5
--     real/fake roll selection button
--     strictly only accept "1" (rather than "1 " and other various "1xx" non-"1" strings
--     accept "-1" to withdraw from a roll (only before rolls are locked in via "Roll now!")
--     many bug fixes / interface improvements
--     @gcg name in RAID or WHISPER to check an individual person's stats
--     /gcg joinstats [main] [alt] to include alt's win/losses with main
--     /gcg unjoinstats [alt]
--   #1 :
--     updated for cata
--     added stats
--     fixed savedvariables to actually save the variables

-- GCGambler by Myrx and Triumvirate of <Gentlemens Club> Korgath US

-- Version 0.2
-- (Myrx) Fixed a bug where minimum roll value was not being checked
-- (Myrx) Fixed a bug where you could start a game of 1-1
-- (Myrx) Added logic to prompt for tiebreakers
-- (TODO) Every player ties

-- Version 0.1
-- Initial release version

local AcceptOnes = "false";
local AcceptRolls = "false";
local totalrolls = 0;
local tierolls = 0;
local theMax;
local lowname = "";
local highname = "";
local low = 0;
local high = 0;
local tie = 0;
local highbreak = 0;
local lowbreak = 0;
local tiehigh = 0;
local tielow = 0;
local chatmethod = "PARTY";
local whispermethod = false;
local totalentries = 0;
local highplayername = "";
local lowplayername = "";
local allowWhispers = false;
local ones = false;

-- LOAD FUNCTION --
function GCGambler_OnLoad(this)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffff00<Gentlemen's Club Gambler v6.0.2> loaded /gcg to use");

	this:RegisterEvent("CHAT_MSG_RAID");
	this:RegisterEvent("CHAT_MSG_RAID_LEADER");
	this:RegisterEvent("CHAT_MSG_PARTY");
	this:RegisterEvent("CHAT_MSG_PARTY_LEADER");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("CHAT_MSG_WHISPER");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	
	this:RegisterForDrag("LeftButton");

	GCGambler_ROLL_Button:Disable();
	GCGambler_AcceptOnes_Button:Enable();		
	GCGambler_LASTCALL_Button:Disable();
	GCGambler_CHAT_Button:Enable();
end


function GCGambler_OnEvent(self, event, ...)

	-- LOADS ALL DATA FOR INITIALIZATION OF ADDON --
	arg1,arg2 = ...;
	if (event == "PLAYER_ENTERING_WORLD") then
		GCGambler_EditBox:SetJustifyH("CENTER");

		if(not GCGambler) then
			GCGambler = {
				["active"] = 1, 
				["chat"] = false, 
				["whispers"] = false, 
				["strings"] = { },
				["lowtie"] = { },
				["hightie"] = { },
				["bans"] = { }
			}
		end
		if(not GCGambler["lastroll"]) then GCGambler["lastroll"] = 100; end
		if(not GCGambler["stats"]) then GCGambler["stats"] = { }; end
		if(not GCGambler["joinstats"]) then GCGambler["joinstats"] = { }; end
		if(not GCGambler["chat"]) then GCGambler["chat"] = false; end
		if(not GCGambler["whispers"]) then GCGambler["whispers"] = false; end
		if(not GCGambler["bans"]) then GCGambler["bans"] = { }; end

		GCGambler_EditBox:SetText(""..GCGambler["lastroll"]);

		if(GCGambler["chat"] == false) then
			GCGambler_CHAT_Button:SetText("Party");
			chatmethod = "PARTY";
		else
			GCGambler_CHAT_Button:SetText("Raid");
			chatmethod = "RAID";
		end

		if(GCGambler["whispers"] == false) then
			GCGambler_WHISPER_Button:SetText("No Whispers");
			whispermethod = false;
		else
			GCGambler_WHISPER_Button:SetText("Whispers");
			whispermethod = true;
		end

		if(GCGambler["active"] == 1) then
			GCGambler_Frame:Show();
		else
			GCGambler_Frame:Hide();
		end
	end

	-- IF IT'S A RAID MESSAGE... --
	if ((event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_RAID") and AcceptOnes=="true" and GCGambler["chat"] == true) then
		
		-- ADDS USER TO THE ROLL POOL - CHECK TO MAKE SURE THEY ARE NOT BANNED --
		if (arg1 == "1") then
			if(GCGambler_ChkBan(tostring(arg2)) == 0) then
				GCGambler_Add(tostring(arg2));
				if (not GCGambler_LASTCALL_Button:IsEnabled() and totalrolls == 1) then
					GCGambler_LASTCALL_Button:Enable();
				end
				if totalrolls == 2 then
					GCGambler_AcceptOnes_Button:Disable();
					GCGambler_AcceptOnes_Button:SetText("Open Entry");
				end
			else
				SendChatMessage("Unable to accept entry. No pay, no play. Got it?", chatmethod);
			end

		elseif(arg1 == "-1") then
			GCGambler_Remove(tostring(arg2));
			if (GCGambler_LASTCALL_Button:IsEnabled() and totalrolls == 0) then
				GCGambler_LASTCALL_Button:Disable();
			end
			if totalrolls == 1 then
				GCGambler_AcceptOnes_Button:Enable();
				GCGambler_AcceptOnes_Button:SetText("Open Entry");
			end
		end
	end

	if ((event == "CHAT_MSG_PARTY_LEADER" or event == "CHAT_MSG_PARTY")and AcceptOnes=="true" and GCGambler["chat"] == false) then
		-- ADDS USER TO THE ROLL POOL - CHECK TO MAKE SURE THEY ARE NOT BANNED --
		if (arg1 == "1") then
			-- SendChatMessage(arg2,chatmethod,GetDefaultLanguage("player"));
			if(GCGambler_ChkBan(tostring(arg2)) == 0) then
				GCGambler_Add(tostring(arg2));
				if (not GCGambler_LASTCALL_Button:IsEnabled() and totalrolls == 1) then
					GCGambler_LASTCALL_Button:Enable();
				end
				if totalrolls == 2 then
					GCGambler_AcceptOnes_Button:Disable();
					GCGambler_AcceptOnes_Button:SetText("Open Entry");
				end
			else
				SendChatMessage("You are banned! No pay, no play!", chatmethod);
			end

		elseif(arg1 == "-1") then
			GCGambler_Remove(tostring(arg2));
			if (GCGambler_LASTCALL_Button:IsEnabled() and totalrolls == 0) then
				GCGambler_LASTCALL_Button:Disable();
			end
			if totalrolls == 1 then
				GCGambler_AcceptOnes_Button:Enable();
				GCGambler_AcceptOnes_Button:SetText("Open Entry");
			end
		end
	end

	if (event == "CHAT_MSG_SYSTEM" and AcceptRolls=="true") then
		local temp1 = tostring(arg1);
		GCGambler_ParseRoll(temp1);		
	end

	if (event == "CHAT_MSG_WHISPER" and allowWhispers == true) then
		GCGambler_Whisper_Commands(arg1, arg2);
	end
end


function GCGambler_ResetStats()
	GCGambler["stats"] = { };
end


function GCGambler_OnClickCHAT()
	if(GCGambler["chat"] == nil) then GCGambler["chat"] = false; end

	GCGambler["chat"] = not GCGambler["chat"];
	
	if(GCGambler["chat"] == false) then
		GCGambler_CHAT_Button:SetText("Party");
		chatmethod = "PARTY";
	else
		GCGambler_CHAT_Button:SetText("Raid");
		chatmethod = "RAID";
	end
end

function GCGambler_OnClickWHISPERS()
	if(GCGambler["whispers"] == nil) then GCGambler["whispers"] = false; end

	GCGambler["whispers"] = not GCGambler["whispers"];
	
	if(GCGambler["whispers"] == false) then
		GCGambler_WHISPER_Button:SetText("No Whispers");
		whispermethod = false;
	else
		GCGambler_WHISPER_Button:SetText("Whispers");
		whispermethod = true;
	end
end

function GCGambler_JoinStats(msg)
	local i = string.find(msg, " ");
	if((not i) or i == -1 or string.find(msg, "[", 1, true) or string.find(msg, "]", 1, true)) then
		ChatFrame1:AddMessage("Usage: /gcg joinstats mainname altname");
		return;
	end
	local mainname = string.sub(msg, 1, i-1);
	local altname = string.sub(msg, i+1);
	ChatFrame1:AddMessage(string.format("Joined alt '%s' -> main '%s'", altname, mainname));
	GCGambler["joinstats"][altname] = mainname;
end

function GCGambler_UnjoinStats(altname)
	if(altname ~= nil and altname ~= "") then
		ChatFrame1:AddMessage(string.format("Unjoined alt '%s' from any other characters", altname));
		GCGambler["joinstats"][altname] = nil;
	else
		local i, e;
		for i, e in pairs(GCGambler["joinstats"]) do
			ChatFrame1:AddMessage(string.format("currently joined: alt '%s' -> main '%s'", i, e));
		end
	end
end

function GCGambler_OnClickSTATS()
	local sortlistname = {};
	local sortlistamount = {};
	local n = 0;
	local i, j, k;

	for i, j in pairs(GCGambler["stats"]) do
		local name = i;
		if(GCGambler["joinstats"][strlower(i)] ~= nil) then
			name = GCGambler["joinstats"][strlower(i)]:gsub("^%l", string.upper);
		end
		for k=0,n do
			if(k == n) then
				sortlistname[n] = name;
				sortlistamount[n] = j;
				n = n + 1;
				break;
			elseif(strlower(name) == strlower(sortlistname[k])) then
				sortlistamount[k] = (sortlistamount[k] or 0) + j;
				break;
			end
		end
	end

	if(n == 0) then
		DEFAULT_CHAT_FRAME:AddMessage("No stats yet!!");
		return;
	end

	for i = 0, n-1 do
		for j = i+1, n-1 do
			if(sortlistamount[j] > sortlistamount[i]) then
				sortlistamount[i], sortlistamount[j] = sortlistamount[j], sortlistamount[i];
				sortlistname[i], sortlistname[j] = sortlistname[j], sortlistname[i];
			end
		end
	end

	SendChatMessage("--- GCGambler Stats ---", chatmethod);

	local x1 = 5-1;
	local x2 = n-5;
	if(x1 >= n) then x1 = n-1; end
	if(x2 <= x1) then x2 = x1+1; end

	for i = 0, x1 do
		sortsign = "won";
		if(sortlistamount[i] < 0) then sortsign = "lost"; end
		SendChatMessage(string.format("%d.  %s %s %d total", i+1, sortlistname[i], sortsign, math.abs(sortlistamount[i])), chatmethod);
	end

	if(x1+1 < x2) then
		SendChatMessage("...", chatmethod);
	end

	for i = x2, n-1 do
		sortsign = "won";
		if(sortlistamount[i] < 0) then sortsign = "lost"; end
		SendChatMessage(string.format("%d.  %s %s %d total", i+1, sortlistname[i], sortsign, math.abs(sortlistamount[i])), chatmethod);
	end
end


function GCGambler_OnClickROLL()
  -- TODO Add in check for suicideRoll
	if (totalrolls > 0 and AcceptRolls == "true") then
		if table.getn(GCGambler.strings) ~= 0 then
			GCGambler_List();
		end	
		return;
	end
	if (totalrolls >1) then
		AcceptOnes = "false";
		AcceptRolls = "true";
		if (tie == 0) then
			SendChatMessage("[Gold Rolls] Roll now!",chatmethod,GetDefaultLanguage("player"));
		end

		if (lowbreak == 1) then
			SendChatMessage(format("%s%d%s", "[Gold Rolls] Low end tiebreaker! Roll 1-", theMax, " now!"),chatmethod,GetDefaultLanguage("player"));
			GCGambler_List();
		end

		if (highbreak == 1) then
			SendChatMessage(format("%s%d%s", "[Gold Rolls] High end tiebreaker! Roll 1-", theMax, " now!"),chatmethod,GetDefaultLanguage("player"));
			GCGambler_List();
		end

		GCGambler_EditBox:ClearFocus();

	end

	if (AcceptOnes == "true" and totalrolls <2) then
		SendChatMessage("[Gold Rolls] Need more!",chatmethod,GetDefaultLanguage("player"));
	end
end

function GCGambler_OnClickLASTCALL()
	SendChatMessage("[Gold Rolls] Last Chance!",chatmethod,GetDefaultLanguage("player"));
	GCGambler_EditBox:ClearFocus();
	GCGambler_LASTCALL_Button:Disable();
	GCGambler_ROLL_Button:Enable();
end

function GCGambler_OnClickACCEPTONES()
	if GCGambler_EditBox:GetText() ~= "" and GCGambler_EditBox:GetText() ~= "1" then
		GCGambler_Reset();
		GCGambler_ROLL_Button:Disable();
		GCGambler_LASTCALL_Button:Disable();
		AcceptOnes = "true";
		local fakeroll = "";
		SendChatMessage(format("%s%s%s%s", "[Gold Rolls] Roll 1-", GCGambler_EditBox:GetText(), " Press 1  (-1 to withdraw)", fakeroll),chatmethod,GetDefaultLanguage("player"));
		GCGambler["lastroll"] = GCGambler_EditBox:GetText();
		theMax = tonumber(GCGambler_EditBox:GetText()); 
		low = theMax+1;
		tielow = theMax+1;
		GCGambler_EditBox:ClearFocus();
		GCGambler_AcceptOnes_Button:SetText("New Game");
		GCGambler_LASTCALL_Button:Disable();	
	else
		message("Please enter a number to roll from.");
	end
end

function GCGambler_Report()
	local goldowed = high - low
	if (goldowed ~= 0) then
		lowname = lowname:gsub("^%l", string.upper)
		highname = highname:gsub("^%l", string.upper)
		local string3 = strjoin(" ", "[Gold Rolls]", lowname, "owes", highname, goldowed,"gold.")

		GCGambler["stats"][highname] = (GCGambler["stats"][highname] or 0) + goldowed;
		GCGambler["stats"][lowname] = (GCGambler["stats"][lowname] or 0) - goldowed;
	
		SendChatMessage(string3,chatmethod,GetDefaultLanguage("player"));
	else
		SendChatMessage("It was a tie! No one wins!",chatmethod,GetDefaultLanguage("player"));
	end
	GCGambler_Reset();
	GCGambler_AcceptOnes_Button:SetText("Open Entry");
	GCGambler_CHAT_Button:Enable();
end

function GCGambler_Tiebreaker()
	--Everyone has rolled at this point
	tierolls = 0;
	totalrolls = 0;
	tie = 1;
	if table.getn(GCGambler.lowtie) == 1 then
		GCGambler.lowtie = {};
	end
	if table.getn(GCGambler.hightie) == 1 then
		GCGambler.hightie = {};
	end
	totalrolls = table.getn(GCGambler.lowtie) + table.getn(GCGambler.hightie);
	tierolls = totalrolls;
	if (table.getn(GCGambler.hightie) == 0 and table.getn(GCGambler.lowtie) == 0) then
		GCGambler_Report();
	else
		AcceptRolls = "false";
		if table.getn(GCGambler.lowtie) > 0 then
			lowbreak = 1;
			highbreak = 0;
			tielow = theMax+1;
			tiehigh = 0;
			GCGambler.strings = GCGambler.lowtie;
			GCGambler.lowtie = {};
			GCGambler_OnClickROLL();			
		end
		if table.getn(GCGambler.hightie) > 0  and table.getn(GCGambler.strings) == 0 then
			lowbreak = 0;
			highbreak = 1;
			tielow = theMax+1;
			tiehigh = 0;
			GCGambler.strings = GCGambler.hightie;
			GCGambler.hightie = {};
			GCGambler_OnClickROLL();
		end
	end
end

function GCGambler_ParseRoll(temp2)
	local temp1 = strlower(temp2);
	-- SendChatMessage(temp1,chatmethod,GetDefaultLanguage("player"));
	local player, junk, roll, range = strsplit(" ", temp1);
	-- SendChatMessage(GCGambler_Check(player),chatmethod,GetDefaultLanguage("player"));
	-- SendChatMessage(player,chatmethod,GetDefaultLanguage("player"));
	if junk == "rolls" and GCGambler_Check(player)==1 then
		minRoll, maxRoll = strsplit("-",range);
		minRoll = tonumber(strsub(minRoll,2));
		maxRoll = tonumber(strsub(maxRoll,1,-2));
		roll = tonumber(roll);
		if (maxRoll == theMax and minRoll == 1) then
			if (tie == 0) then
				if (roll == high) then
					if table.getn(GCGambler.hightie) == 0 then
						GCGambler_AddTie(highname, GCGambler.hightie);
					end
					GCGambler_AddTie(player, GCGambler.hightie);
				end
				if (roll>high) then
					highname = player
					highplayername = player
					if (high == 0) then
						high = roll
						if (whispermethod) then
							SendChatMessage(string.format("You have the HIGHEST roll so far: %s and you might win a max of %sg", roll, (high - 1)),"WHISPER",GetDefaultLanguage("player"),player);
						end
					else
						high = roll
						if (whispermethod) then
							SendChatMessage(string.format("You have the HIGHEST roll so far: %s and you might win %sg from %s", roll, (high - low), lowplayername),"WHISPER",GetDefaultLanguage("player"),player);
							SendChatMessage(string.format("%s now has the HIGHEST roller so far: %s and you might owe him/her %sg", player, roll, (high - low)),"WHISPER",GetDefaultLanguage("player"),lowplayername);
						end
					end
						-- SendChatMessage(low,chatmethod,GetDefaultLanguage("player"));
						-- SendChatMessage(high,chatmethod,GetDefaultLanguage("player"));
					GCGambler.hightie = {};
					--GCGambler_AddTie(player, GCGambler.hightie);				
				end
				if (roll == low) then
					if table.getn(GCGambler.lowtie) == 0 then
						GCGambler_AddTie(lowname, GCGambler.lowtie);
					end
					GCGambler_AddTie(player, GCGambler.lowtie);
				end
				if (roll<low) then 
					lowname = player
					lowplayername = player
					low = roll
					if (high ~= low) then
						if (whispermethod) then
							SendChatMessage(string.format("You have the LOWEST roll so far: %s and you might owe %s %sg ", roll, highplayername, (high - low)),"WHISPER",GetDefaultLanguage("player"),player);
						end
					end
					GCGambler.lowtie = {};				
					--GCGambler_AddTie(player, GCGambler.lowtie);				
				end
			else
				if (lowbreak == 1) then
					if (roll == tielow) then
						
						if table.getn(GCGambler.lowtie) == 0 then
							GCGambler_AddTie(lowname, GCGambler.lowtie);
						end
						GCGambler_AddTie(player, GCGambler.lowtie);
					end
					if (roll<tielow) then 
						lowname = player
						tielow = roll;
						GCGambler.lowtie = {};				
						--GCGambler_AddTie(player, GCGambler.lowtie);				
					end
				end
				if (highbreak == 1) then
					if (roll == tiehigh) then
						if table.getn(GCGambler.hightie) == 0 then
							GCGambler_AddTie(highname, GCGambler.hightie);
						end
						GCGambler_AddTie(player, GCGambler.hightie);
					end
					if (roll>tiehigh) then
						highname = player
						tiehigh = roll;
						GCGambler.hightie = {};
						--GCGambler_AddTie(player, GCGambler.hightie);				
					end
				end
			end
			GCGambler_Remove(tostring(player));
			totalentries = totalentries + 1;
			
			--local string3 = strjoin(" ", "[GCG]", "Total Entries: ", totalentries, "players.")
			--SendChatMessage(string3,chatmethod,GetDefaultLanguage("player"));

			if table.getn(GCGambler.strings) == 0 then
				if tierolls == 0 then
					GCGambler_Report();
				else
					if totalentries == 2 then
						GCGambler_Report();
					else
						GCGambler_Tiebreaker();
					end
				end
			end
		end	
	end
end

function GCGambler_Check(player)
	for i=1, table.getn(GCGambler.strings) do
		if strlower(GCGambler.strings[i]) == tostring(player) then
			return 1
		end
	end
	return 0
end

function GCGambler_List()
	for i=1, table.getn(GCGambler.strings) do
	  	local string3 = strjoin(" ", "[Gold Rolls]", tostring(GCGambler.strings[i]):gsub("^%l", string.upper),"still needs to roll.")
		SendChatMessage(string3,chatmethod,GetDefaultLanguage("player"));
	end
end

function GCGambler_ListBan()
	--local stringstrt = "|cffffff00"
	--local tempstr = " "
	--local poststr = "|cffffff00Currently Banned: "
	local bancnt = 0;
	DEFAULT_CHAT_FRAME:AddMessage("Current Bans:");
	for i=1, table.getn(GCGambler.bans) do
		--tempstr = strjoin(tempstr,"[", tostring(GCGambler.bans[i]), "] ")
		bancnt = 1;
		DEFAULT_CHAT_FRAME:AddMessage(strjoin("|cffffff00", "...", tostring(GCGambler.bans[i])));
	end
	--poststr = strjoin(poststr, tempstr)
	if (bancnt == 0) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00If all our friends were like yours we'd have no one on our ban list either.");
	--else
		--DEFAULT_CHAT_FRAME:AddMessage(poststr);
	end
end

function GCGambler_Add(name)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	-- SendChatMessage(charname,chatmethod,GetDefaultLanguage("player"));
	-- SendChatMessage(realmname,chatmethod,GetDefaultLanguage("player"));
	if (insname ~= nil or insname ~= "") then
		local found = 0;
		for i=1, table.getn(GCGambler.strings) do
		  	if GCGambler.strings[i] == insname then
				found = 1;
			end
        	end
		if found == 0 then
		      	table.insert(GCGambler.strings, insname)
			totalrolls = totalrolls+1
		end
	end
end

function GCGambler_ChkBan(name)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	if (insname ~= nil or insname ~= "") then
		for i=1, table.getn(GCGambler.bans) do
			if strlower(GCGambler.bans[i]) == strlower(insname) then
				return 1
			end
		end
	end
	return 0
end

function GCGambler_AddBan(name)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	if (insname ~= nil or insname ~= "") then
		local banexist = 0;
		for i=1, table.getn(GCGambler.bans) do
			if GCGambler.bans[i] == insname then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Unable to add to ban list - user already banned.");
				banexist = 1;
			end
		end
		if (banexist == 0) then
			table.insert(GCGambler.bans, insname)
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff00User is now banned!");
			local string3 = strjoin(" ", "[Gold Rolls]", "User Banned from rolling! -> ",insname, "!")
			--SendChatMessage(string3,chatmethod,GetDefaultLanguage("player"));
			DEFAULT_CHAT_FRAME:AddMessage(strjoin("|cffffff00", string3));
			--local string3 = strjoin(" ", "[GCG]", "Total Entries: ", totalentries, "players.")
			--SendChatMessage(string3,chatmethod,GetDefaultLanguage("player"));
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Error: No name provided.");
	end
end

function GCGambler_RemoveBan(name)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	if (insname ~= nil or insname ~= "") then
		--local banexist = 0;
		for i=1, table.getn(GCGambler.bans) do
			if strlower(GCGambler.bans[i]) == strlower(insname) then
				table.remove(GCGambler.bans, i)
				DEFAULT_CHAT_FRAME:AddMessage("|cffffff00User removed from ban successfully.");
				return;
			end
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Error: No name provided.");
	end
end
				
function GCGambler_AddTie(name, tietable)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	if (insname ~= nil or insname ~= "") then
		local found = 0;
		for i=1, table.getn(tietable) do
		  	if tietable[i] == insname then
				found = 1;
			end
        	end
		if found == 0 then
		    table.insert(tietable, insname)
			tierolls = tierolls+1	
			totalrolls = totalrolls+1		
		end
	end
end

function GCGambler_Remove(name)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	for i=1, table.getn(GCGambler.strings) do
		if GCGambler.strings[i] ~= nil then
		  	if strlower(GCGambler.strings[i]) == strlower(insname) then
				table.remove(GCGambler.strings, i)
				totalrolls = totalrolls - 1;
			end
		end
      end
end

function GCGambler_RemoveTie(name, tietable)
	local charname, realmname = strsplit("-",name);
	local insname = strlower(charname);
	for i=1, table.getn(tietable) do
		if tietable[i] ~= nil then
		  	if strlower(tietable[i]) == insname then
				table.remove(tietable, i)
			end
		end
      end
end

function GCGambler_Reset()
		GCGambler["strings"] = { };
		GCGambler["lowtie"] = { };
		GCGambler["hightie"] = { };
		AcceptOnes = "false"
		AcceptRolls = "false"
		totalrolls = 0
		theMax = 0
		tierolls = 0;
		lowname = ""
		highname = ""
		low = theMax
		high = 0
		tie = 0
		highbreak = 0;
		lowbreak = 0;
		tiehigh = 0;
		tielow = 0;
		totalentries = 0;
		highplayername = "";
		lowplayername = "";
		GCGambler_ROLL_Button:Disable();
		GCGambler_AcceptOnes_Button:Enable();		
		GCGambler_LASTCALL_Button:Disable();
		GCGambler_CHAT_Button:Enable();
end

function GCGambler_EditBox_OnLoad()
	GCGambler_EditBox:SetNumeric(true);
	GCGambler_EditBox:SetAutoFocus(false);
end

function GCGambler_Whisper_Commands(msg, whispTar)
	local msg = msg:lower()
	local err;
	--Start Whisper Checks
	if(string.sub(msg, 1, 12) == "gcgstartroll") and ones == false and GCGambler_AcceptOnes_Button:GetText() ~= "New Game" then
		local rollAmount = string.sub(msg, 13, string.len(msg));
		-- We want to parse the roll to a number if it is so.
		if tonumber(rollAmount) ~= nil then
			rollAmount = tonumber(rollAmount);
		else
			err = rollAmount;
			rollAmount = "";
		end
		--Start roll if it is a valid amount to roll to
		if rollAmount ~= "" and rollAmount ~= "1" and rollAmount ~="0" then
			GCGambler_EditBox:SetText(rollAmount);
			GCGambler_OnClickACCEPTONES();
		--Otherwise let the player know they input an invalid roll
		else
			SendChatMessage(format("%s%s%s","Invalid roll amount, ", err, ". Please use gcgstartroll <roll amount>"), "WHISPER", GetDefaultLanguage("player"), whispTar);
		end
	elseif(string.sub(msg, 1, 12) == "gcgstartroll") and (ones == true or GCGambler_AcceptOnes_Button:GetText() == "New Game") then
		SendChatMessage("Please wait for the current game to end.", "WHISPER", GetDefaultLanguage("player"), whispTar);
	end
	--TODO: Add some method of error checking to make sure roll has started before doing these two.
		
	if(msg == "gcglastcall") then
		if GCGambler_AcceptOnes_Button:GetText() ~= "New Game" then
		GCGambler_OnClickLASTCALL();
		ones = true;
		else
			SendChatMessage("Please start a new game before doing last call.", "WHISPER", GetDefaultLanguage("player"), whispTar);
			ones = false;
		end
	end
	if(msg == "gcgendroll") then
		if GCGambler_AcceptOnes_Button:GetText() ~= "New Game" and ones == true then
			GCGambler_OnClickROLL();
			ones = false;
		else
			SendChatMessage("Please ensure a game has been started, and last call has been done before ending roll.", "WHISPER", GetDefaultLanguage("player"), whispTar);
		end
	end
	--End Whisper Checks
end

function GCGambler_SlashCmd(msg)
	local msg = msg:lower();
	local msgPrint = 0;
	if (msg == "" or msg == nil) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Following commands for /gcg:");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00show - Shows the frame");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00hide - Hides the frame");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00reset - Resets the AddOn");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00resetstats - Resets the stats");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00joinstats [main] [alt] - Apply [alt]'s win/losses to [main]");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00unjoinstats [alt] - Unjoin [alt]'s win/losses from whomever it was joined to");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00ban - Ban's the user from being able to roll");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00unban - Unban's the user");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00listban - Shows ban list");
		--Chat Line Roll Commands - Start and stop rolls from the chat box
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00acceptones - Starts a roll between 1 and the set amount");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00lastcall - Send out a last call for the current roll");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00roll - Ends the opt in phase for rolling, equivalent to clicking ROLL button");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00startremote - Enables GCG to receive commands via whisper");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00stopremote - Disables GCG to receive commands via whisper");
		--Whisper commands - Start and stop rolls from whispers received
		--DEFAULT_CHAT_FRAME:AddMessage("|cffffff00WHISPER - gcgstartroll <Max Roll>- Starts a roll between 1 and the whispered amount");
		--DEFAULT_CHAT_FRAME:AddMessage("|cffffff00WHISPER - gcglastcall - Send out a last call for the current roll");
		--DEFAULT_CHAT_FRAME:AddMessage("|cffffff00WHISPER - gcgendroll - Ends the opt in phase for rolling, equivalent to clicking ROLL button");
		msgPrint = 1;
	end
	if (msg == "hide") then
		GCGambler_Frame:Hide();
		GCGambler["active"] = 0;
		msgPrint = 1;
	end
	if (msg == "show") then
		GCGambler_Frame:Show();
		GCGambler["active"] = 1;
		msgPrint = 1;
	end
	if (msg == "reset") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00GCG has now been reset");
		GCGambler_Reset();
		GCGambler_AcceptOnes_Button:SetText("Open Entry");
		msgPrint = 1;		
	end
	if (msg == "resetstats") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00GCG stats have now been reset");
		GCGambler_ResetStats();
		msgPrint = 1;
	end
	if (string.sub(msg, 1, 9) == "joinstats") then
		GCGambler_JoinStats(strsub(msg, 11));
		msgPrint = 1;
	end
	if (string.sub(msg, 1, 11) == "unjoinstats") then
		GCGambler_UnjoinStats(strsub(msg, 13));
		msgPrint = 1;
	end

	if (string.sub(msg, 1, 3) == "ban") then
		GCGambler_AddBan(strsub(msg, 5));
		msgPrint = 1;
	end

	if (string.sub(msg, 1, 5) == "unban") then
		GCGambler_RemoveBan(strsub(msg, 7));
		msgPrint = 1;
	end

	if (string.sub(msg, 1, 7) == "listban") then
		GCGambler_ListBan();
		msgPrint = 1;
	end
	--Command Line Checks
	if(msg == "acceptones") then
		GCGambler_OnClickACCEPTONES();
		msgPrint = 1;
	end
	
	if(msg == "lastcall") then
		GCGambler_OnClickLASTCALL();
		msgPrint = 1;
	end
	
	if(msg == "roll") then
		GCGambler_OnClickROLL();
		msgPrint = 1;
	end
	if(msg == "startremote") then
		allowWhispers = true;
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00GCG Remote commands enabled.");
		SendChatMessage("Remote roll commands enabled!",chatmethod,GetDefaultLanguage("player"));
		SendChatMessage("Whisper gcgstartroll <roll amount> to start roll, gcglastcall for last call, and gcgendroll to end roll.",chatmethod,GetDefaultLanguage("player"));

		msgPrint = 1;
	end
	if(msg == "stopremote") then
		allowWhispers = false;
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00GCG Remote commands disabled.");
		SendChatMessage("Remote roll commands disabled!",chatmethod,GetDefaultLanguage("player"));
		msgPrint = 1;
	end	
	--End Command Line Checks
	if(msgPrint == 0) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Invalid argument for command /gcg");
	end
end

SLASH_GCGambler1 = "/gambler";
SLASH_GCGambler2 = "/gcg";
SLASH_GCGambler3 = "/rollgame";
SLASH_GCGambler4 = "/GCGambler";
SlashCmdList["GCGambler"] = GCGambler_SlashCmd
