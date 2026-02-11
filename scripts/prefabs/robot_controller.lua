local assets = {
    Asset("ANIM", "anim/transistor.zip"),
    Asset("IMAGE", "images/inventoryimages/robot_controller.tex"),
    Asset("ATLAS", "images/inventoryimages/robot_controller.xml"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("transistor")
    inst.AnimState:SetBuild("transistor")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("robot_controller")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/robot_controller.xml"
    inst.components.inventoryitem.imagename = "robot_controller"
    inst:AddComponent("inspectable")

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("robot_controller", fn, assets)
