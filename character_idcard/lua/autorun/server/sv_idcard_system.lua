if not SERVER then return end

local NET = {
    register = "idcard_register",
    registrationResult = "idcard_registration_result",
    openRegistration = "idcard_open_registration",
    showCard = "idcard_show_card",
    cardAction = "idcard_card_action",
    openActions = "idcard_open_actions",
    actionRequest = "idcard_action_request",
    actionResult = "idcard_action_result",
    medicalExam = "idcard_medical_exam_data",
}
local ROLEPLAY_YEAR = 2020
for _, name in pairs(NET) do util.AddNetworkString(name) end

local function EnsureDatabase()
    sql.Query([[CREATE TABLE IF NOT EXISTS idcard_characters (
        steamid64 TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        age INTEGER NOT NULL DEFAULT 18,
        gender TEXT NOT NULL DEFAULT 'male',
        birth_year INTEGER NOT NULL DEFAULT 2006,
        birth_month INTEGER NOT NULL DEFAULT 1,
        document_number INTEGER NOT NULL DEFAULT 0
    )]])
    -- Migrate older local databases without deleting existing characters.
    local columns = sql.Query("PRAGMA table_info(idcard_characters)") or {}
    local found = {}
    for _, column in ipairs(columns) do found[column.name] = true end
    if not found.age then sql.Query("ALTER TABLE idcard_characters ADD COLUMN age INTEGER NOT NULL DEFAULT 18") end
    if not found.gender then sql.Query("ALTER TABLE idcard_characters ADD COLUMN gender TEXT NOT NULL DEFAULT 'male'") end
    if not found.birth_year then sql.Query("ALTER TABLE idcard_characters ADD COLUMN birth_year INTEGER NOT NULL DEFAULT 2006") end
    if not found.birth_month then sql.Query("ALTER TABLE idcard_characters ADD COLUMN birth_month INTEGER NOT NULL DEFAULT 1") end
    if not found.document_number then sql.Query("ALTER TABLE idcard_characters ADD COLUMN document_number INTEGER NOT NULL DEFAULT 0") end
    sql.Query("UPDATE idcard_characters SET gender = 'male' WHERE gender = 'Мужской'")
    sql.Query("UPDATE idcard_characters SET gender = 'female' WHERE gender = 'Женский'")

    local currentYear = tonumber(os.date("%Y")) or 2026
    local oldRows = sql.Query("SELECT steamid64, age FROM idcard_characters WHERE birth_year = 2006 AND birth_month = 1") or {}
    for _, row in ipairs(oldRows) do
        local oldAge = math.Clamp(tonumber(row.age) or 20, 18, 100)
        sql.Query("UPDATE idcard_characters SET birth_year = " .. (currentYear - oldAge) .. " WHERE steamid64 = " .. sql.SQLStr(row.steamid64))
    end

    local numberRows = sql.Query("SELECT steamid64 FROM idcard_characters WHERE document_number = 0 OR document_number IS NULL") or {}
    local maxRow = sql.QueryRow("SELECT MAX(document_number) AS max_number FROM idcard_characters")
    local nextNumber = math.max(tonumber(maxRow and maxRow.max_number) or 7299999999, 7299999999)
    for _, row in ipairs(numberRows) do
        nextNumber = nextNumber + 1
        sql.Query("UPDATE idcard_characters SET document_number = " .. nextNumber .. " WHERE steamid64 = " .. sql.SQLStr(row.steamid64))
    end
    sql.Query("CREATE UNIQUE INDEX IF NOT EXISTS idcard_document_number_unique ON idcard_characters(document_number)")
end
hook.Add("Initialize", "IDCard.EnsureDatabase", EnsureDatabase)
EnsureDatabase()

local function LoadCharacter(ply)
    local steamID64 = ply:SteamID64()
    if not steamID64 or steamID64 == "0" then return false end
    local row = sql.QueryRow("SELECT first_name, last_name, birth_year, birth_month, gender, document_number FROM idcard_characters WHERE steamid64 = " .. sql.SQLStr(steamID64))
    if not row then return false end
    ply:SetNW2String("IDCardFirstName", row.first_name or "")
    ply:SetNW2String("IDCardLastName", row.last_name or "")
    ply:SetNW2Int("IDCardBirthYear", tonumber(row.birth_year) or 2006)
    ply:SetNW2Int("IDCardBirthMonth", tonumber(row.birth_month) or 1)
    ply:SetNW2String("IDCardGender", row.gender or "male")
    ply:SetNW2String("IDCardDocumentNumber", tostring(row.document_number or ""))
    ply.IDCardRegistered = true
    return true
end

local function IsRegistered(ply)
    return IsValid(ply) and ply.IDCardRegistered == true
end

local function ResetSessionData(ply)
    if not IsValid(ply) then return end
    ply:SetNW2Bool("HasBusinessLicense", false)
    ply:SetNW2Bool("HasDrivingLicense", false)
    ply:SetNW2Bool("HasGunlicense", false)
    ply:SetNW2Bool("IDCardWanted", false)
    ply:SetNW2String("IDCardWantedReason", "")
    if ply.setDarkRPVar then pcall(ply.setDarkRPVar, ply, "HasGunlicense", false) end
end

local function SendActionResult(ply, ok, message)
    net.Start(NET.actionResult)
        net.WriteBool(ok)
        net.WriteString(message or "")
    net.Send(ply)
end

local function SendCard(viewer, owner, showActor)
    if not IsValid(viewer) or not IsValid(owner) or not IsRegistered(owner) then return false end
    if IsValid(showActor) then
        local cooldownEnd = showActor.IDCardNextShowAt or 0
        if cooldownEnd > CurTime() then
            SendActionResult(showActor, false, "ID-карту можно снова показать через " .. math.ceil(cooldownEnd - CurTime()) .. " сек.")
            return false
        end
        showActor.IDCardNextShowAt = CurTime() + 15
    end
    local hasGunLicense = owner:GetNW2Bool("HasGunlicense", false)
    if owner.getDarkRPVar then
        local ok, value = pcall(owner.getDarkRPVar, owner, "HasGunlicense")
        if ok and value == true then hasGunLicense = true end
    end
    net.Start(NET.showCard)
        net.WriteString(owner:GetNW2String("IDCardFirstName", ""))
        net.WriteString(owner:GetNW2String("IDCardLastName", ""))
        net.WriteUInt(owner:GetNW2Int("IDCardBirthYear", 2006), 12)
        net.WriteUInt(owner:GetNW2Int("IDCardBirthMonth", 1), 4)
        net.WriteString(owner:GetNW2String("IDCardGender", "male"))
        net.WriteString(owner:GetNW2String("IDCardDocumentNumber", ""))
        net.WriteString(owner:GetModel() or "models/player/kleiner.mdl")
        net.WriteBool(hasGunLicense)
        net.WriteBool(owner:GetNW2Bool("HasBusinessLicense", false))
        net.WriteBool(owner:GetNW2Bool("HasDrivingLicense", false))
        net.WriteBool(owner:GetNW2Bool("IDCardWanted", false))
        net.WriteString(owner:GetNW2String("IDCardWantedReason", ""))
    net.Send(viewer)
    return true
end

-- Z-City marks restrained players with the handcuffed netvar.
local function IsHandcuffed(ply)
    if not IsValid(ply) then return false end
    if isfunction(ply.GetNetVar) then
        local ok, value = pcall(ply.GetNetVar, ply, "handcuffed", false)
        if ok and value == true then return true end
    end
    return ply:GetNWBool("handcuffed", false) or ply:GetNW2Bool("handcuffed", false)
end

local function SanitizeMedicalData(source, depth)
    local clean = {}
    if not istable(source) or depth > 3 then return clean end
    for key, value in pairs(source) do
        if isstring(key) or isnumber(key) then
            if isnumber(value) or isstring(value) or isbool(value) then
                clean[key] = value
            elseif istable(value) and not value.IsValid then
                clean[key] = SanitizeMedicalData(value, depth + 1)
            end
        end
    end
    return clean
end

local function SendMedicalExam(medic, patient)
    if not IsValid(medic) or not IsValid(patient) then return end
    medic.IDCardNextMedicalExam = medic.IDCardNextMedicalExam or 0
    if medic.IDCardNextMedicalExam > CurTime() then
        SendActionResult(medic, false, "Подождите перед следующим осмотром.")
        return
    end
    medic.IDCardNextMedicalExam = CurTime() + 1

    local data = SanitizeMedicalData(patient.organism, 1)
    data._source = istable(patient.organism) and "organism" or "none"
    data._alive = patient:Alive()
    data._name = string.sub(patient:Nick(), 1, 64)
    net.Start(NET.medicalExam)
        net.WriteEntity(patient)
        net.WriteTable(data)
    net.Send(medic)
end

local function IsMedic(ply)
    return IsValid(ply) and ply:GetNW2String("IDCardProfession", "citizen") == "paramedic"
end

-- Detect E directly: some gamemodes do not dispatch PlayerUse for player targets.
local function OpenInteractionMenu(ply, ent)
    if not IsRegistered(ply) or not IsValid(ent) or not ent:IsPlayer() or ent == ply then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 160 * 160 then return end
    net.Start(NET.openActions)
        net.WriteEntity(ent)
        net.WriteBool(IsHandcuffed(ent))
        net.WriteBool(ent:InVehicle())
        net.WriteBool(IsMedic(ply))
    net.Send(ply)
end

hook.Add("KeyPress", "IDCard.OpenInteractionMenuOnE", function(ply, key)
    if key ~= IN_USE then return end
    local trace = ply:GetEyeTrace()
    OpenInteractionMenu(ply, trace.Entity)
end)

local function IsGlideVehicle(ent)
    if not IsValid(ent) then return false end
    local class = string.lower(ent:GetClass() or "")
    return ent.IsGlideVehicle == true or string.StartWith(class, "glide_")
end

local function FindCuffedGlideOccupant(vehicle)
    if not IsGlideVehicle(vehicle) or not istable(vehicle.seats) then return end
    for _, seat in pairs(vehicle.seats) do
        if not IsValid(seat) then continue end
        local occupant = seat:GetDriver()
        if IsValid(occupant) and occupant:IsPlayer() and IsHandcuffed(occupant) then
            return occupant
        end
    end
end

-- E stays available for normal vehicle entry. Press R while aiming at a
-- Glide vehicle to open actions for its restrained occupant.
hook.Add("KeyPress", "IDCard.OpenCuffedPassengerActionsOnReload", function(ply, key)
    if key ~= IN_RELOAD or not IsRegistered(ply) then return end
    local vehicle = ply:GetEyeTrace().Entity
    if not IsGlideVehicle(vehicle) then return end
    local target = FindCuffedGlideOccupant(vehicle)
    if not IsValid(target) or ply:GetPos():DistToSqr(target:GetPos()) > 200 * 200 then return end
    net.Start(NET.openActions)
        net.WriteEntity(target)
        net.WriteBool(true)
        net.WriteBool(true)
        net.WriteBool(IsMedic(ply))
    net.Send(ply)
end)

local function FindFreeGlidePassengerSeat(target)
    local candidates = {}
    local boardingRadius = 120 -- Keep the restrained player right beside the vehicle.
    for _, vehicle in ipairs(ents.FindInSphere(target:GetPos(), boardingRadius)) do
        if IsGlideVehicle(vehicle) and istable(vehicle.seats) then
            -- Glide uses separate vehicle seat entities; index 1 is the driver.
            for index, seat in pairs(vehicle.seats) do
                if tonumber(index) and tonumber(index) > 1 and IsValid(seat) and seat:IsVehicle()
                    and target:GetPos():DistToSqr(seat:GetPos()) <= boardingRadius * boardingRadius
                    and not IsValid(seat:GetDriver()) then
                    candidates[#candidates + 1] = {
                        vehicle = vehicle,
                        seat = seat,
                        distance = target:GetPos():DistToSqr(seat:GetPos())
                    }
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    return candidates[1] and candidates[1].vehicle, candidates[1] and candidates[1].seat
end

net.Receive(NET.actionRequest, function(_, ply)
    if not IsRegistered(ply) then return end
    local action = net.ReadUInt(3)
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() or target == ply
        or ply:GetPos():DistToSqr(target:GetPos()) > 160 * 160 then return end

    if action == 0 then
        SendCard(ply, target)
        return
    end
    if action == 2 then
        -- Show the actor's own card to the nearby player.
        SendCard(target, ply, ply)
        return
    end
    if action == 5 then
        if not IsHandcuffed(target) or target:InVehicle() then
            SendActionResult(ply, false, "Сопровождать можно только закованного человека вне машины.")
            return
        end
        if target.IDCardEscortedBy == ply then
            target.IDCardEscortedBy = nil
            ply.IDCardEscorting = nil
            SendActionResult(ply, true, "Сопровождение остановлено.")
            return
        end
        if IsValid(ply.IDCardEscorting) then ply.IDCardEscorting.IDCardEscortedBy = nil end
        if IsValid(target.IDCardEscortedBy) then target.IDCardEscortedBy.IDCardEscorting = nil end
        ply.IDCardEscorting = target
        target.IDCardEscortedBy = ply
        SendActionResult(ply, true, "Вы ведёте задержанного за собой. Нажмите действие ещё раз, чтобы остановить.")
        return
    end
    if action == 4 then
        if not IsMedic(ply) then
            SendActionResult(ply, false, "Осматривать пациентов могут только медики.")
            return
        end
        SendMedicalExam(ply, target)
        return
    end
    if action == 3 then
        if not IsHandcuffed(target) or not target:InVehicle() then
            SendActionResult(ply, false, "Игрок должен быть в наручниках и находиться в машине.")
            return
        end
        target:ExitVehicle()
        SendActionResult(ply, true, "Игрок вытащен из машины.")
        return
    end
    if action ~= 1 then return end
    if not IsHandcuffed(target) then
        SendActionResult(ply, false, "Сначала наденьте на человека наручники.")
        return
    end
    if target:InVehicle() then
        SendActionResult(ply, false, "Человек уже находится в машине.")
        return
    end
    local vehicle, seat = FindFreeGlidePassengerSeat(target)
    if not IsValid(vehicle) or not IsValid(seat) then
        SendActionResult(ply, false, "Рядом нет свободного пассажирского места в машине Glide.")
        return
    end
    timer.Simple(0, function()
        if not IsValid(ply) or not IsValid(target) or not IsValid(vehicle) or not IsValid(seat) then return end
        if not IsHandcuffed(target) or ply:GetPos():DistToSqr(target:GetPos()) > 180 * 180 then return end
        if isfunction(seat.GetDriver) and IsValid(seat:GetDriver()) then
            SendActionResult(ply, false, "Это место уже заняли.")
            return
        end
        if Glide and isfunction(Glide.EnterVehicleSeat) and vehicle.IsGlideVehicle == true then
            Glide.EnterVehicleSeat(target, vehicle, seat)
        else
            target:EnterVehicle(seat)
        end
        SendActionResult(ply, true, "Человек посажен на пассажирское место.")
    end)
end)


local function StopEscort(handler, target, message)
    if IsValid(handler) and handler.IDCardEscorting == target then handler.IDCardEscorting = nil end
    if IsValid(target) and target.IDCardEscortedBy == handler then target.IDCardEscortedBy = nil end
    if message and IsValid(handler) then SendActionResult(handler, false, message) end
end

timer.Create("IDCard.EscortRestrainedPlayers", 0.1, 0, function()
    for _, handler in ipairs(player.GetAll()) do
        local target = handler.IDCardEscorting
        if not IsValid(target) then
            handler.IDCardEscorting = nil
            continue
        end
        if target.IDCardEscortedBy ~= handler or not IsHandcuffed(target) then
            StopEscort(handler, target, "Сопровождение завершено.")
            continue
        end
        if not handler:Alive() or not target:Alive() or handler:InVehicle() or target:InVehicle() then
            StopEscort(handler, target, "Сопровождение остановлено.")
            continue
        end
        local goal = handler:GetPos() - handler:GetForward() * 52
        local delta = goal - target:GetPos()
        delta.z = 0
        local distance = delta:Length()
        if distance > 620 then
            StopEscort(handler, target, "Задержанный слишком далеко; сопровождение остановлено.")
        elseif distance > 58 then
            local direction = delta:GetNormalized()
            local desiredSpeed = math.min(165, math.max(65, distance * 2.5))
            local velocity = target:GetVelocity()
            local correction = Vector(direction.x * desiredSpeed - velocity.x, direction.y * desiredSpeed - velocity.y, 0)
            target:SetVelocity(correction)
        end
    end
end)

hook.Add("PlayerDeath", "IDCard.StopEscortOnDeath", function(ply)
    if IsValid(ply.IDCardEscorting) then StopEscort(ply, ply.IDCardEscorting) end
    if IsValid(ply.IDCardEscortedBy) then StopEscort(ply.IDCardEscortedBy, ply) end
end)
hook.Add("PlayerDisconnected", "IDCard.StopEscortOnDisconnect", function(ply)
    if IsValid(ply.IDCardEscorting) then StopEscort(ply, ply.IDCardEscorting) end
    if IsValid(ply.IDCardEscortedBy) then StopEscort(ply.IDCardEscortedBy, ply) end
end)

-- Block voluntary exits from every vehicle while Z-City handcuffs are active.
hook.Add("CanExitVehicle", "IDCard.KeepCuffedPlayersSeated", function(_, ply)
    if IsHandcuffed(ply) then return false end
end)

hook.Add("PlayerInitialSpawn", "IDCard.LoadCharacter", function(ply)
    ResetSessionData(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if not LoadCharacter(ply) then
            ply.IDCardAwaitingRegistration = true
            -- InitialSpawn happens while the client is still loading Lua. Retry
            -- briefly so the first registration message cannot be missed.
            local timerName = "IDCard.RegistrationPrompt." .. ply:SteamID64()
            local attempts = 0
            timer.Create(timerName, 2, 15, function()
                if not IsValid(ply) or not ply.IDCardAwaitingRegistration then
                    timer.Remove(timerName)
                    return
                end
                attempts = attempts + 1
                net.Start(NET.openRegistration)
                net.Send(ply)
                if attempts >= 15 then timer.Remove(timerName) end
            end)
        end
    end)
end)

-- Hold a new character in spectator until their registration has been saved.
hook.Add("PlayerSpawn", "IDCard.RequireRegistration", function(ply)
    if ply.IDCardAwaitingRegistration and not IsRegistered(ply) then
        timer.Simple(0, function()
            if IsValid(ply) and not IsRegistered(ply) then
                ply:KillSilent()
                ply:Spectate(OBS_MODE_ROAMING)
                net.Start(NET.openRegistration)
                net.Send(ply)
            end
        end)
        return true
    end
end)

net.Receive(NET.register, function(_, ply)
    if not IsValid(ply) or not ply.IDCardAwaitingRegistration then return end
    local first = string.Trim(net.ReadString())
    local last = string.Trim(net.ReadString())
    local birthYear = net.ReadUInt(12)
    local birthMonth = net.ReadUInt(4)
    local gender = net.ReadString()
    first, last = string.sub(first, 1, 32), string.sub(last, 1, 32)
    local function validName(value)
        return #value >= 2 and #value <= 32 and string.match(value, "^[%wА-Яа-яЁё%-]+$") ~= nil
    end
    if not validName(first) or not validName(last) then
        net.Start(NET.registrationResult) net.WriteBool(false) net.WriteString("Введите имя и фамилию: от 2 до 32 букв.") net.Send(ply)
        return
    end
    local age = ROLEPLAY_YEAR - birthYear
    if birthYear < ROLEPLAY_YEAR - 100 or birthYear > ROLEPLAY_YEAR - 18 or birthMonth < 1 or birthMonth > 12
        or age < 18 or age > 100 or (gender ~= "male" and gender ~= "female") then
        net.Start(NET.registrationResult) net.WriteBool(false) net.WriteString("Проверьте месяц и год рождения (возраст персонажа должен быть от 18 до 100 лет).") net.Send(ply)
        return
    end

    local id = ply:SteamID64()
    local numberRow = sql.QueryRow("SELECT MAX(document_number) AS max_number FROM idcard_characters")
    local documentNumber = math.max(tonumber(numberRow and numberRow.max_number) or 7299999999, 7299999999) + 1
    local query = "INSERT OR REPLACE INTO idcard_characters (steamid64, first_name, last_name, age, gender, birth_year, birth_month, document_number) VALUES (" ..
        sql.SQLStr(id) .. ", " .. sql.SQLStr(first) .. ", " .. sql.SQLStr(last) .. ", " .. age .. ", " .. sql.SQLStr(gender) .. ", " ..
        birthYear .. ", " .. birthMonth .. ", " .. documentNumber .. ")"
    if sql.Query(query) == false then
        net.Start(NET.registrationResult) net.WriteBool(false) net.WriteString("Ошибка сохранения. Повторите попытку.") net.Send(ply)
        return
    end

    ply:SetNW2String("IDCardFirstName", first)
    ply:SetNW2String("IDCardLastName", last)
    ply:SetNW2Int("IDCardBirthYear", birthYear)
    ply:SetNW2Int("IDCardBirthMonth", birthMonth)
    ply:SetNW2String("IDCardGender", gender)
    ply:SetNW2String("IDCardDocumentNumber", tostring(documentNumber))
    ply.IDCardRegistered = true
    ply.IDCardAwaitingRegistration = false
    timer.Remove("IDCard.RegistrationPrompt." .. id)
    ply:UnSpectate()
    net.Start(NET.registrationResult) net.WriteBool(true) net.WriteString("") net.Send(ply)
    timer.Simple(0.25, function() if IsValid(ply) then ply:Spawn() end end)
end)

local function GiveIDCard(ply)
    if not IsRegistered(ply) then return end
    if not ply:HasWeapon("weapon_idcard") then ply:Give("weapon_idcard") end
end

hook.Add("PlayerLoadout", "IDCard.GiveWeapon", function(ply)
    GiveIDCard(ply)
end)

-- Some custom gamemodes (including Z-City variants) replace DarkRP's loadout
-- flow, so also grant the card just after the player spawn has completed.
hook.Add("PlayerSpawn", "IDCard.GiveWeaponAfterSpawn", function(ply)
    timer.Simple(0, function()
        if IsValid(ply) then GiveIDCard(ply) end
    end)
end)

hook.Add("PlayerDeath", "IDCard.ResetOnDeath", ResetSessionData)
hook.Add("PlayerDisconnected", "IDCard.ResetOnDisconnect", ResetSessionData)

net.Receive(NET.cardAction, function(_, ply)
    if not IsRegistered(ply) then return end
    local action = net.ReadUInt(2)
    if action == 0 then
        SendCard(ply, ply)
    elseif action == 1 then
        local trace = ply:GetEyeTrace()
        local target = trace.Entity
        if not IsValid(target) or not target:IsPlayer() then return end
        if ply:GetPos():DistToSqr(target:GetPos()) > 250 * 250 then return end
        SendCard(target, ply, ply)
    end
end)

local function IsAuthority(ply)
    if not IsValid(ply) then return false end
    if ply:IsAdmin() then return true end
    local profession = ply:GetNW2String("IDCardProfession", "citizen")
    if profession == "police" or profession == "mayor" then return true end
    local name = string.lower(team.GetName(ply:Team()) or "")
    return string.find(name, "police", 1, true) ~= nil or string.find(name, "поли", 1, true) ~= nil
        or string.find(name, "mayor", 1, true) ~= nil or string.find(name, "мэр", 1, true) ~= nil
end

local function FindTarget(query)
    query = string.Trim(string.lower(query or ""))
    for _, target in ipairs(player.GetAll()) do
        if target:SteamID64() == query or string.find(string.lower(target:Nick()), query, 1, true) then return target end
    end
end

local function AdminNotice(ply, message)
    if IsValid(ply) then ply:ChatPrint(message) else print("[IDCard] " .. message) end
end

local function SetLicense(ply, target, kind, enabled)
    if kind == "weapon" then
        if target.setDarkRPVar then pcall(target.setDarkRPVar, target, "HasGunlicense", enabled) end
        target:SetNW2Bool("HasGunlicense", enabled)
    elseif kind == "business" then
        target:SetNW2Bool("HasBusinessLicense", enabled)
    else
        target:SetNW2Bool("HasDrivingLicense", enabled)
    end
    ply:ChatPrint((enabled and "Выдана" or "Отозвана") .. " лицензия игроку " .. target:Nick() .. ".")
end

local function LicenseCommand(kind)
    return function(ply, _, args)
        if not IsAuthority(ply) then if IsValid(ply) then ply:ChatPrint("Недостаточно прав.") end return end
        local target = FindTarget(args[1])
        if not IsValid(target) then ply:ChatPrint("Игрок не найден.") return end
        local verb = string.lower(args[2] or "")
        local enabled = verb == "выдать" or verb == "дать" or verb == "1" or verb == "on"
        SetLicense(ply, target, kind, enabled)
    end
end

concommand.Add("idcard_weapon_license", LicenseCommand("weapon"))
concommand.Add("idcard_business_license", LicenseCommand("business"))
concommand.Add("idcard_driving_license", LicenseCommand("driving"))

-- Local test/admin utility: remove the saved identity and reopen registration.
concommand.Add("idcard_reset_character", function(ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local id = ply:SteamID64()
    sql.Query("DELETE FROM idcard_characters WHERE steamid64 = " .. sql.SQLStr(id))
    ply.IDCardRegistered = false
    ply.IDCardAwaitingRegistration = true
    ply:SetNW2String("IDCardFirstName", "")
    ply:SetNW2String("IDCardLastName", "")
    net.Start(NET.openRegistration)
    net.Send(ply)
    ply:ChatPrint("Данные персонажа удалены. Заполните форму регистрации.")
end)

_G.IDCardSystem = _G.IDCardSystem or {}
function IDCardSystem.SetWanted(target, enabled, reason)
    if not IsValid(target) then return end
    target:SetNW2Bool("IDCardWanted", enabled == true)
    target:SetNW2String("IDCardWantedReason", enabled and string.sub(tostring(reason or "Причина не указана"), 1, 128) or "")
end

function IDCardSystem.SetDrivingLicense(target, enabled)
    if not IsValid(target) then return end
    target:SetNW2Bool("HasDrivingLicense", enabled == true)
end

hook.Add("PlayerSay", "IDCard.ChatLicenseCommands", function(ply, text)
	local command, targetName, verb = string.match(text, "^!(%S+)%s+(.+)%s+(%S+)$")
    if command ~= "idgun" and command ~= "idbiz" and command ~= "iddrive" then return end
    if not IsAuthority(ply) then ply:ChatPrint("Недостаточно прав.") return "" end
    local target = FindTarget(targetName)
    if not IsValid(target) then ply:ChatPrint("Игрок не найден.") return "" end
    local normalized = string.lower(verb)
    local enabled = normalized == "выдать" or normalized == "дать" or normalized == "1"
    local kind = command == "idgun" and "weapon" or (command == "idbiz" and "business" or "driving")
    SetLicense(ply, target, kind, enabled)
    return ""
end)
