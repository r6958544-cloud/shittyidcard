if not CLIENT then return end

local registrationFrame
local ROLEPLAY_YEAR = 2020
local months = {
    "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
    "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
}

local function OpenRegistration()
    if IsValid(registrationFrame) then registrationFrame:MakePopup() return end

    registrationFrame = vgui.Create("DFrame")
    registrationFrame:SetSize(460, 430)
    registrationFrame:Center()
    registrationFrame:SetTitle("")
    registrationFrame:ShowCloseButton(false)
    registrationFrame:MakePopup()
    registrationFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(20, 29, 43, 250))
        draw.RoundedBoxEx(12, 0, 0, w, 62, Color(28, 91, 125), true, true, false, false)
        draw.SimpleText("Регистрация персонажа", "DermaLarge", 22, 31, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Данные будут напечатаны на пластиковой ID-карте", "DermaDefault", 24, 82, Color(205, 216, 226))
    end

    local first = vgui.Create("DTextEntry", registrationFrame)
    first:SetPos(28, 120) first:SetSize(404, 36) first:SetPlaceholderText("Имя персонажа")
    local last = vgui.Create("DTextEntry", registrationFrame)
    last:SetPos(28, 168) last:SetSize(404, 36) last:SetPlaceholderText("Фамилия персонажа")

    local birthLabel = vgui.Create("DLabel", registrationFrame)
    birthLabel:SetPos(28, 208) birthLabel:SetSize(404, 20) birthLabel:SetText("Дата рождения")
    birthLabel:SetTextColor(Color(220, 225, 232))

    local birthYear = vgui.Create("DNumberWang", registrationFrame)
    birthYear:SetPos(28, 230) birthYear:SetSize(126, 34)
    birthYear:SetMin(ROLEPLAY_YEAR - 100) birthYear:SetMax(ROLEPLAY_YEAR - 18)
    birthYear:SetValue(ROLEPLAY_YEAR - 20)

    local birthMonth = vgui.Create("DComboBox", registrationFrame)
    birthMonth:SetPos(168, 230) birthMonth:SetSize(264, 34)
    birthMonth:SetValue(months[selectedMonth] or "Месяц")
    local selectedMonth = 1
    for index, monthName in ipairs(months) do birthMonth:AddChoice(monthName, index) end
    birthMonth.OnSelect = function(_, _, _, data) selectedMonth = tonumber(data) or 1 end
    birthMonth:SetValue(months[selectedMonth])

    local genderLabel = vgui.Create("DLabel", registrationFrame)
    genderLabel:SetPos(28, 272) genderLabel:SetSize(404, 20) genderLabel:SetText("Пол персонажа")
    genderLabel:SetTextColor(Color(220, 225, 232))
    local gender = vgui.Create("DComboBox", registrationFrame)
    gender:SetPos(28, 294) gender:SetSize(404, 34) gender:SetValue("Мужской (Male)")
    gender:AddChoice("Мужской (Male)", "male")
    gender:AddChoice("Женский (Female)", "female")
    local selectedGender = "male"
    gender.OnSelect = function(_, _, _, data) selectedGender = data == "female" and "female" or "male" end

    local status = vgui.Create("DLabel", registrationFrame)
    status:SetPos(28, 334) status:SetSize(404, 24) status:SetText("")
    status:SetTextColor(Color(255, 145, 145))
    registrationFrame.StatusLabel = status

    local submit = vgui.Create("DButton", registrationFrame)
    submit:SetPos(28, 370) submit:SetSize(404, 38)
    submit:SetText("Создать ID-карту") submit:SetTextColor(color_white)
    submit.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(45, 130, 165) or Color(33, 100, 132))
    end
    submit.DoClick = function()
        local year = math.Clamp(math.floor(tonumber(birthYear:GetValue()) or (ROLEPLAY_YEAR - 20)), ROLEPLAY_YEAR - 100, ROLEPLAY_YEAR - 18)
        net.Start("idcard_register")
            net.WriteString(first:GetValue())
            net.WriteString(last:GetValue())
            net.WriteUInt(year, 12)
            net.WriteUInt(selectedMonth, 4)
            net.WriteString(selectedGender)
        net.SendToServer()
    end
end

net.Receive("idcard_open_registration", OpenRegistration)
net.Receive("idcard_registration_result", function()
    local success, message = net.ReadBool(), net.ReadString()
    if success then
        if IsValid(registrationFrame) then registrationFrame:Close() registrationFrame = nil end
    elseif IsValid(registrationFrame) and IsValid(registrationFrame.StatusLabel) then
        registrationFrame.StatusLabel:SetText(message)
    end
end)

local function PaintSecurityPattern(w, h, scale)
    local s = scale or 1
    surface.SetDrawColor(62, 115, 142, 19)
    for band = 0, 12 do
        local baseY = 92 + band * 31
        local prevX, prevY
        for x = 0, w, 8 do
            local y = baseY + math.sin((x + band * 27) / 42) * 16 + math.sin((x + band * 13) / 17) * 3
            if prevX then surface.DrawLine(prevX * s, prevY * s, x * s, y * s) end
            prevX, prevY = x, y
        end
    end
    surface.SetDrawColor(255, 255, 255, 24)
    for i = 0, 14 do
        surface.DrawLine((195 + i * 28) * s, 98 * s, (95 + i * 42) * s, (h - 18) * s)
    end
    surface.SetDrawColor(48, 97, 125, 27)
    for ring = 1, 5 do
        surface.DrawCircle((w - 155) * s, (h - 135) * s, (18 + ring * 13) * s, 48, 97, 125, 27)
    end
    -- Low-contrast guilloche rosette, like fine-line printing on a plastic card.
    local cx, cy = w - 112, 204
    for ray = 0, 35 do
        local angle = math.rad(ray * 10)
        local inner = 30 + math.sin(angle * 8) * 8
        local outer = 82 + math.cos(angle * 6) * 8
        surface.DrawLine(
            (cx + math.cos(angle) * inner) * s, (cy + math.sin(angle) * inner) * s,
            (cx + math.cos(angle) * outer) * s, (cy + math.sin(angle) * outer) * s
        )
    end
    for ring = 1, 7 do
        surface.DrawCircle(cx * s, cy * s, ring * 9 * s, 49, 94, 120, 20)
    end

    -- A few fixed, subtle laminate specks keep the surface from looking flat.
    surface.SetDrawColor(73, 91, 91, 18)
    for speck = 1, 44 do
        local x = 17 + (speck * 67) % (w - 34)
        local y = 103 + (speck * 43) % (h - 124)
        surface.DrawRect(x * s, y * s, (speck % 3 == 0 and 2 or 1) * s, s)
    end
end

surface.CreateFont("IDCardNYTitle", {font = "Georgia", size = 36, weight = 500, antialias = true, extended = true})
surface.CreateFont("IDCardFieldLabel", {font = "Tahoma", size = 12, weight = 700, antialias = true, extended = true})
surface.CreateFont("IDCardFieldValue", {font = "Tahoma", size = 16, weight = 600, antialias = true, extended = true})
surface.CreateFont("IDCardName", {font = "Georgia", size = 24, weight = 600, antialias = true, extended = true})

local function PaintFlagWatermark(w, h, scale)
    local s = scale or 1
    local top, stripeHeight = 101, 28
    for stripe = 0, 6 do
        local y = top + stripe * stripeHeight * 2
        draw.RoundedBox(0, 10 * s, y * s, (w - 20) * s, stripeHeight * s, Color(166, 55, 63, 12))
    end
    draw.RoundedBox(0, 10 * s, top * s, 225 * s, 126 * s, Color(37, 69, 106, 15))
    surface.SetFont("DermaDefaultBold")
    surface.SetTextColor(255, 255, 255, 34)
    for row = 0, 3 do
        for col = 0, 6 do
            surface.SetTextPos((19 + col * 29 + (row % 2) * 10) * s, (top + 9 + row * 26) * s)
            surface.DrawText("*")
        end
    end
end

local function ShowCard(first, last, birthYear, birthMonth, gender, documentNumber, model, weaponLicense, businessLicense, drivingLicense, wanted, reason)
    local cardScale = 0.8
    local frame = vgui.Create("DFrame")
    frame:SetSize(640, 408) frame:Center() frame:SetTitle("")
    frame:ShowCloseButton(false) frame:SetDraggable(false) frame:MakePopup()

    frame.Paint = function()
        local s = cardScale
        local w, h = 800, 510
        local function box(radius, x, y, width, height, color)
            draw.RoundedBox(radius * s, x * s, y * s, width * s, height * s, color)
        end
        local function label(value, font, x, y, color, alignX, alignY)
            draw.SimpleText(value, font, x * s, y * s, color, alignX, alignY)
        end
        local function line(x1, y1, x2, y2, color, thickness)
            surface.SetDrawColor(color)
            if thickness and thickness > 1 then
                surface.DrawRect(x1 * s, y1 * s, (x2 - x1) * s, thickness * s)
            else
                surface.DrawLine(x1 * s, y1 * s, x2 * s, y2 * s)
            end
        end
        local function rect(x, y, width, height, color)
            surface.SetDrawColor(color)
            surface.DrawRect(x * s, y * s, width * s, height * s)
        end

        box(18, 0, 0, w, h, Color(157, 164, 160))
        box(15, 3, 3, w - 6, h - 6, Color(211, 222, 228))
        box(12, 8, 8, w - 16, h - 16, Color(222, 233, 238))
        PaintFlagWatermark(w, h, s)
        PaintSecurityPattern(w, h, s)
        surface.SetDrawColor(126, 151, 151, 100)
        surface.DrawOutlinedRect(9 * s, 9 * s, (w - 18) * s, (h - 18) * s, s)
        surface.SetDrawColor(255, 255, 245, 120)
        surface.DrawOutlinedRect(13 * s, 13 * s, (w - 26) * s, (h - 26) * s, s)
        box(14, 5, 5, w - 10, 94, Color(237, 242, 241, 245))
        label("NEW YORK STATE", "IDCardNYTitle", 34, 34, Color(24, 86, 143), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        label("ID CARD", "DermaDefaultBold", 34, 73, Color(31, 52, 65), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        label("SAMPLE", "DermaDefaultBold", w - 27, 31, Color(67, 79, 76), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        label("ID NUMBER  NY-" .. tostring(documentNumber), "IDCardFieldValue", w - 27, 63, Color(28, 49, 62), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(65, 126, 160, 200)
        surface.DrawRect(20 * s, 98 * s, (w - 40) * s, 2 * s)

        box(3, 38, 134, 138, 164, Color(168, 179, 177, 170))
        -- Small iridescent security foil beside the portrait.
        box(2, 184, 226, 17, 52, Color(65, 115, 132, 70))
        line(186, 229, 199, 229, Color(220, 231, 219, 105))
        line(186, 241, 199, 241, Color(170, 116, 120, 72))
        line(186, 253, 199, 253, Color(104, 147, 168, 78))
        line(186, 265, 199, 265, Color(186, 174, 117, 80))
        label("✦", "DermaDefaultBold", 192, 260, Color(255, 255, 235, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        label("ПОРТРЕТ", "DermaDefaultBold", 107, 311, Color(47, 66, 72), TEXT_ALIGN_CENTER)
        label("USA", "DermaDefaultBold", 24, 194, Color(32, 79, 124), TEXT_ALIGN_CENTER)

        local muted = Color(71, 82, 80)
        local ink = Color(28, 43, 49)
        label("ГРАЖДАНСТВО", "IDCardFieldLabel", 220, 116, muted)
        label("США", "IDCardFieldValue", 220, 135, ink)
        label("ФАМИЛИЯ", "IDCardFieldLabel", 220, 164, muted)
        label(string.upper(last), "IDCardName", 220, 184, ink)
        label("ИМЯ", "IDCardFieldLabel", 220, 216, muted)
        label(string.upper(first), "IDCardName", 220, 237, ink)

        local monthName = months[birthMonth] or "—"
        local age = ROLEPLAY_YEAR - birthYear
        label("ПОЛ", "IDCardFieldLabel", 220, 273, muted)
        label(gender == "female" and "ЖЕНСКИЙ" or "МУЖСКОЙ", "IDCardFieldValue", 220, 293, ink)
        label("ДАТА РОЖДЕНИЯ", "IDCardFieldLabel", 360, 273, muted)
        label(monthName .. " " .. birthYear, "IDCardFieldValue", 360, 293, ink)
        label("ВОЗРАСТ (2020)", "IDCardFieldLabel", 570, 273, muted)
        label(tostring(age) .. " ЛЕТ", "IDCardFieldValue", 570, 293, ink)

        label("МЕСТО РОЖДЕНИЯ", "IDCardFieldLabel", 220, 327, muted)
        label("NEW YORK, NY", "IDCardFieldValue", 220, 347, ink)
        label("ВЫДАНА", "IDCardFieldLabel", 430, 327, muted)
        label("01 JAN 2020", "IDCardFieldValue", 430, 347, ink)
        label("ДЕЙСТВИТЕЛЬНА ДО", "IDCardFieldLabel", 570, 327, muted)
        label("01 JAN 2030", "IDCardFieldValue", 570, 347, ink)

        label("ЛИЦЕНЗИЯ НА ОРУЖИЕ: " .. (weaponLicense and "ЕСТЬ" or "НЕТ"), "IDCardFieldValue", 220, 386, ink)
        label("ЛИЦЕНЗИЯ НА БИЗНЕС: " .. (businessLicense and "ЕСТЬ" or "НЕТ"), "IDCardFieldValue", 220, 411, ink)
        label("ВОДИТЕЛЬСКИЕ ПРАВА: " .. (drivingLicense and "ЕСТЬ" or "НЕТ"), "IDCardFieldValue", 220, 436, ink)

        box(1, 24, 474, w - 48, 1, Color(67, 82, 78, 110))
        label("SAMPLE  •  NOT A GOVERNMENT ID", "DermaDefaultBold", 30, 489, Color(60, 70, 70))
        label("NEW YORK  •  USA  •  SAMPLE  •  NEW YORK  •  USA", "DermaDefault", w - 28, 489, Color(82, 101, 101, 150), TEXT_ALIGN_RIGHT)

        -- Laminate highlights, softened edges and small wear marks.
        line(15, 14, w - 22, 14, Color(255, 255, 244, 86))
        line(13, 24, 13, h - 26, Color(255, 255, 244, 86))
        line(28, 448, 108, 452, Color(102, 112, 105, 48))
        line(w - 142, 104, w - 126, 111, Color(102, 112, 105, 48))
        line(w - 110, 107, w - 96, 111, Color(102, 112, 105, 48))
        line(216, h - 34, 262, h - 32, Color(102, 112, 105, 48))
    end

    local photoFrame = vgui.Create("DPanel", frame)
    photoFrame:SetPos(40 * cardScale, 136 * cardScale)
    photoFrame:SetSize(134 * cardScale, 156 * cardScale)
    photoFrame:SetPaintBackground(false)
    photoFrame:NoClipping(false)
    photoFrame:SetZPos(5)

    local portrait = vgui.Create("DModelPanel", photoFrame)
    portrait:SetPos(0, 0)
    portrait:SetSize(134 * cardScale, 156 * cardScale)
    portrait:SetModel(util.IsValidModel(model or "") and model or "models/player/kleiner.mdl")
    portrait:SetFOV(24)
    portrait:NoClipping(false)
    local photoFocus = Vector(0, 0, 64)
    portrait:SetLookAt(photoFocus)
    portrait:SetCamPos(Vector(34, 0, 64))
    portrait:SetAmbientLight(Color(205, 207, 197))
    portrait:SetDirectionalLight(BOX_TOP, Color(232, 234, 226))
    portrait:SetDirectionalLight(BOX_FRONT, Color(190, 198, 203))
    portrait:SetAnimated(false)
    portrait.LayoutEntity = function(_, entity)
        if not IsValid(entity) then return end
        entity:SetAngles(Angle(0, 0, 0))
        entity:SetCycle(0)
        entity:SetPlaybackRate(0)
    end
    if IsValid(portrait.Entity) then
        portrait.Entity:SetSequence(0)
        portrait.Entity:SetCycle(0)
        portrait.Entity:SetPlaybackRate(0)
        portrait.Entity:SetAngles(Angle(0, 0, 0))
    end
    portrait:SetPaintBackgroundEnabled(false)
    frame.PaintOver = function()
        local s = cardScale
        surface.SetDrawColor(73, 82, 76, 185)
        surface.DrawOutlinedRect(38 * s, 134 * s, 138 * s, 164 * s, s)
        surface.SetDrawColor(255, 255, 255, 45)
        surface.DrawLine(40 * s, 136 * s, 174 * s, 136 * s)
    end

    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetSize(28, 28)
    closeButton:SetPos(602, 9)
    closeButton:SetText("×")
    closeButton:SetFont("DermaLarge")
    closeButton:SetTextColor(Color(37, 55, 65))
    closeButton:SetZPos(20)
    closeButton.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(194, 211, 216, 245) or Color(218, 229, 230, 210))
    end
    closeButton.DoClick = function() if IsValid(frame) then frame:Close() end end

    timer.Simple(5, function() if IsValid(frame) then frame:Close() end end)
end

net.Receive("idcard_show_card", function()
    local first, last = net.ReadString(), net.ReadString()
    local year, month = net.ReadUInt(12), net.ReadUInt(4)
    local gender, documentNumber, model = net.ReadString(), net.ReadString(), net.ReadString()
    ShowCard(first, last, year, month, gender, documentNumber, model,
        net.ReadBool(), net.ReadBool(), net.ReadBool(), net.ReadBool(), net.ReadString())
end)

local actionFrame
local actionTarget

local function OpenInteractionMenu()
    local target = net.ReadEntity()
    local cuffed = net.ReadBool()
    local inVehicle = net.ReadBool()
    local canSelfCheck = net.ReadBool()
    if not IsValid(target) or not target:IsPlayer() then return end
    if IsValid(actionFrame) then actionFrame:Remove() end
    actionTarget = target

    local rows = {
        {title = "Посмотреть ID-карту", subtitle = "Открыть удостоверение игрока", icon = "icon16/vcard.png", action = 0},
        {title = "Показать свою ID-карту", subtitle = "Предъявить своё удостоверение", icon = "icon16/vcard.png", action = 2}
    }
    if canSelfCheck then
        rows[#rows + 1] = {title = "Самоосмотр", subtitle = "Проверить собственное состояние", icon = "icon16/heart.png", action = "selfcheck"}
        rows[#rows + 1] = {title = "Осмотреть пациента", subtitle = "Получить медицинские данные игрока", icon = "icon16/zoom.png", action = 4}
    end
    if cuffed then
        rows[#rows + 1] = inVehicle and {
            title = "Вытащить из машины", subtitle = "Достать закованного пассажира", icon = "icon16/door_in.png", action = 3
        } or {
            title = "Посадить в машину", subtitle = "Поместить на пассажирское место Glide", icon = "icon16/car.png", action = 1
        }
        if not inVehicle then
            rows[#rows + 1] = {title = "Вести за собой", subtitle = "Сопроводить или остановить задержанного", icon = "icon16/user_go.png", action = 5}
        end
    end
    for _, row in ipairs(rows) do row.material = Material(row.icon, "smooth") end

    local frame = vgui.Create("DFrame")
    actionFrame = frame
    frame:SetSize(440, 116 + #rows * 78)
    frame:SetTitle("")
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(10, 12, 16, 235))
        surface.SetDrawColor(164, 173, 182, 58)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBoxEx(10, 1, 1, w - 2, 73, Color(22, 25, 30, 232), true, true, false, false)
        draw.SimpleText("ВЗАИМОДЕЙСТВИЕ", "DermaDefaultBold", 20, 26, Color(246, 247, 249), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.sub(target:Nick(), 1, 42), "DermaDefault", 20, 50, Color(167, 174, 182), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 255, 255, 24)
        surface.DrawRect(18, 80, w - 36, 1)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(402, 13)
    close:SetSize(25, 25)
    close:SetText("×")
    close:SetFont("DermaDefaultBold")
    close:SetTextColor(Color(197, 202, 208))
    close.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(5, 0, 0, w, h, Color(255, 255, 255, 24)) end
    end
    close.DoClick = function() if IsValid(frame) then frame:Close() end end

    local function addRow(y, row)
        local button = vgui.Create("DButton", frame)
        button:SetPos(14, y)
        button:SetSize(412, 68)
        button:SetText("")
        button.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(42, 46, 52, 238) or Color(27, 30, 35, 225))
            draw.RoundedBox(2, 0, 0, 3, h, self:IsHovered() and Color(210, 215, 222, 220) or Color(125, 133, 143, 150))
            draw.RoundedBox(18, 15, 16, 36, 36, Color(64, 70, 79, 180))
            local mat = row.material
            if mat and not mat:IsError() then
                surface.SetMaterial(mat)
                surface.SetDrawColor(232, 235, 240, 235)
                surface.DrawTexturedRect(25, 26, 16, 16)
            end
            draw.SimpleText(row.title, "DermaDefaultBold", 64, 25, Color(244, 245, 247), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(row.subtitle, "DermaDefault", 64, 47, Color(166, 172, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("›", "DermaLarge", w - 18, h * 0.5, Color(140, 147, 156, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        button.DoClick = function()
            if not IsValid(actionTarget) then return end
            if row.action == "selfcheck" then
                RunConsoleCommand("SelfCheck")
                frame:Close()
                return
            end
            net.Start("idcard_action_request")
                net.WriteUInt(row.action, 3)
                net.WriteEntity(actionTarget)
            net.SendToServer()
            frame:Close()
        end
    end

    for index, row in ipairs(rows) do addRow(91 + (index - 1) * 78, row) end
end

net.Receive("idcard_open_actions", OpenInteractionMenu)


net.Receive("idcard_action_result", function()
    local success, message = net.ReadBool(), net.ReadString()
    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
end)

surface.CreateFont("IDCardMedicalTitle", {font = "Tahoma", size = 22, weight = 700, antialias = true, extended = true})
surface.CreateFont("IDCardMedicalRow", {font = "Tahoma", size = 16, weight = 600, antialias = true, extended = true})
surface.CreateFont("IDCardMedicalDesc", {font = "Tahoma", size = 13, weight = 400, antialias = true, extended = true})

local function OpenPatientMedicalReport(patient, data)
    if not istable(data) then data = {} end
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(760, ScrW() - 40), math.min(700, ScrH() - 40))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(16, 18, 22, 248))
        draw.RoundedBoxEx(8, 0, 0, w, 76, Color(49, 27, 34, 245), true, true, false, false)
        draw.RoundedBox(3, 0, 0, 4, 76, Color(210, 84, 91))
        draw.SimpleText("МЕДИЦИНСКИЙ ОСМОТР", "IDCardMedicalTitle", 22, 25, Color(244, 245, 247))
        draw.SimpleText(data._name or (IsValid(patient) and patient:Nick() or "Пациент"), "DermaDefault", 23, 52, Color(190, 180, 184))
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(frame:GetWide() - 48, 18)
    close:SetSize(30, 30)
    close:SetText("×")
    close:SetFont("DermaLarge")
    close:SetTextColor(Color(220, 213, 215))
    close.Paint = function() end
    close.DoClick = function() if IsValid(frame) then frame:Close() end end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(0, 82)
    scroll:SetSize(frame:GetWide(), frame:GetTall() - 90)
    local bar = scroll:GetVBar()
    bar:SetWide(5)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(90, 92, 98, 180)) end

    local function section(title)
        local label = scroll:Add("DLabel")
        label:Dock(TOP)
        label:DockMargin(18, 12, 18, 2)
        label:SetTall(22)
        label:SetFont("DermaDefaultBold")
        label:SetText(title)
        label:SetTextColor(Color(145, 150, 159))
    end

    local function row(title, value, detail, color)
        local panel = scroll:Add("DPanel")
        panel:Dock(TOP)
        panel:DockMargin(18, 4, 18, 0)
        panel:SetTall(58)
        panel.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(27, 29, 34, 245))
            draw.RoundedBoxEx(4, 0, 0, 4, h, color or Color(130, 135, 143), true, false, true, false)
            draw.SimpleText(title, "IDCardMedicalRow", 15, 18, Color(226, 228, 232))
            draw.SimpleText(detail or "", "IDCardMedicalDesc", 15, 41, Color(151, 155, 163))
            draw.SimpleText(value or "—", "IDCardMedicalRow", w - 16, h * 0.5, color or Color(190, 193, 199), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local function number(key)
        local value = data[key]
        if istable(value) then value = value[1] end
        value = tonumber(value) or 0
        return value == value and value or 0
    end
    local function flag(key)
        local value = data[key]
        return value == true or (tonumber(value) or 0) > 0
    end

    if data._source ~= "organism" then
        row("Данные пациента", "НЕТ ДАННЫХ", "Мод Z-CITY SelfCheck не обнаружил organism у цели.", Color(145, 150, 159))
        return
    end

    section("ЖИЗНЕННЫЕ ПОКАЗАТЕЛИ")
    local pulse = math.Round(number("pulse"))
    if flag("heartstop") then
        row("Пульс", "ОСТАНОВКА", "Сердечная деятельность отсутствует.", RED)
    elseif pulse < 40 then
        row("Пульс", pulse .. " уд/мин", "Критически редкий пульс.", RED)
    elseif pulse < 60 then
        row("Пульс", pulse .. " уд/мин", "Пульс ниже нормы.", ORANGE)
    elseif pulse > 130 then
        row("Пульс", pulse .. " уд/мин", "Критически высокий пульс.", RED)
    elseif pulse > 100 then
        row("Пульс", pulse .. " уд/мин", "Пульс повышен.", YELLOW)
    else
        row("Пульс", pulse .. " уд/мин", "Показатель в норме.", GREEN)
    end

    row("Объём крови", math.Round(number("blood")) .. " мл", number("blood") < 4000 and "Возможна значительная кровопотеря." or "", number("blood") < 3000 and RED or (number("blood") < 4000 and ORANGE or GREEN))
    local oxygen = data.o2
    local oxygenPercent = "—"
    if istable(oxygen) then
        local range = tonumber(oxygen.range) or 30
        if range > 0 then oxygenPercent = tostring(math.Round(math.Clamp((tonumber(oxygen[1]) or range) / range, 0, 1) * 100)) .. "%" end
    end
    row("Сатурация", oxygenPercent, "Оценка насыщения крови кислородом.", oxygenPercent == "—" and Color(140, 145, 153) or (tonumber(string.match(oxygenPercent, "%d+")) < 60 and RED or GREEN))
    row("Сознание", data._alive == false and "НЕТ ПРИЗНАКОВ ЖИЗНИ" or (flag("otrub") and "БЕЗ СОЗНАНИЯ" or (number("consciousness") > 0.8 and "ЯСНОЕ" or "НАРУШЕНО")), "", (data._alive == false or flag("otrub")) and RED or GREEN)
    row("Боль", math.Round(number("pain")), number("pain") >= 60 and "Сильная боль." or "", number("pain") >= 60 and RED or (number("pain") >= 30 and ORANGE or GREEN))
    row("Дыхание", flag("choking") and "УДУШЬЕ" or (number("pneumothorax") > 0 and "ПНЕВМОТОРАКС" or (data.lungsfunction == false and "НАРУШЕНО" or "БЕЗ ЯВНЫХ НАРУШЕНИЙ")), "", (flag("choking") or number("pneumothorax") > 0 or data.lungsfunction == false) and RED or GREEN)

    section("КРОВОТЕЧЕНИЯ И ТРАВМЫ")
    local artery = number("arteria") > 0
    for _, key in ipairs({"larmartery", "rarmartery", "llegartery", "rlegartery", "spineartery"}) do
        if number(key) > 0 then artery = true end
    end
    row("Артериальное кровотечение", artery and "ЕСТЬ" or "НЕ ОБНАРУЖЕНО", "", artery and RED or GREEN)
    row("Наружное кровотечение", number("bleed") > 0 and "ЕСТЬ" or "НЕ ОБНАРУЖЕНО", "", number("bleed") > 0 and ORANGE or GREEN)
    row("Внутреннее кровотечение", number("internalBleed") > 0 and "ЕСТЬ" or "НЕ ОБНАРУЖЕНО", "", number("internalBleed") > 0 and RED or GREEN)

    local limbNames = {lleg = "Левая нога", rleg = "Правая нога", larm = "Левая рука", rarm = "Правая рука"}
    local traumaFound = false
    for _, key in ipairs({"lleg", "rleg", "larm", "rarm"}) do
        local status = flag(key .. "amputated") and "АМПУТАЦИЯ" or (flag(key .. "dislocation") and "ВЫВИХ" or (number(key) >= 1 and "ПЕРЕЛОМ" or (number(key) > 0.3 and "ТРАВМА" or nil)))
        if status then
            row(limbNames[key], status, "Зафиксировано повреждение конечности.", (status == "АМПУТАЦИЯ" or status == "ПЕРЕЛОМ") and RED or ORANGE)
            traumaFound = true
        end
    end
    for _, wound in ipairs({
        {"bulletwounds", "Огнестрельные раны"}, {"stabwounds", "Колотые раны"}, {"slashwounds", "Резаные раны"},
        {"explosionwounds", "Осколочные раны"}, {"burns", "Ожоги"}, {"bruises", "Ушибы"}
    }) do
        local count = number(wound[1])
        if count > 0 then row(wound[2], tostring(math.Round(count, 1)), "Количество повреждений.", count >= 3 and RED or ORANGE); traumaFound = true end
    end
    if not traumaFound then row("Повреждения", "НЕ ОБНАРУЖЕНЫ", "По доступным данным травм нет.", GREEN) end
end

net.Receive("idcard_medical_exam_data", function()
    local patient, data = net.ReadEntity(), net.ReadTable()
    OpenPatientMedicalReport(patient, data)
end)

surface.CreateFont("IDCardUseHint", {font = "Tahoma", size = 14, weight = 500, antialias = true, extended = true})
hook.Add("HUDPaint", "IDCard.NearbyPlayerUseHint", function()
    if IsValid(actionFrame) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local trace = ply:GetEyeTrace()
    local target = trace.Entity
    if not IsValid(target) then return end
    local isPlayer = target:IsPlayer() and target ~= ply
    local class = string.lower(target:GetClass() or "")
    local isGlide = target.IsGlideVehicle == true or string.StartWith(class, "glide_")
    if not isPlayer and not isGlide then return end
    if ply:GetPos():DistToSqr(target:GetPos()) > 220 * 220 then return end

    local label = isGlide and "E — СЕСТЬ   •   R — ПАССАЖИР" or "ВЗАИМОДЕЙСТВИЕ"
    surface.SetFont("IDCardUseHint")
    local labelW = surface.GetTextSize(label)
    local width, height = labelW + 48, 28
    local x, y = (ScrW() - width) * 0.5, ScrH() * 0.72
    draw.RoundedBox(7, x, y, width, height, Color(10, 12, 16, 220))
    surface.SetDrawColor(164, 173, 182, 58)
    surface.DrawOutlinedRect(x, y, width, height, 1)
    draw.RoundedBox(4, x + 5, y + 4, 24, 20, Color(64, 70, 79, 180))
    draw.SimpleText("E", "IDCardUseHint", x + 17, y + 14, Color(232, 235, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(label, "IDCardUseHint", x + 36, y + 14, Color(197, 202, 208), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

-- The Z-City SelfCheck addon exposes its feature through the client command
-- SelfCheck and adds the same command to the radial/Q menu. Keep the command
-- and radial entry available only to medical jobs; the interaction menu gets
-- a separate button for medics above.
local function IsLocalMedic()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    return ply:GetNW2String("IDCardProfession", "citizen") == "paramedic"
end

local function InstallSelfCheckRestrictions()
    local original = _G.IDCardZMedOriginalSelfCheck or concommand.GetTable().SelfCheck
    if not isfunction(original) then return false end
    _G.IDCardZMedOriginalSelfCheck = original

    concommand.Add("SelfCheck", function(ply, command, args)
        if not IsLocalMedic() then return end
        original(ply or LocalPlayer(), command or "SelfCheck", args or {})
    end)

    hook.Remove("radialOptions", "ZMed_Radial")
    hook.Add("radialOptions", "ZMed_Radial", function()
        if not IsLocalMedic() or not (hg and istable(hg.radialOptions)) then return end
        for _, option in ipairs(hg.radialOptions) do
            if istable(option) and option.zmed then return end
        end
        local label = (ZMed and ZMed.L and ZMed.L("radial_condition")) or "Состояние"
        local option = {function() RunConsoleCommand("SelfCheck") end, label}
        option.zmed = true
        hg.radialOptions[#hg.radialOptions + 1] = option
    end)
    return true
end

timer.Create("IDCard.InstallZMedRestrictions", 0.5, 0, function()
    if InstallSelfCheckRestrictions() then timer.Remove("IDCard.InstallZMedRestrictions") end
end)
