local mod = SexyCooldown
local math_pow = _G.math.pow
local string_format = _G.string.format
local math_floor = _G.math.floor
local math_fmod = _G.math.fmod
local math_min = _G.math.min

local function getPos(val, valMax, base)
	return math_pow(val, base) / math_pow(valMax, base)
end
local LSM = LibStub("LibSharedMedia-3.0")

local GetTime = _G.GetTime
local dummyFrame = CreateFrame("Frame")
local cooldownPrototype = setmetatable({}, {__index = dummyFrame})
local cooldownMeta = {__index = cooldownPrototype}
local barPrototype = setmetatable({}, {__index = dummyFrame})

mod.barMeta = {__index = barPrototype}

local framePool = {}
local stringPool = {}

local function getAnchorSide(self)
	local o = self.settings.bar.orientation
	return 	o == "LEFT_TO_RIGHT" and "LEFT" or
			o == "RIGHT_TO_LEFT" and "RIGHT" or
			o == "BOTTOM_TO_TOP" and "TOP" or
			o == "TOP_TO_BOTTOM" and "BOTTOM"
end

------------------------------------------------------
-- Bar prototype
------------------------------------------------------

function barPrototype:Init()	
	self:SetFrameStrata("LOW")
	self.settings = self.db.profile
	self.usedFrames = {}
	self.cooldowns = {}
	self.durations = {}
	
	self:SetBackdrop(mod.backdrop)
	if not self.settings.bar.x then
		self.settings.bar.x, self.settings.bar.y = self.settings.x, self.settings.y
	end
	
	self:SetScript("OnMouseDown", function(self)
		if not self.db.profile.bar.lock then
			self:StartMoving()
		end
	end)
	self:SetScript("OnMouseUp", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		local ox, oy = UIParent:GetCenter()
		self.settings.bar.x = x - ox
		self.settings.bar.y = y - oy
	end)
	self:SetScript("OnSizeChanged", function()
		self.settings.bar.width = self:GetLength()
		self.settings.bar.height = self:GetDepth()
		self:UpdateLook()
	end)
	self:EnableMouse(true)
	self:SetMovable(true)
	self:SetResizable(true)
	self:SetMinResize(20, 10)
	
	local grip = CreateFrame("Frame", nil, self)
	grip:EnableMouse(true)
	local tex = grip.tex or grip:CreateTexture()
	grip.tex = tex
	tex:SetTexture([[Interface\BUTTONS\UI-AutoCastableOverlay]])
	tex:SetTexCoord(0.619, 0.760, 0.612, 0.762)
	tex:SetDesaturated(true)
	tex:ClearAllPoints()
	tex:SetAllPoints()

	grip:SetWidth(6)
	grip:SetHeight(6)
	grip:SetScript("OnMouseDown", function(self)
		self:GetParent():StartSizing()
	end)
	grip:SetScript("OnMouseUp", function(self)
		self:GetParent():StopMovingOrSizing()
		self:GetParent().settings.bar.width = self:GetParent():GetLength()
		self:GetParent().settings.bar.height = self:GetParent():GetDepth()
	end)

	grip:ClearAllPoints()
	grip:SetPoint("BOTTOMRIGHT")
	grip:SetScript("OnEnter", function(self)
		self.tex:SetDesaturated(false)
	end)
	grip:SetScript("OnLeave", function(self)
		self.tex:SetDesaturated(true)
	end)
	self.grip = grip
	
	self.fade = self:CreateAnimationGroup()
	self.fadeAlpha = self.fade:CreateAnimation()

	self.fadeAlpha.parent = self
	self.fadeAlpha:SetScript("OnPlay", function(self)
		self.startAlpha = self.parent:GetAlpha()
		if self.parent.active then
			self.endAlpha = 1
		else
			self.endAlpha = self.parent.settings.bar.inactiveAlpha
		end
	end)
	self.fadeAlpha:SetScript("OnUpdate", function(self)		
		local new = self.startAlpha + ((self.endAlpha - self.startAlpha) * self:GetProgress())
		self.parent:SetAlpha(new)
	end)	
	
	
	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		insets = {left = 2, top = 2, right = 2, bottom = 2},
		edgeSize = 8,
		tile = false		
	}		
	
	-- Anchor to control where icon ready splashes appear
	self.splashAnchor = CreateFrame("Frame", nil, UIParent)
	
	self.splashAnchor:SetBackdrop(backdrop)
	self.splashAnchor:SetBackdropColor(0, 1, 0, 1)
	if self.settings.bar.splash_x then
		self.splashAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.settings.bar.splash_x, self.settings.bar.splash_y)
	else
		self.splashAnchor:SetPoint("CENTER", self, getAnchorSide(self))
	end
	self.splashAnchor:SetWidth(35)
	self.splashAnchor:SetHeight(35)
	self.splashAnchor:EnableMouse(true)	
	self.splashAnchor:SetMovable(true)	
	self.splashAnchor:SetScript("OnMouseDown", function(self)
		self:StartMoving()
	end)
	self.splashAnchor:SetScript("OnMouseUp", function(mover)
		mover:StopMovingOrSizing()
		self.settings.bar.splash_x, self.settings.bar.splash_y = mover:GetCenter()
	end)
	local close = CreateFrame("Button", nil, self.splashAnchor, "UIPanelCloseButton")
	close:SetWidth(14)
	close:SetHeight(14)
	close:SetPoint("TOPRIGHT", self.splashAnchor, "TOPRIGHT", -1, -1)
	close:SetScript("OnClick", function(self)
		self:GetParent():lock(true)
	end)
	self.splashAnchor.close = close;
	
	self.splashAnchor.lock = function(self, lock)
		if lock then
			self.close:Hide()
			self:SetBackdropColor(0,0,0,0)
		else
			self.close:Show()
			self:SetBackdropColor(0,1,0,1)
		end
	end
	self.splashAnchor:lock(true)
	
	self:UpdateBarLook()
end

function barPrototype:Vertical()
	local vert = (self.settings.bar.orientation == "BOTTOM_TO_TOP" or self.settings.bar.orientation == "TOP_TO_BOTTOM")
	return vert
end

function barPrototype:Reversed()
	return self.settings.bar.orientation == "RIGHT_TO_LEFT" or self.settings.bar.orientation == "BOTTOM_TO_TOP"
end

function barPrototype:GetLength()
	return self:Vertical() and self:GetHeight() or self:GetWidth()
end

function barPrototype:GetDepth()
	return self:Vertical() and self:GetWidth() or self:GetHeight()
end

do
	local framelevelSerial = 10
	local delta = 0
	local throttle = 1 / 33
	function barPrototype:OnUpdate(t)
		delta = delta + t		
		if delta < throttle then return end
		delta = delta - throttle
		for _, frame in ipairs(self.usedFrames) do		
			frame:UpdateTime()
		end
	end
	
	local backdrop = {
		edgeFile = [[Interface\GLUES\COMMON\TextPanel-Border.blp]],
		insets = {left = 2, top = 2, right = 2, bottom = 2},
		edgeSize = 8,
		tile = false		
	}	
	function barPrototype:UpdateSingleIconLook(icon)
		backdrop.edgeFile = LSM:Fetch("border", self.settings.icon.border) or backdrop.edgeFile
		backdrop.edgeSize = self.settings.icon.borderSize or backdrop.edgeSize
		
		icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", self.settings.icon.borderInset, -self.settings.icon.borderInset)
		icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -self.settings.icon.borderInset, self.settings.icon.borderInset)
		icon.overlay.tex:SetPoint("TOPLEFT", icon.overlay, "TOPLEFT", self.settings.icon.borderInset, -self.settings.icon.borderInset)
		icon.overlay.tex:SetPoint("BOTTOMRIGHT", icon.overlay, "BOTTOMRIGHT", -self.settings.icon.borderInset, self.settings.icon.borderInset)
		
		icon:SetBackdrop(backdrop)
		icon.overlay:SetBackdrop(backdrop)
		local c = self.settings.icon.borderColor
		icon:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
		icon.overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
		
		self:UpdateLabel(icon.fs, self.settings.icon)
		self:UpdateLabel(icon.overlay.fs, self.settings.icon)
		icon:SetWidth(self:GetDepth() + self.settings.icon.sizeOffset)
		icon:SetHeight(self:GetDepth() + self.settings.icon.sizeOffset)		
		
		if self.settings.icon.showText then
			icon.fs:Show()
			icon.overlay.fs:Show()
		else
			icon.fs:Hide()
			icon.overlay.fs:Hide()
		end
		
		icon.finishScale.maxScale = self.settings.icon.splashScale
		-- icon.finishScale:SetScale(self.settings.icon.splashScale, self.settings.icon.splashScale)
		icon.finishScale:SetDuration(self.settings.icon.splashSpeed)
		icon.finishAlpha:SetDuration(self.settings.icon.splashSpeed)
		
		if self.settings.icon.disableTooltip then
			icon:EnableMouse(false)
		else
			icon:EnableMouse(true)
		end
	end
	
	local function onClick(self, button)
		if button == "RightButton" then
			self:Blacklist()
		end
	end
	
	function barPrototype:Activate()
		if self.active then return end
		self.active = true		
		local alpha = self:GetAlpha()
		if alpha ~= 1 then
			self.fade:Stop()
			self.fadeAlpha:SetDuration(0.3)
			self.fade:Play()
		end
	end
	
	function barPrototype:Deactivate()
		if not self.active then return end
		self.active = false
		local alpha = self:GetAlpha()
		if alpha ~= self.settings.bar.inactiveAlpha then
			self.fade:Stop()
			self.fadeAlpha:SetDuration(0.33)
			self.fade:Play()
		end
	end
	
	function barPrototype:CreateNewCooldownFrame()
		local f = setmetatable(CreateFrame("Frame"), cooldownMeta)
		f:SetScript("OnMouseUp", onClick)
		
		f.tex = f:CreateTexture(nil, "ARTWORK")

		f.overlay = CreateFrame("Frame", nil, f)
		f.overlay:SetAllPoints()
		f.overlay.tex = f.overlay:CreateTexture(nil, "ARTWORK")
		
		f.fs = f:CreateFontString(nil, nil, "SystemFont_Outline_Small")
		f.fs:SetPoint("BOTTOMRIGHT", f.overlay, "BOTTOMRIGHT", -1, 2)
		
		f.overlay.fs = f.overlay:CreateFontString(nil, nil, "SystemFont_Outline_Small")
		f.overlay.fs:SetPoint("BOTTOMRIGHT", f.overlay, "BOTTOMRIGHT", -1, 2)
		
		f:SetScript("OnEnter", f.ShowTooltip)
		f:SetScript("OnLeave", f.HideTooltip)
		f:EnableMouse(true)
		
		f.finish = f:CreateAnimationGroup()
		f.finishScale = f.finish:CreateAnimation()
		f.finishScale.maxScale = 4
		f.finishAlpha = f.finish:CreateAnimation("Alpha")
		f.finishAlpha:SetChange(-1)
		
		f.finishScale:SetScript("OnUpdate", function(self)
			local scale = 1 + ((self.maxScale - 1) * self:GetProgress())
			f:SetScale(scale)
		end)		
		f.finish:SetScript("OnPlay", function()
			f:SetParent(UIParent)
			if f.parent.settings.bar.splash_x then
				f:SetParent(self.splashAnchor)
				f:ClearAllPoints()
				f:SetPoint("CENTER", self.splashAnchor, "CENTER")
				f:EnableMouse(false)
			end
			f.overlay:Hide()
			f.fs:Hide()
		end)
		f.finish:SetScript("OnFinished", function()
			f:SetScale(1)
			if not self.settings.icon.disableTooltip then
				f:EnableMouse(true)
			end
			f:Hide()
			f:SetParent(self)
			f.fs:Show()
			f.overlay:Show()
		end)
		f.finish:SetScript("OnStop", f.finish:GetScript("OnFinished"))
		
		f.pulse = f.overlay:CreateAnimationGroup()
		f.pulse:SetLooping("BOUNCE")
		f.pulseAlpha = f.pulse:CreateAnimation("Alpha")
		f.pulseAlpha:SetMaxFramerate(30)
		f.pulseAlpha:SetChange(-1)
		f.pulseAlpha:SetDuration(0.4)
		f.pulseAlpha:SetEndDelay(0.4)
		f.pulseAlpha:SetStartDelay(0.4)
		
		f.throb = f:CreateAnimationGroup()
		-- f.throb:SetLooping("BOUNCE")
		f.throbUp = f.throb:CreateAnimation("Scale")
		f.throbUp:SetScale(2, 2)
		f.throbUp:SetDuration(0.025)
		f.throbUp:SetEndDelay(0.25)
		
		f.throb:SetScript("OnPlay", function()
			f.overlay:Hide()
			f.origFrameLevel = f.origFrameLevel or f:GetFrameLevel()
			f:SetFrameLevel(128)
		end)
		f.throb:SetScript("OnStop", function()
			f.overlay:Show()
			if f.origFrameLevel then
				f:SetFrameLevel(f.origFrameLevel)
				f.origFrameLevel = nil
			end
		end)
		f.throb:SetScript("OnFinished", f.throb:GetScript("OnStop"))
		
		f.parent = self
		
		tinsert(framePool, f)
		return f
	end
	
	function barPrototype:CreateCooldown(name, typ, id, startTime, duration, icon)
		if not duration then
			error((":CreateCooldown requires a numeric duration, %s %s %s"):format(tostring(name), tostring(typ), tostring(id)))
		end
		if duration < self.settings.bar.minDuration or duration - (GetTime() - startTime) + 0.5 < self.settings.bar.minDuration then return end
		if duration > self.settings.bar.maxDuration and self.settings.bar.maxDuration ~= 0 then return end
		
		local hyperlink = ("%s:%s"):format(typ, id)
		if self.settings.blacklist[hyperlink] then return end
		
		local f = self.cooldowns[hyperlink]
		if not f then
			f = tremove(framePool)
			if not f then
				self:CreateNewCooldownFrame()
				f = tremove(framePool)
			end
			
			f.name = name
			f.icon = icon
			
			if f.finish:IsPlaying() then f.finish:Stop() end
			if f.throb:IsPlaying() then f.throb:Stop() end
			if f.pulse:IsPlaying() then f.pulse:Stop() end
			
			f.overlay:Show()
			f:SetAlpha(1)	
			f.overlay:SetAlpha(1)			
			
			f:SetParent(self)
			
			f:SetFrameLevel(framelevelSerial)
			f.overlay:SetFrameLevel(framelevelSerial + 60)
			framelevelSerial = framelevelSerial + 5
			if framelevelSerial > 60 then
				framelevelSerial = 10
			end
			f.useTooltip = typ == "spell" or typ == "item"
			f.hyperlink = hyperlink
			self.cooldowns[f.hyperlink] = f
			self.durations[f.hyperlink] = duration
			
			f.endTime = startTime + duration
			
			f.parent = self			
			f:SetCooldownTexture(typ, id)			
			self:UpdateSingleIconLook(f)
			tinsert(self.usedFrames, f)
			f:Show()
			self:Activate()
		end
		f.startTime = startTime
		f.duration = duration
		self:SetMaxDuration()
		f.lastOverlapCheck = 0
		f:ClearAllPoints()
		f:UpdateTime()
		self:SetScript("OnUpdate", self.OnUpdate)		
	end
	
	function barPrototype:CastFailure(typ, id)
		local hyperlink = typ .. ":" .. id
		for _, v in ipairs(self.usedFrames) do
			if v.hyperlink == hyperlink and v.endTime - GetTime() > 0.3 then
				if not v.throb:IsPlaying() then
					v.throb:Play()
				end
			end
		end
	end
end

function barPrototype:SetMaxDuration()
	if not self.settings.bar.flexible then return end
	local max = 0
	for k, v in pairs(self.durations) do
		max = v > max and v or max
	end
	if max < 30 then max = 30 end
	if max ~= self:GetTimeMax() then
		self.max_duration = max
		self:SetLabels()
	end
end

function barPrototype:GetTimeMax()
	local t = self.settings.bar.flexible and self.max_duration or self.settings.bar.time_max
	return t
end

function barPrototype:CreateLabel()
	local s = tremove(stringPool) or self:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	tinsert(self.usedStrings, s)
	s:SetParent(self)
	s:Show()
	return s
end

function barPrototype:SetLabel(val)
	local l = self:CreateLabel(self)
	local pos = getPos(val, self:GetTimeMax(), self.settings.bar.time_compression) * (self:GetLength() - self:GetDepth())
	if self:Vertical() then
		l:SetPoint("CENTER", self, getAnchorSide(self), 0, pos * (self:Reversed() and -1 or 1))
	else
		l:SetPoint("CENTER", self, getAnchorSide(self), pos * (self:Reversed() and -1 or 1), 0)
	end
	if val > 3600 then
		val = ("%2.0fh"):format(val / 3600)
	elseif val >= 60 then
		val = ("%2.0fm"):format(val / 60)
	end	
	l:SetText(val)
end

local stock = {1, 10, 30}
function barPrototype:SetLabels()
	self.usedStrings = self.usedStrings or {}
	
	while #self.usedStrings > 0 do
		local l = tremove(self.usedStrings)
		l:Hide()
		tinsert(stringPool, l)
	end
	
	local minutes = math_floor(self:GetTimeMax() / 60)
	for i = 5, minutes, 5 do
		self:SetLabel(i * 60)
	end
	
	if minutes > 5 and math_fmod(minutes, 5) ~= 0 then
		self:SetLabel(minutes * 60)
	elseif minutes < 1 and self:GetTimeMax() ~= 30 then
		self:SetLabel(self:GetTimeMax())
	end
	
	for i = 1, math_min(minutes, 5) do
		self:SetLabel(i * 60)
	end

	for _, val in ipairs(stock) do
		if val <= self:GetTimeMax() then
			self:SetLabel(val)
		end
	end
end

function barPrototype:UpdateLabel(label, store)
	local f, s, m = label:GetFont() 
	local font = LSM:Fetch("font", store.font or f)
	local size = store.fontsize or s
	local outline = store.outline or m
	label:SetFont(font, size, outline)	
	local c = store.fontColor
	label:SetTextColor(c.r, c.g, c.b, c.a)
end

function barPrototype:SetBarFont()
	for k, v in ipairs(stringPool) do
		self:UpdateLabel(v, self.settings.bar)
	end
	
	for k, v in ipairs(self.usedStrings) do
		self:UpdateLabel(v, self.settings.bar)
	end
end

do
	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		insets = {left = 2, top = 2, right = 2, bottom = 2},
		edgeSize = 8,
		tile = false
	}
	function barPrototype:UpdateBarBackdrop()
		backdrop.bgFile = LSM:Fetch("statusbar", self.settings.bar.texture) or backdrop.bgFile
		backdrop.edgeFile = LSM:Fetch("border", self.settings.bar.border) or backdrop.border
		backdrop.edgeSize = self.settings.bar.borderSize or backdrop.edgeSize
		backdrop.insets.left = self.settings.bar.borderInset or backdrop.insets.left
		backdrop.insets.top = self.settings.bar.borderInset or backdrop.insets.top
		backdrop.insets.right = self.settings.bar.borderInset or backdrop.insets.right
		backdrop.insets.bottom = self.settings.bar.borderInset or backdrop.insets.bottom
		self:SetBackdrop(backdrop)
		local c = self.settings.bar.backgroundColor
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
		c = self.settings.bar.borderColor
		self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
	end
end

function barPrototype:UpdateBarLook()
	self:SetPoint("CENTER", UIParent, "CENTER", self.settings.bar.x, self.settings.bar.y)
	self:SetWidth(self:Vertical() and self.settings.bar.height or self.settings.bar.width)
	self:SetHeight(self:Vertical() and self.settings.bar.width or self.settings.bar.height)
	
	if not self.settings.bar.splash_x then
		self.splashAnchor:SetPoint("CENTER", self, getAnchorSide(self))
	end
	
	self:SetLabels()
	self:SetBarFont()
	self:UpdateBarBackdrop()
	if self.settings.bar.lock then
		self.grip:Hide()
		self:EnableMouse(false)
	else
		self.grip:Show()
		self:EnableMouse(true)
	end
	
	if not self.active then
		self:SetAlpha(self.settings.bar.inactiveAlpha)
	end
end

function barPrototype:UpdateIconLook()
	for _, icon in ipairs(self.usedFrames) do
		self:UpdateSingleIconLook(icon)
	end
end

function barPrototype:UpdateLook()
	self:UpdateBarLook()
	self:UpdateIconLook()
end

function barPrototype:Expire()
	self:SetScript("OnUpdate", nil)
	
	while #self.usedStrings > 0 do
		local l = tremove(self.usedStrings)
		l:Hide()
		tinsert(stringPool, l)
	end
	
	for _, frame in ipairs(self.usedFrames) do
		if frame.finish:IsPlaying() then frame.finish:Stop() end
		if frame.throb:IsPlaying() then frame.throb:Stop() end
		if frame.pulse:IsPlaying() then frame.pulse:Stop() end	
		frame:Expire(true)
	end
	self:Hide()
end

function barPrototype:CheckOverlap(current)
	local l, r = current:GetLeft(), current:GetRight()
	if not l or not r then return end
	
	current.lastOverlapCheck = current.lastOverlapCheck or 0
	if GetTime() - current.lastOverlapCheck < 3 then return end
	current.lastOverlapCheck = GetTime()
	
	current.pulsing = false
	for _, icon in ipairs(self.usedFrames) do
		if icon ~= current then
			local ir, il = icon:GetRight(), icon:GetLeft()
			if (ir >= l and ir <= r) or (il >= l and il <= r) then
				local overlap = math.min(math.abs(ir - l), math.abs(il - r))
				if overlap > 5 then
					local frame = icon:GetFrameLevel() >= current:GetFrameLevel() and icon or current
					if not frame.pulse:IsPlaying() then
						frame.pulse:Play()
					end
					frame.pulsing = true
				end
			end
		end
	end
	if not current.pulsing and current.pulse:IsPlaying() then
		current.pulse:Stop()
	end	
end

------------------------------------------------------
-- Button prototype
------------------------------------------------------
function cooldownPrototype:SetCooldownTexture(typ, id)
	local icon = self.icon
	if not icon then
		local _
		if typ == "spell" then
			_, _, icon = GetSpellInfo(id)
		elseif typ == "item" then
			_, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
		end
	end
	if icon then
		self.tex:SetTexture(icon)
		self.tex:SetTexCoord(0.09, 0.91, 0.09, 0.91)
		
		self.overlay.tex:SetTexture(icon)
		self.overlay.tex:SetTexCoord(0.09, 0.91, 0.09, 0.91)
	end
end

function cooldownPrototype:ShowTooltip()
	if not self.hyperlink or not self.useTooltip then 
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	GameTooltip:SetHyperlink(self.hyperlink)
	GameTooltip:Show()
end

function cooldownPrototype:HideTooltip()
	GameTooltip:Hide()
end
	
function cooldownPrototype:Expire(noanimate)
	local parent = self.parent
	for k, v in ipairs(parent.usedFrames) do
		if v == self then
			tinsert(framePool, tremove(parent.usedFrames, k))
			break
		end
	end
	if #parent.usedFrames == 0 then
		parent:SetScript("OnUpdate", nil)
		parent:Deactivate()
	end
	
	if self.pulse:IsPlaying() then self.pulse:Stop() end
	if noanimate then
		self:Hide()
	else
		self.finish:Play()
	end
	parent.cooldowns[self.hyperlink] = nil
	parent.durations[self.hyperlink] = nil
end
	
function cooldownPrototype:UpdateTime()
	local parent = self.parent
	local timeMax = parent:GetTimeMax()
	local remaining = self.endTime - GetTime()
	local iRemaining = math_floor(remaining)
	local text
	if iRemaining ~= self.lastRemaining or iRemaining < 10 then
		parent:CheckOverlap(self)
		if remaining > 60 then
			local minutes = math_floor(remaining / 60)
			local seconds = math_fmod(remaining, 60)
			text = string_format("%2.0f:%02.0f", minutes, seconds)
		elseif remaining <= 10 then
			text = string_format("%2.1f", remaining)
		else
			text = string_format("%2.0f", remaining)
		end
		if self.fs.lastText ~= text then
			self.fs:SetText(text)
			self.fs.lastText = text
			self.overlay.fs:SetText(text)
			self.overlay.fs.lastText = text
		end
		self.lastRemaining = iRemaining
	end
	
	if remaining > timeMax then
		remaining = timeMax
	end

	local expire = false
	if remaining <= 0 then
		remaining = 0.00001
		expire = true
	end
	
	local w, h = parent:GetLength(), parent:GetDepth()
	local barWidth = (w - h)
	local base = parent.settings.bar.time_compression
	local pos = getPos(remaining, timeMax, base) * barWidth
	-- self:SetPoint("CENTER", parent, "LEFT", pos, 0)
	if parent:Vertical() then
		self:SetPoint("CENTER", parent, getAnchorSide(parent), 0, pos * (parent:Reversed() and -1 or 1))
	else
		self:SetPoint("CENTER", parent, getAnchorSide(parent), pos * (parent:Reversed() and -1 or 1), 0)
	end	
	
	if expire then
		self:Expire()		
	end
end

function cooldownPrototype:Blacklist()
	self.parent.db.profile.blacklist[self.hyperlink] = self.name
	self:Expire(true)
end
