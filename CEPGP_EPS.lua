local addonName, addon = ...

local origDecayEP;

CEPGP_EPS = {
	enabled = true,
	amount = 0
};

function CEPGP_EPS_calculateMaximumEP()
	if (CEPGP_Info.IgnoreUpdates == false) then
		-- Delay before trying to read the decayed EP, otherwise the highestEP
		-- found may be wrong and no players will be updated correctly.

		C_Timer.After(2, function()
			local highestEP = 0;
			local temp = {};
			local i = 0;
		
			for k, _ in pairs(CEPGP_roster) do
				table.insert(temp, k);
			end

			C_Timer.NewTicker(0.0001, function()
				i = i + 1;
				local name = temp[i];
				local index = CEPGP_getIndex(name);
				local EP, GP = CEPGP_getEPGP(name, index);

				-- CEPGP_print(name .. ": " .. tostring(EP));

				if (EP > highestEP) then highestEP = EP; end

				if i == #temp then
					CEPGP_EPS_updateMaximumEP(highestEP);
				end
			end, #temp)
		end);
	else
		C_Timer.After(0.5, function()
		-- CEPGP_print("Waiting for decay to complete");
		CEPGP_EPS_calculateMaximumEP();
		end);
	end
end

function CEPGP_EPS_updateMaximumEP(highestEP)
	CEPGP_print("Highest EP: " .. tostring(highestEP));

	local temp = {};
	local i = 0;
	local maximumEP = highestEP - CEPGP_EPS.amount;
	local affectedPlayers = 0;
	
	for k, _ in pairs(CEPGP_roster) do
		table.insert(temp, k);
	end

	CEPGP_print("Updating maximum EP to: " .. tostring(maximumEP));

	C_Timer.After(0.1, function()
		C_Timer.NewTicker(0.0001, function()
			i = i + 1;
			local name = temp[i];
			local index = CEPGP_getIndex(name);
			local main = CEPGP_getMain(name);
			local EP, GP = CEPGP_getEPGP(name, index);

			if (EP > maximumEP and not main) then
				affectedPlayers = affectedPlayers + 1;
				GuildRosterSetOfficerNote(index, maximumEP .. "," .. GP);
			end

			if i == #temp then
				C_Timer.After(2, function()
					for name, _ in pairs(CEPGP.Alt.Links) do
						CEPGP_syncAltStandings(name);
					end
				end);

				local message = "Smoothed EP from " .. tostring(highestEP) .. " to " .. tostring(maximumEP) .. ". " .. affectedPlayers .. " affected players"

				CEPGP_print("Smoothing has completed");
				CEPGP_addTraffic("Guild", UnitName("player"), message);
				CEPGP_sendChatMessage(message, CEPGP.Channel);
			end
		end, #temp)
	end);
end

-- Hook original AddRaidEP function

function CEPGP_EPS_hook()
	origDecayEP = CEPGP_decay;
	CEPGP_decay = function(...)
		local amount, reason, EP, GP, fixed = ...;

		origDecayEP(tonumber(amount), reason, EP, GP, fixed);

		if (CEPGP_EPS.enabled and CEPGP_EPS.smoothAfterDecay) then
			-- Delay before attempting to calculate maximum EP and then updating players.
			-- Delay ensures the decay has started before starting to try and update it.

			C_Timer.After(1, function()
				CEPGP_EPS_calculateMaximumEP();
			end);
		end
	end
end

function CEPGP_EPS_initialise()

	-- Initialise saved variables

	if CEPGP_EPS.enabled == nil then
		CEPGP_EPS.enabled = true;
	end

	if CEPGP_EPS.amount == nil then
		CEPGP_EPS.amount = 0;
	end

	if CEPGP_EPS.enabled then
		_G["CEPGP_EPS_decay_popup"]:Show();
	else
		_G["CEPGP_EPS_decay_popup"]:Hide();
	end

	if CEPGP_EPS.smoothAfterDecay then
		CEPGP_EPS_decay_smooth_check:SetChecked(true);
	else
		CEPGP_EPS_decay_smooth_check:SetChecked(false);
	end

	-- Create interface options panel

	panel = CreateFrame("FRAME");
	panel.name = "CEPGP EP Smoothing";

	local titleText = panel:CreateFontString("CEPGP_EPS_titleText", "OVERLAY", "GameFontNormalLarge");
	titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -15);
	titleText:SetText("CEPGP EP Smoothing");

	local smoothAmountLabel = panel:CreateFontString("CEPGP_EPS_smoothAmountLabel", "OVERLAY", "GameFontNormal");
	smoothAmountLabel:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -10);
	smoothAmountLabel:SetTextColor(1,1,1);
	smoothAmountLabel:SetText("Smooth Amount");

	local smoothAmountText = CreateFrame('EditBox', "CEPGP_EPS_smoothAmountText", panel, "InputBoxTemplate");
	smoothAmountText:SetAutoFocus(false);
	smoothAmountText:SetPoint("TOP", smoothAmountLabel, "BOTTOM", 0, -5);
	smoothAmountText:SetHeight(20);
	smoothAmountText:SetWidth(75);
	smoothAmountText:SetText(tostring(CEPGP_EPS.amount));
	smoothAmountText:SetCursorPosition(0);

	smoothAmountText:SetScript("OnEnter", function()
		GameTooltip:SetOwner(smoothAmountText, "ANCHOR_TOPLEFT");
		GameTooltip:SetText("This amount will be subtracted from the highest guild EP after decay, any players above that value will be updated to that value.");
	end)

	smoothAmountText:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end)

	smoothAmountText:SetScript("OnEditFocusLost", function()
		smoothAmountText:HighlightText(0,0);
		local value = smoothAmountText:GetText();

		if not CEPGP_isNumber(value) then
			CEPGP_print("Smooth amount must contain numbers only", true);
			smoothAmountText:SetText(tostring(0));
		elseif value == "" then
			CEPGP_print("Smooth amount cannot be blank", true);
			smoothAmountText:SetText(tostring(0));
		elseif 0 > tonumber(smoothAmountText:GetText()) then
			CEPGP_print("Smooth amount must be a positive number", true);
			smoothAmountText:SetText(tostring(0));
		elseif CEPGP_EPS.amount == tonumber(value) then
			return;
		end
		
		CEPGP_EPS.amount = tonumber(value);
		CEPGP_print("Updated smooth amount");
	end)

	InterfaceOptions_AddCategory(panel);

	-- Register plugin with CEPGP

	CEPGP_addPlugin(addonName, panel, CEPGP_EPS.enabled, function()
		if CEPGP_EPS.enabled then
			_G["CEPGP_EPS_decay_popup"]:Hide();
			CEPGP_EPS.enabled = false;
		else
			_G["CEPGP_EPS_decay_popup"]:Show();
			CEPGP_EPS.enabled = true;
		end
	end);

	CEPGP_EPS_hook();
end

function CEPGP_EPS_OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "CEPGP_EPS" then
		CEPGP_EPS_initialise();
	end
end

function CEPGP_EPS_createFrames()
	local CEPGP_EPS_frame = CreateFrame("Frame", "CEPGP_EPS_decay_popup", _G["CEPGP_decay_popup"]);
	CEPGP_EPS_frame:SetScale(1.0);
	fontString = CEPGP_EPS_frame:CreateFontString("CEPGP_EPS_textFrame", "OVERLAY", "GameFontNormal");
	fontString:SetPoint("LEFT", "CEPGP_decay_popup_fixed_check", "RIGHT", 5, 0);
	fontString:SetText("Smooth after Decay: ");

	local checkFrame = CreateFrame("CheckButton", "CEPGP_EPS_decay_smooth_check", CEPGP_EPS_frame, "UIOptionsCheckButtonTemplate");
	checkFrame:SetPoint("LEFT", "CEPGP_EPS_textFrame", "RIGHT", 5, 0);
	checkFrame:SetScript("OnClick",function() if _G["CEPGP_EPS_decay_smooth_check"]:GetChecked() then
												CEPGP_EPS.smoothAfterDecay = true;
											  else
												CEPGP_EPS.smoothAfterDecay = false;
											  end
								   end);
	
	CEPGP_EPS_frame:RegisterEvent("ADDON_LOADED");
	CEPGP_EPS_frame:SetScript("OnEvent", CEPGP_EPS_OnEvent);
end

CEPGP_EPS_createFrames();
