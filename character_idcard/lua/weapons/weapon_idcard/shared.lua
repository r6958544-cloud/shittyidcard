SWEP.Base = "weapon_base"
SWEP.PrintName = "ID-карта"
SWEP.Author = "Character ID Card"
SWEP.Instructions = "ЛКМ — посмотреть карту. ПКМ — показать ближайшему игроку."
SWEP.Category = "DarkRP"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = "models/props_lab/clipboard.mdl"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1)
    if CLIENT then
        net.Start("idcard_card_action") net.WriteUInt(0, 2) net.SendToServer()
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 1)
    if CLIENT then
        net.Start("idcard_card_action") net.WriteUInt(1, 2) net.SendToServer()
    end
end
