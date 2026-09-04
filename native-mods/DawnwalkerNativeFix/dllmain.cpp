// DawnwalkerNativeFix: native replacement for the Lua GiveBestGear path.
//
// Root cause (fully confirmed via UE4SS source, see repo memory): Lua's
// UFunction call marshalling (LuaUObject.cpp::call_ufunction_from_lua) turns
// a returned FItemHandle into a Lua table built from its REFLECTED
// UProperty members only. FItemHandle has zero reflected properties, so the
// "handle" Lua receives is an empty table, and passing it back into
// TryAddItem copies nothing into the destination struct - it stays
// zero-initialized, which the game resolves to a placeholder item.
//
// Fix: call GetItemHandle and TryAddItem/TryAddAndEquipItem via raw
// ProcessEvent with our own zero-initialized byte buffers (each function-call
// buffer sized via UFunction::GetParmsSize() - NOT GetStructureSize(), which
// computes UStruct::PropertiesSize and can differ from ParmsSize; an
// undersized ProcessEvent buffer overflows the heap silently instead of
// crashing immediately, see repo memory. GetStructureSize() IS still correct
// for sizing the FItemHandle UScriptStruct itself), locate each named
// parameter's byte offset live via UStruct::FindProperty()/
// FProperty::GetOffset_Internal(), and memcpy the struct's raw bytes directly
// between the two calls. This never needs to know FItemHandle's internal
// field layout, and tolerates the game renaming unrelated fields/functions
// as long as the names used below still exist.
//
// Item list and default item level are ported 1:1 from
// runtime-mods/DawnwalkerModBridge/Scripts/main.lua's (now-disabled)
// BEST_GEAR_WEAPONS/ARMOR/JEWELRY tables and GiveBestGear(). See repo memory
// for the rarity/damage/toughness scan behind these picks.

#include <Mod/CppUserModBase.hpp>
#include <Unreal/UObjectGlobals.hpp>
#include <Unreal/UObject.hpp>
#include <Unreal/AActor.hpp>
#include <Unreal/NameTypes.hpp>
#include <Unreal/CoreUObject/UObject/Class.hpp>
#include <Unreal/CoreUObject/UObject/UnrealType.hpp>
#include <Unreal/UFunctionStructs.hpp>
#include <Helpers/String.hpp>

#include <cstring>
#include <cstdint>
#include <vector>
#include <fstream>
#include <sstream>
#include <atomic>
#include <algorithm>

using namespace RC;
using namespace RC::Unreal;

namespace
{
    constexpr auto kCommandPath = "Mods/DawnwalkerNativeFix/command.txt";
    constexpr auto kStatusPath = "Mods/DawnwalkerNativeFix/status.txt";

    struct GearItem
    {
        const CharType* Path;
        bool Equip;
    };

    // A selectable catalog entry (one weapon, one full armor set, one ring, one amulet, ...) that
    // the UI's gear dropdowns pick from by Id - Id is an ANSI string since it's matched directly
    // against command.txt's plain-text lines, never passed to UE reflection.
    struct GearOption
    {
        const char* Id;
        const GearItem* Items;
        size_t ItemCount;
    };

    const GearItem kWeaponShortSword[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordBlacksmithMasterpice2a.ITM_Weapon_SwordBlacksmithMasterpice2a"), false} };
    const GearItem kWeaponLongSword[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordErkas1a.ITM_Weapon_SwordErkas1a"), false} };
    const GearItem kWeaponGreatsword[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordDawnwalker5a.ITM_Weapon_SwordDawnwalker5a"), true} };
    const GearItem kWeaponHeavy[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_MaceMaster1a.ITM_Weapon_MaceMaster1a"), false} };
    // Named/"Unique"-tier weapons (no Common/Superior/Master/Epic numeric-tier prefix in the asset
    // name, same naming convention as the named jewelry below) - found by grepping
    // UE4SS_ObjectDump.txt's ItemWeaponDataAsset instances for standalone names. Weapon TYPE
    // (short/long/greatsword/heavy) isn't derivable from the asset name alone and would need live
    // instance data to confirm, so these are offered as their own category instead of being sorted
    // into the type-specific dropdowns above.
    const GearItem kWeaponAmbrus[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordAmbrus1a.ITM_Weapon_SwordAmbrus1a"), false} };
    const GearItem kWeaponAncient[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordAncient1a.ITM_Weapon_SwordAncient1a"), false} };
    const GearItem kWeaponGargoyle[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordGargoyle1a.ITM_Weapon_SwordGargoyle1a"), false} };
    const GearItem kWeaponVampiric[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordVampiric1a.ITM_Weapon_SwordVampiric1a"), false} };
    const GearItem kWeaponMercenary[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordMercenary1a.ITM_Weapon_SwordMercenary1a"), false} };
    const GearItem kWeaponUnique1[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordUnique1a.ITM_Weapon_SwordUnique1a"), false} };
    const GearItem kWeaponUnique2[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordUnique2a.ITM_Weapon_SwordUnique2a"), false} };
    const GearItem kWeaponUnique3[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Weapon_SwordUnique3a.ITM_Weapon_SwordUnique3a"), false} };
    // Five complete 4-piece "Unique" armor sets (Chest/Legs/Hands/Feet, all equip=true), found by
    // grouping UE4SS_ObjectDump.txt's ItemClothingDataAsset instances by their theme suffix - the
    // previous single "best" set was actually a mismatched hybrid of two different themes (Ancient
    // chest/legs + Dawnwalker2a hands/feet); these are the real, properly-matched sets instead.
    const GearItem kArmorSetAncient[] = {
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_ChestUniqueAncient1a.ITM_Clothing_ChestUniqueAncient1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LegsUniqueAncient1a.ITM_Clothing_LegsUniqueAncient1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_HandsUniqueAncient1a.ITM_Clothing_HandsUniqueAncient1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FeetUniqueAncient1a.ITM_Clothing_FeetUniqueAncient1a"), true},
    };
    const GearItem kArmorSetDawnwalker1[] = {
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_ChestUniqueDawnwalker1a.ITM_Clothing_ChestUniqueDawnwalker1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LegsUniqueDawnwalker1a.ITM_Clothing_LegsUniqueDawnwalker1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_HandsUniqueDawnwalker1a.ITM_Clothing_HandsUniqueDawnwalker1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FeetUniqueDawnwalker1a.ITM_Clothing_FeetUniqueDawnwalker1a"), true},
    };
    const GearItem kArmorSetDawnwalker2[] = {
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_ChestUniqueDawnwalker2a.ITM_Clothing_ChestUniqueDawnwalker2a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LegsUniqueDawnwalker2a.ITM_Clothing_LegsUniqueDawnwalker2a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_HandsUniqueDawnwalker2a.ITM_Clothing_HandsUniqueDawnwalker2a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FeetUniqueDawnwalker2a.ITM_Clothing_FeetUniqueDawnwalker2a"), true},
    };
    const GearItem kArmorSetMercenary[] = {
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_ChestUniqueMercenary1a.ITM_Clothing_ChestUniqueMercenary1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LegsUniqueMercenary1a.ITM_Clothing_LegsUniqueMercenary1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_HandsUniqueMercenary1a.ITM_Clothing_HandsUniqueMercenary1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FeetUniqueMercenary1a.ITM_Clothing_FeetUniqueMercenary1a"), true},
    };
    const GearItem kArmorSetVampiric[] = {
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_ChestUniqueVampiric1a.ITM_Clothing_ChestUniqueVampiric1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LegsUniqueVampiric1a.ITM_Clothing_LegsUniqueVampiric1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_HandsUniqueVampiric1a.ITM_Clothing_HandsUniqueVampiric1a"), true},
        {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FeetUniqueVampiric1a.ITM_Clothing_FeetUniqueVampiric1a"), true},
    };
    const GearItem kRingNew1[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing1.ITM_Clothing_NewUniqueRing1"), false} };
    const GearItem kRingNew2[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing2.ITM_Clothing_NewUniqueRing2"), false} };
    const GearItem kRingNew3[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing3.ITM_Clothing_NewUniqueRing3"), false} };
    const GearItem kRingNew4[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing4.ITM_Clothing_NewUniqueRing4"), false} };
    const GearItem kRingNew5[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueRing5.ITM_Clothing_NewUniqueRing5"), false} };
    const GearItem kRingVampiric[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_VampiricRing.ITM_Clothing_VampiricRing"), false} };
    const GearItem kRingBakir[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_BakirRing.ITM_Clothing_BakirRing"), false} };
    const GearItem kRingDawnwalkers[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_DawnwalkersRing.ITM_Clothing_DawnwalkersRing"), false} };
    const GearItem kRingAstrologists[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_AstrologistsRing.ITM_Clothing_AstrologistsRing"), false} };
    const GearItem kRingAlchemists[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_AlchemistsRing.ITM_Clothing_AlchemistsRing"), false} };
    const GearItem kRingAncientHeros[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_AncientHerosRing.ITM_Clothing_AncientHerosRing"), false} };
    const GearItem kRingFarkas[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_FarkasRing.ITM_Clothing_FarkasRing"), false} };
    const GearItem kRingLacras[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LacrasRing.ITM_Clothing_LacrasRing"), false} };
    const GearItem kRingLeonikas[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_LeonikasRing.ITM_Clothing_LeonikasRing"), false} };
    const GearItem kRingMercenarys[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_MercenarysRing.ITM_Clothing_MercenarysRing"), false} };
    const GearItem kAmuletNew1[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet1.ITM_Clothing_NewUniqueAmulet1"), false} };
    const GearItem kAmuletNew2[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet2.ITM_Clothing_NewUniqueAmulet2"), false} };
    const GearItem kAmuletNew3[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet3.ITM_Clothing_NewUniqueAmulet3"), false} };
    const GearItem kAmuletNew4[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet4.ITM_Clothing_NewUniqueAmulet4"), false} };
    const GearItem kAmuletNew5[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_NewUniqueAmulet5.ITM_Clothing_NewUniqueAmulet5"), false} };
    const GearItem kAmuletMatriarchs[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_MatriarchsAmulet.ITM_Clothing_MatriarchsAmulet"), false} };
    const GearItem kAmuletVampiric[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_VampiricAmulet.ITM_Clothing_VampiricAmulet"), false} };
    const GearItem kAmuletDawnwalkers[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_DawnwalkersAmulet.ITM_Clothing_DawnwalkersAmulet"), false} };
    const GearItem kAmuletVichosCross[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_VichosCross.ITM_Clothing_VichosCross"), false} };
    const GearItem kAmuletAncientHeros[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_AncientHerosAmulet.ITM_Clothing_AncientHerosAmulet"), false} };
    const GearItem kAmuletAstral[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_AstralAmulet.ITM_Clothing_AstralAmulet"), false} };
    const GearItem kAmuletCursed[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_CursedAmulet.ITM_Clothing_CursedAmulet"), false} };
    const GearItem kAmuletMercenarys[] = { {STR("/Game/_Dawnwalker/Inventory/Items/ITM_Clothing_MercenarysAmulet.ITM_Clothing_MercenarysAmulet"), false} };

    // Ids here MUST match ui/src/data/GearCatalog.js exactly - the UI's dropdowns send one of these
    // ids verbatim in command.txt's `giveGearId=` line.
    const GearOption kGearOptions[] = {
        {"weapon_short_sword", kWeaponShortSword, std::size(kWeaponShortSword)},
        {"weapon_long_sword", kWeaponLongSword, std::size(kWeaponLongSword)},
        {"weapon_greatsword", kWeaponGreatsword, std::size(kWeaponGreatsword)},
        {"weapon_heavy", kWeaponHeavy, std::size(kWeaponHeavy)},
        {"weapon_ambrus", kWeaponAmbrus, std::size(kWeaponAmbrus)},
        {"weapon_ancient", kWeaponAncient, std::size(kWeaponAncient)},
        {"weapon_gargoyle", kWeaponGargoyle, std::size(kWeaponGargoyle)},
        {"weapon_vampiric", kWeaponVampiric, std::size(kWeaponVampiric)},
        {"weapon_mercenary", kWeaponMercenary, std::size(kWeaponMercenary)},
        {"weapon_unique_1", kWeaponUnique1, std::size(kWeaponUnique1)},
        {"weapon_unique_2", kWeaponUnique2, std::size(kWeaponUnique2)},
        {"weapon_unique_3", kWeaponUnique3, std::size(kWeaponUnique3)},
        {"armor_set_ancient", kArmorSetAncient, std::size(kArmorSetAncient)},
        {"armor_set_dawnwalker_1", kArmorSetDawnwalker1, std::size(kArmorSetDawnwalker1)},
        {"armor_set_dawnwalker_2", kArmorSetDawnwalker2, std::size(kArmorSetDawnwalker2)},
        {"armor_set_mercenary", kArmorSetMercenary, std::size(kArmorSetMercenary)},
        {"armor_set_vampiric", kArmorSetVampiric, std::size(kArmorSetVampiric)},
        {"ring_new_1", kRingNew1, std::size(kRingNew1)},
        {"ring_new_2", kRingNew2, std::size(kRingNew2)},
        {"ring_new_3", kRingNew3, std::size(kRingNew3)},
        {"ring_new_4", kRingNew4, std::size(kRingNew4)},
        {"ring_new_5", kRingNew5, std::size(kRingNew5)},
        {"ring_vampiric", kRingVampiric, std::size(kRingVampiric)},
        {"ring_bakir", kRingBakir, std::size(kRingBakir)},
        {"ring_dawnwalkers", kRingDawnwalkers, std::size(kRingDawnwalkers)},
        {"ring_astrologists", kRingAstrologists, std::size(kRingAstrologists)},
        {"ring_alchemists", kRingAlchemists, std::size(kRingAlchemists)},
        {"ring_ancient_heros", kRingAncientHeros, std::size(kRingAncientHeros)},
        {"ring_farkas", kRingFarkas, std::size(kRingFarkas)},
        {"ring_lacras", kRingLacras, std::size(kRingLacras)},
        {"ring_leonikas", kRingLeonikas, std::size(kRingLeonikas)},
        {"ring_mercenarys", kRingMercenarys, std::size(kRingMercenarys)},
        {"amulet_new_1", kAmuletNew1, std::size(kAmuletNew1)},
        {"amulet_new_2", kAmuletNew2, std::size(kAmuletNew2)},
        {"amulet_new_3", kAmuletNew3, std::size(kAmuletNew3)},
        {"amulet_new_4", kAmuletNew4, std::size(kAmuletNew4)},
        {"amulet_new_5", kAmuletNew5, std::size(kAmuletNew5)},
        {"amulet_matriarchs", kAmuletMatriarchs, std::size(kAmuletMatriarchs)},
        {"amulet_vampiric", kAmuletVampiric, std::size(kAmuletVampiric)},
        {"amulet_dawnwalkers", kAmuletDawnwalkers, std::size(kAmuletDawnwalkers)},
        {"amulet_vichos_cross", kAmuletVichosCross, std::size(kAmuletVichosCross)},
        {"amulet_ancient_heros", kAmuletAncientHeros, std::size(kAmuletAncientHeros)},
        {"amulet_astral", kAmuletAstral, std::size(kAmuletAstral)},
        {"amulet_cursed", kAmuletCursed, std::size(kAmuletCursed)},
        {"amulet_mercenarys", kAmuletMercenarys, std::size(kAmuletMercenarys)},
    };

    const GearOption* FindGearOption(const std::string& id)
    {
        for (const auto& option : kGearOptions)
        {
            if (id == option.Id) return &option;
        }
        return nullptr;
    }

    // Some quest-tied readables come along for the ride when granting certain unique gear (e.g.
    // ITM_Weapon_SwordDawnwalker5a's quest chain) and pile up into undeletable duplicates across
    // repeated grants during testing - not a bug in the grant itself, just a byproduct of granting
    // the same quest-linked item many times. RemoveItem bypasses the in-game UI's "can't discard
    // quest items" restriction entirely, since it's a raw reflection call, not a UI action.
    struct RemovableOption
    {
        const char* Id;
        const CharType* Path;
    };

    const RemovableOption kRemovableOptions[] = {
        {"cleanup_monastery_map", STR("/Game/_Dawnwalker/Inventory/Items/ITM_Readable_Q101_MonasteryMap.ITM_Readable_Q101_MonasteryMap")},
    };

    const RemovableOption* FindRemovableOption(const std::string& id)
    {
        for (const auto& option : kRemovableOptions)
        {
            if (id == option.Id) return &option;
        }
        return nullptr;
    }

    // Gets the local player's current character level via
    // /Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:GetCurrentLevel
    // (no params, IntProperty ReturnValue at offset 0). Falls back to 1 on any failure,
    // matching the disabled Lua GiveBestGear's fallback.
    int32 GetCurrentPlayerLevel()
    {
        UObject* subsystem = UObjectGlobals::FindFirstOf(STR("CharacterDevelopmentSubsystem"));
        if (!subsystem) return 1;

        UFunction* getCurrentLevelFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodCharacterDevelopment.CharacterDevelopmentSubsystem:GetCurrentLevel"));
        if (!getCurrentLevelFn) return 1;

        FProperty* returnProp = getCurrentLevelFn->FindProperty(FName(STR("ReturnValue")));
        if (!returnProp) return 1;

        std::vector<uint8_t> buffer(static_cast<size_t>(getCurrentLevelFn->GetParmsSize()), 0);
        subsystem->ProcessEvent(getCurrentLevelFn, buffer.data());
        return *returnProp->ContainerPtrToValuePtr<int32>(buffer.data());
    }

    // Grants (and optionally equips) a single item on the player, replicating
    // Lua's GiveBestGear::grantOne but via raw ProcessEvent byte-copies so the
    // FItemHandle returned by GetItemHandle is never routed through Lua's
    // reflection-only table marshalling.
    bool GiveItem(UObject* Player, UObject* InventoryComponent, UObject* InvLibCDO,
                  UFunction* GetItemHandleFn, UFunction* TryAddItemFn, UFunction* TryAddAndEquipItemFn,
                  UScriptStruct* ItemHandleStruct, const CharType* ItemPath, bool Equip, int32 ItemLevel)
    {
        UObject* itemAsset = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, ItemPath);
        if (!itemAsset)
        {
            Output::send<LogLevel::Warning>(STR("[DawnwalkerNativeFix] item asset not found: {}\n"), ItemPath);
            return false;
        }

        // --- GetItemHandle(WorldContextObject, ItemAsset, ItemLevel) -> FItemHandle ---
        FProperty* worldCtxProp = GetItemHandleFn->FindProperty(FName(STR("InWorldContextObject")));
        FProperty* itemAssetProp = GetItemHandleFn->FindProperty(FName(STR("ItemAsset")));
        FProperty* itemLevelProp = GetItemHandleFn->FindProperty(FName(STR("ItemLevel")));
        FProperty* getHandleReturnProp = GetItemHandleFn->FindProperty(FName(STR("ReturnValue")));
        if (!worldCtxProp || !itemAssetProp || !itemLevelProp || !getHandleReturnProp)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] GetItemHandle parameters not found (game update?)\n"));
            return false;
        }

        std::vector<uint8_t> getHandleBuf(static_cast<size_t>(GetItemHandleFn->GetParmsSize()), 0);
        *worldCtxProp->ContainerPtrToValuePtr<UObject*>(getHandleBuf.data()) = Player;
        *itemAssetProp->ContainerPtrToValuePtr<UObject*>(getHandleBuf.data()) = itemAsset;
        *itemLevelProp->ContainerPtrToValuePtr<uint8_t>(getHandleBuf.data()) = static_cast<uint8_t>(ItemLevel);

        InvLibCDO->ProcessEvent(GetItemHandleFn, getHandleBuf.data());

        const int32 handleSize = ItemHandleStruct->GetStructureSize();
        void* handleSrc = getHandleReturnProp->ContainerPtrToValuePtr<void>(getHandleBuf.data());

        // --- TryAddItem(ItemHandle, Quantity, bSkipNewItemCheck) or TryAddAndEquipItem(ItemHandle, bSkipNewItemCheck) ---
        UFunction* addFn = Equip ? TryAddAndEquipItemFn : TryAddItemFn;
        FProperty* handleProp = addFn->FindProperty(FName(STR("ItemHandle")));
        if (!handleProp)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] {} ItemHandle parameter not found\n"),
                                           Equip ? STR("TryAddAndEquipItem") : STR("TryAddItem"));
            return false;
        }

        std::vector<uint8_t> addBuf(static_cast<size_t>(addFn->GetParmsSize()), 0);
        void* handleDst = handleProp->ContainerPtrToValuePtr<void>(addBuf.data());
        std::memcpy(handleDst, handleSrc, static_cast<size_t>(handleSize));

        if (!Equip)
        {
            if (FProperty* quantityProp = addFn->FindProperty(FName(STR("Quantity"))))
            {
                *quantityProp->ContainerPtrToValuePtr<int32>(addBuf.data()) = 1;
            }
        }
        // bSkipNewItemCheck=true: skips whatever "is this item new" bookkeeping the game's own loot/
        // pickup path normally registers for us - our raw ProcessEvent handle never goes through that
        // path, and leaving this false (matching Lua's intent) is the leading suspect for the game
        // crashing specifically when opening the inventory menu after a native grant (the UI likely
        // queries IsItemConsideredNew()/builds a "NEW" badge per item, hitting state that was never
        // populated for a handle created this way). Cosmetic-only tradeoff: granted items just won't
        // show a "new" badge.
        if (FProperty* skipNewItemProp = addFn->FindProperty(FName(STR("bSkipNewItemCheck"))))
        {
            *skipNewItemProp->ContainerPtrToValuePtr<bool>(addBuf.data()) = true;
        }

        InventoryComponent->ProcessEvent(addFn, addBuf.data());
        return true;
    }

    // Success: fully attempted (regardless of per-item failures). NotReady: player/inventory aren't
    // resolvable yet (still loading) - caller should retry the SAME request next tick, not give up.
    // PermanentFailure: a required class/function is missing (game update) - retrying won't help.
    enum class GiveBestGearResult { Success, NotReady, PermanentFailure };

    // Resolves the local player pawn + their InventoryComponent - shared by both the give and remove
    // flows. NotReady means the player hasn't spawned in yet (retry the same request next tick).
    // PermanentFailure means a required property/class is missing (game update) - retrying won't help.
    GiveBestGearResult ResolvePlayerAndInventory(UObject*& outPlayer, UObject*& outInventoryComponent)
    {
        UObject* controller = UObjectGlobals::FindFirstOf(STR("PlayerController"));
        if (!controller)
        {
            Output::send<LogLevel::Warning>(STR("[DawnwalkerNativeFix] no PlayerController found\n"));
            return GiveBestGearResult::NotReady;
        }

        UClass* controllerClass = controller->GetClassPrivate();
        FProperty* pawnProp = controllerClass ? controllerClass->FindProperty(FName(STR("Pawn"))) : nullptr;
        if (!pawnProp)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] PlayerController.Pawn property not found\n"));
            return GiveBestGearResult::PermanentFailure;
        }
        UObject* player = *pawnProp->ContainerPtrToValuePtr<UObject*>(controller);
        if (!player)
        {
            Output::send<LogLevel::Warning>(STR("[DawnwalkerNativeFix] player pawn not spawned yet\n"));
            return GiveBestGearResult::NotReady;
        }

        // Deliberately NOT using AActor::GetComponentsByClass here: it's a macro-generated wrapper
        // (UE_BEGIN_NATIVE_FUNCTION_BODY) that throws std::runtime_error if this game's build doesn't
        // expose the exact "/Script/Engine.Actor:K2_GetComponentsByClass"/"ComponentClass" param it
        // expects, and CppMod::fire_update() (UE4SS's own dispatcher) has no try/catch around
        // on_update() - an uncaught exception there is a very plausible cause of the access-violation
        // crash seen on first live test. FindAllOf + a raw Outer pointer match is the same
        // battle-tested technique the (working) Lua bridge used for CombatComponentBase/
        // CharacterMovementComponent, translated to a direct pointer comparison (safe in C++, unlike
        // Lua's proxy identity, which needed :GetAddress()).
        std::vector<UObject*> allInventoryComponents;
        UObjectGlobals::FindAllOf(STR("InventoryComponent"), allInventoryComponents);
        UObject* inventoryComponent = nullptr;
        for (UObject* component : allInventoryComponents)
        {
            if (component && component->GetOuterPrivate() == player)
            {
                inventoryComponent = component;
                break;
            }
        }
        if (!inventoryComponent)
        {
            Output::send<LogLevel::Warning>(STR("[DawnwalkerNativeFix] player has no InventoryComponent\n"));
            return GiveBestGearResult::NotReady;
        }

        outPlayer = player;
        outInventoryComponent = inventoryComponent;
        return GiveBestGearResult::Success;
    }

    // Holds everything needed to resume granting items across multiple engine ticks: resolved once
    // in BeginGrantSetup, then AdvanceGrant consumes state.option's items one entry per tick until done.
    struct PendingGrant
    {
        bool active = false;
        int32 requestId = -1;
        std::string gearId;
        const GearOption* option = nullptr;
        UObject* player = nullptr;
        UObject* inventoryComponent = nullptr;
        UObject* invLibCDO = nullptr;
        UFunction* getItemHandleFn = nullptr;
        UFunction* tryAddItemFn = nullptr;
        UFunction* tryAddAndEquipItemFn = nullptr;
        UScriptStruct* itemHandleStruct = nullptr;
        int32 itemLevel = 0;
        size_t nextItemIndex = 0;
        int32 granted = 0;
        int32 failed = 0;
    };

    // Resolves the player/inventory/UFunctions once for a new request. NotReady means the player
    // hasn't spawned in yet - caller should retry the SAME request next tick. PermanentFailure means
    // a required class/function is missing (game update) - retrying won't help. On Success, `state`
    // is fully populated and ready for AdvanceGrant to start consuming option's items.
    GiveBestGearResult BeginGrantSetup(PendingGrant& state, int32 requestId, const std::string& gearId, const GearOption* option)
    {
        UObject* player = nullptr;
        UObject* inventoryComponent = nullptr;
        GiveBestGearResult resolveResult = ResolvePlayerAndInventory(player, inventoryComponent);
        if (resolveResult != GiveBestGearResult::Success) return resolveResult;

        UObject* invLibCDO = UObjectGlobals::StaticFindObject<UObject*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.Default__InventoryBlueprintFunctionLibrary"));
        UFunction* getItemHandleFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.InventoryBlueprintFunctionLibrary:GetItemHandle"));
        UFunction* tryAddItemFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.InventoryComponent:TryAddItem"));
        UFunction* tryAddAndEquipItemFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.InventoryComponent:TryAddAndEquipItem"));
        UScriptStruct* itemHandleStruct = UObjectGlobals::StaticFindObject<UScriptStruct*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.ItemHandle"));

        if (!invLibCDO || !getItemHandleFn || !tryAddItemFn || !tryAddAndEquipItemFn || !itemHandleStruct)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] one or more required inventory objects not found (game update?)\n"));
            return GiveBestGearResult::PermanentFailure;
        }

        state.active = true;
        state.requestId = requestId;
        state.gearId = gearId;
        state.option = option;
        state.player = player;
        state.inventoryComponent = inventoryComponent;
        state.invLibCDO = invLibCDO;
        state.getItemHandleFn = getItemHandleFn;
        state.tryAddItemFn = tryAddItemFn;
        state.tryAddAndEquipItemFn = tryAddAndEquipItemFn;
        state.itemHandleStruct = itemHandleStruct;
        state.itemLevel = GetCurrentPlayerLevel();
        state.nextItemIndex = 0;
        state.granted = 0;
        state.failed = 0;
        return GiveBestGearResult::Success;
    }

    // Grants ONE item from state.option and advances the queue. Returns true once every item has
    // been attempted (state.granted/failed hold the final tally) - false means more ticks needed.
    bool AdvanceGrant(PendingGrant& state)
    {
        if (state.nextItemIndex >= state.option->ItemCount) return true;

        const GearItem& item = state.option->Items[state.nextItemIndex++];
        const bool ok = GiveItem(state.player, state.inventoryComponent, state.invLibCDO, state.getItemHandleFn,
                                  state.tryAddItemFn, state.tryAddAndEquipItemFn, state.itemHandleStruct,
                                  item.Path, item.Equip, state.itemLevel);
        if (ok) ++state.granted; else ++state.failed;
        return state.nextItemIndex >= state.option->ItemCount;
    }

    // Removes every copy of a single item asset from the player's inventory in one shot (unlike
    // granting, this is a single ProcessEvent-per-step call chain, not a 26-item flood risk, so no
    // multi-tick staggering is needed). outRemovedCount is 0 (not an error) if the player simply
    // doesn't have any of this item.
    GiveBestGearResult TryRemoveAllOfAssetPath(const CharType* path, int32& outRemovedCount)
    {
        outRemovedCount = 0;

        UObject* player = nullptr;
        UObject* inventoryComponent = nullptr;
        GiveBestGearResult resolveResult = ResolvePlayerAndInventory(player, inventoryComponent);
        if (resolveResult != GiveBestGearResult::Success) return resolveResult;

        UObject* itemAsset = UObjectGlobals::StaticFindObject<UObject*>(nullptr, nullptr, path);
        UFunction* getHandleFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.InventoryComponent:GetHandleForAssetInInventory"));
        UFunction* getQuantityFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.InventoryComponent:GetItemQuantity"));
        UFunction* removeItemFn = UObjectGlobals::StaticFindObject<UFunction*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.InventoryComponent:RemoveItem"));
        UScriptStruct* itemHandleStruct = UObjectGlobals::StaticFindObject<UScriptStruct*>(
            nullptr, nullptr, STR("/Script/DogwoodInventory.ItemHandle"));

        if (!itemAsset || !getHandleFn || !getQuantityFn || !removeItemFn || !itemHandleStruct)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] one or more required removal objects not found (game update?)\n"));
            return GiveBestGearResult::PermanentFailure;
        }

        // --- GetHandleForAssetInInventory(ItemAsset) -> FItemHandle ---
        FProperty* assetProp = getHandleFn->FindProperty(FName(STR("ItemAsset")));
        FProperty* handleReturnProp = getHandleFn->FindProperty(FName(STR("ReturnValue")));
        if (!assetProp || !handleReturnProp)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] GetHandleForAssetInInventory parameters not found\n"));
            return GiveBestGearResult::PermanentFailure;
        }
        std::vector<uint8_t> getHandleBuf(static_cast<size_t>(getHandleFn->GetParmsSize()), 0);
        *assetProp->ContainerPtrToValuePtr<UObject*>(getHandleBuf.data()) = itemAsset;
        inventoryComponent->ProcessEvent(getHandleFn, getHandleBuf.data());
        const int32 handleSize = itemHandleStruct->GetStructureSize();
        void* handleSrc = handleReturnProp->ContainerPtrToValuePtr<void>(getHandleBuf.data());

        // --- GetItemQuantity(Item, bMatchAssetOnly=true) -> int32 ---
        FProperty* qtyItemProp = getQuantityFn->FindProperty(FName(STR("Item")));
        FProperty* qtyMatchProp = getQuantityFn->FindProperty(FName(STR("bMatchAssetOnly")));
        FProperty* qtyReturnProp = getQuantityFn->FindProperty(FName(STR("ReturnValue")));
        if (!qtyItemProp || !qtyMatchProp || !qtyReturnProp)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] GetItemQuantity parameters not found\n"));
            return GiveBestGearResult::PermanentFailure;
        }
        std::vector<uint8_t> qtyBuf(static_cast<size_t>(getQuantityFn->GetParmsSize()), 0);
        std::memcpy(qtyItemProp->ContainerPtrToValuePtr<void>(qtyBuf.data()), handleSrc, static_cast<size_t>(handleSize));
        *qtyMatchProp->ContainerPtrToValuePtr<bool>(qtyBuf.data()) = true;
        inventoryComponent->ProcessEvent(getQuantityFn, qtyBuf.data());
        const int32 quantity = *qtyReturnProp->ContainerPtrToValuePtr<int32>(qtyBuf.data());

        if (quantity <= 0) return GiveBestGearResult::Success; // nothing to remove, not an error

        // --- RemoveItem(ItemHandle, Quantity) ---
        FProperty* removeHandleProp = removeItemFn->FindProperty(FName(STR("ItemHandle")));
        FProperty* removeQuantityProp = removeItemFn->FindProperty(FName(STR("Quantity")));
        if (!removeHandleProp || !removeQuantityProp)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] RemoveItem parameters not found\n"));
            return GiveBestGearResult::PermanentFailure;
        }
        std::vector<uint8_t> removeBuf(static_cast<size_t>(removeItemFn->GetParmsSize()), 0);
        std::memcpy(removeHandleProp->ContainerPtrToValuePtr<void>(removeBuf.data()), handleSrc, static_cast<size_t>(handleSize));
        *removeQuantityProp->ContainerPtrToValuePtr<int32>(removeBuf.data()) = quantity;
        inventoryComponent->ProcessEvent(removeItemFn, removeBuf.data());

        outRemovedCount = quantity;
        return GiveBestGearResult::Success;
    }

    GiveBestGearResult TryRemoveAllOfAsset(const RemovableOption* option, int32& outRemovedCount)
    {
        return TryRemoveAllOfAssetPath(option->Path, outRemovedCount);
    }

    // Sweeps every item this mod has ever been able to grant (kGearOptions, not just the one
    // cleanup-catalog readable) and removes all duplicates of each. Menu-open crashes correlate
    // with sessions that repeatedly granted the same armor sets/weapons without cleaning up in
    // between (confirmed via a real crash dump: the callstack is 100% base-game code, no mod frames
    // at all - so an inventory bloated with dozens of duplicate items is the leading suspect, not
    // anything this mod's hooks actively do). One pass per item type in a single tick, same as the
    // single-asset removal above - already proven safe for large quantities (294 in one click).
    GiveBestGearResult TryRemoveAllGrantedGear(int32& outRemovedCount)
    {
        outRemovedCount = 0;
        for (const auto& option : kGearOptions)
        {
            for (size_t i = 0; i < option.ItemCount; ++i)
            {
                int32 removedForThisPath = 0;
                const GiveBestGearResult result = TryRemoveAllOfAssetPath(option.Items[i].Path, removedForThisPath);
                if (result == GiveBestGearResult::NotReady) return GiveBestGearResult::NotReady;
                if (result == GiveBestGearResult::Success) outRemovedCount += removedForThisPath;
                // PermanentFailure for one item path shouldn't abandon the whole sweep - keep going.
            }
        }
        return GiveBestGearResult::Success;
    }

    void WriteStatus(const std::string& gearId, const std::string& result)
    {
        std::ofstream out(kStatusPath, std::ios::trunc);
        if (!out) return;
        out << "giveGearId=" << gearId << "\n";
        out << "giveGearResult=" << result << "\n";
    }

    void WriteRemoveStatus(const std::string& gearId, const std::string& result)
    {
        std::ofstream out(kStatusPath, std::ios::trunc);
        if (!out) return;
        out << "removeGearId=" << gearId << "\n";
        out << "removeGearResult=" << result << "\n";
    }

    enum class GearCommandType { None, Give, Remove };

    // command.txt is never cleared/acknowledged by the app side (it just always contains the last
    // request), so this must return the request's own id, not just a boolean - otherwise on_update
    // (which runs every frame) would re-run the full grant loop dozens of times per second forever,
    // exactly what flooded the inventory and crashed the game on the previous live test. Only one of
    // giveGearId/removeGearId is ever present at a time - each write fully overwrites command.txt.
    GearCommandType ReadGearCommand(int32& outRequestId, std::string& outGearId)
    {
        std::ifstream in(kCommandPath);
        if (!in) return GearCommandType::None;
        outRequestId = -1;
        outGearId.clear();
        GearCommandType type = GearCommandType::None;
        std::string line;
        while (std::getline(in, line))
        {
            if (line.rfind("giveGearId=", 0) == 0) { outGearId = line.substr(11); type = GearCommandType::Give; }
            else if (line.rfind("removeGearId=", 0) == 0) { outGearId = line.substr(13); type = GearCommandType::Remove; }
            else if (line.rfind("requestId=", 0) == 0)
            {
                try { outRequestId = std::stoi(line.substr(10)); } catch (...) { outRequestId = -1; }
            }
        }
        return type;
    }

    // The stat-based (GAS attribute write) Damage Multiplier in main.lua writes successfully and
    // holds steady but has never been confirmed to affect real combat damage - see repo memory's
    // extensive "DAMAGE MULTIPLIER" saga. Since we already have native ProcessEvent/hooking
    // infrastructure here (the whole reason this mod exists is to get around Lua limitations),
    // hook the actual per-hit damage QUERY function directly and multiply its real return value,
    // instead of hoping an upstream attribute feeds into whatever black-box formula computes it.
    constexpr auto kBridgeCommandPath = "Mods/DawnwalkerModBridge/command.txt";
    std::atomic<float> g_damageMultiplier{1.0f};
    std::atomic<int> g_damageHookLogCount{0};

    // TEMPORARY DIAGNOSTIC (2026-09-04): a SECOND, differently-shaped crash (writing 0x18, no
    // recursion - see repo memory) happened in a session with a clean, non-duplicated inventory,
    // ruling out the inventory-bloat theory behind the first crash (reading 0x11c, recursive). To
    // isolate whether THIS hook's only write (SetReturnValue below) is a factor - this project has
    // an established precedent (GetParmsSize/GetStructureSize) for a bad write silently corrupting
    // memory that only crashes much later, in an unrelated call path - flip this to false to make
    // the hook fully read-only (still logs, never rewrites the return value) and retest the same
    // long menu-browsing scenario. Flip back to true once that theory is confirmed or ruled out.
    constexpr bool kGetWeaponDamageWriteEnabled = false;

    // Reads the SAME damageMultiplier value the Lua bridge/CombatPage slider already writes, so no
    // new UI/IPC wiring is needed - both the (kept, still-inert) GAS attribute write and this native
    // hook read the one slider value. Cheap file read done once per tick in on_update(), never
    // inside the hook callback itself (which can fire mid-combat on a performance-sensitive path).
    void RefreshDamageMultiplierFromBridge()
    {
        std::ifstream in(kBridgeCommandPath);
        if (!in) return;
        std::string line;
        while (std::getline(in, line))
        {
            if (line.rfind("damageMultiplier=", 0) == 0)
            {
                try
                {
                    const float value = std::stof(line.substr(17));
                    if (value >= 0.1f && value <= 10.0f) g_damageMultiplier.store(value);
                }
                catch (...) { /* leave the last-known-good value in place */ }
                return;
            }
        }
    }

    // Post-hook on ItemWeaponDataAsset:GetWeaponDamage(ThisItemHandle, RangeEdge,
    // AbilitySystemComponent) -> float. Logs the first several real (pre-multiply) return values
    // unconditionally - proof either way whether this function is actually invoked during real
    // combat (BP_ApplyAttackDamage, hooked the same way during the Lua saga, was confirmed dead
    // code and never fired for anyone) - before assuming the multiply below has any effect.
    // CONFIRMED (2026-09-04 live test): fires only ~8 times per session, always in min/max pairs,
    // clustered together - a UI/tooltip stat query (fires when opening the inventory/equipment
    // menu), NOT a per-hit call. Real damage output was unaffected.
    void OnGetWeaponDamagePost(UnrealScriptFunctionCallableContext& context, void* /*customData*/)
    {
        // Never let an exception escape a hook callback - this runs on whatever thread/call stack
        // the game's own combat code is mid-execution on, an even less forgiving context than
        // CppMod::fire_update()'s unguarded dispatcher (see repo memory).
        try
        {
            const float multiplier = g_damageMultiplier.load();
            const float original = *static_cast<float*>(context.RESULT_DECL);
            if (g_damageHookLogCount.load() < 20)
            {
                g_damageHookLogCount.fetch_add(1);
                Output::send<LogLevel::Verbose>(STR("[DawnwalkerNativeFix] GetWeaponDamage hook: original={} multiplier={} result={}\n"),
                                                 original, multiplier, original * multiplier);
            }
            if (multiplier != 1.0f && kGetWeaponDamageWriteEnabled)
            {
                // A crash was reported opening the in-game menu right after this hook had been
                // multiplying by 10x for a while - the UI that renders this stat likely can't
                // handle an arbitrarily large float (formatting overflow / display-width assert).
                // Hard-cap the OUTPUT, mirroring the same defensive ceiling already used for the
                // Lua GAS-attribute writes (200/20000) - the multiplier itself was never the real
                // problem there either.
                constexpr float kMaxDisplayedWeaponDamage = 999999.0f;
                const float result = std::min(original * multiplier, kMaxDisplayedWeaponDamage);
                context.SetReturnValue<float>(result);
            }
        }
        catch (...)
        {
            // Swallow - a broken multiply must never crash the game's own damage calculation.
        }
    }
}

class DawnwalkerNativeFix : public CppUserModBase
{
public:
    DawnwalkerNativeFix()
    {
        ModName = STR("DawnwalkerNativeFix");
        ModVersion = STR("1.0");
        ModDescription = STR("Native fix for GiveBestGear's wrong-item bug (raw ProcessEvent byte-copy).");
        ModAuthors = STR("dawnwalker-mod-app");
    }

    ~DawnwalkerNativeFix() override = default;

    auto on_unreal_init() -> void override
    {
        Output::send<LogLevel::Verbose>(STR("[DawnwalkerNativeFix] on_unreal_init\n"));

        // Registered once here (functions are guaranteed loaded by on_unreal_init) rather than in
        // on_update() - RegisterHook installs a detour on the UFunction itself, shared across every
        // instance/call, so it only ever needs to happen once for the mod's whole lifetime.
        try
        {
            UObjectGlobals::RegisterHook(
                STR("/Script/DogwoodInventory.ItemWeaponDataAsset:GetWeaponDamage"),
                {}, // no pre-hook needed, we only need to see/modify the return value
                [](UnrealScriptFunctionCallableContext& context, void* customData) { OnGetWeaponDamagePost(context, customData); },
                nullptr);
            Output::send<LogLevel::Verbose>(STR("[DawnwalkerNativeFix] Hooked GetWeaponDamage\n"));
        }
        catch (const std::exception& ex)
        {
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] Failed to hook GetWeaponDamage: {}\n"), ensure_str(ex.what()));
        }

        // NOTE: hooking a pure Blueprint (Kismet) function like
        // FocusAbilityFunctionLibrary_C:DealDamageAscBased was tried here and DOESN'T work on this
        // engine version - confirmed via UE4SS.log ("ProcessInternal: 0x0", i.e. not ready/used).
        // RegisterHook's Blueprint fallback path only matches when Function->GetFunc() equals the
        // OLD pre-4.22 ProcessInternalInternal address; this UE5 game dispatches Kismet calls via
        // ProcessLocalScriptFunctionInternal instead, which RegisterHook's version of the check
        // never compares against - so ANY plain Blueprint function throws "Was unable to register a
        // UFunction hook" here, caught cleanly with no side effects (this is not a crash source).
        // Real per-hit damage scaling would need AOB/detour-level hooking of
        // ProcessLocalScriptFunction itself (see RE-UE4SS's own KismetDebuggerMod for the pattern) -
        // not attempted, too deep/risky for now.
    }

    auto on_update() -> void override
    {
        RefreshDamageMultiplierFromBridge();

        // Known even if an exception is thrown below, so the catch blocks can still mark the right
        // request as handled instead of leaving it to spin forever.
        int32 requestId = m_pending.active ? m_pending.requestId : -1;

        // CppMod::fire_update() (UE4SS's own dispatcher) has no try/catch around on_update() - any
        // exception escaping here (e.g. from a UE4SS SDK helper that throws std::runtime_error on an
        // unexpected reflection layout) would unwind straight into the engine's own tick call with no
        // handler, which is a very plausible cause of the access-violation crash seen on first live
        // test. Never let anything escape this call.
        try
        {
            // Resume an in-flight grant regardless of what command.txt currently says - granting one
            // item per tick (not all 26 in one frame) gives the game's own quest/notification systems
            // a chance to process each pickup before the next one lands (see repo memory: granting
            // everything in a single frame triggered a burst of quest unlocks, a locked menu, then a
            // crash before it finished).
            if (m_pending.active)
            {
                if (AdvanceGrant(m_pending))
                {
                    Output::send<LogLevel::Verbose>(STR("[DawnwalkerNativeFix] GiveGear {}: granted={} failed={} itemLevel={}\n"),
                                                     ensure_str(m_pending.gearId), m_pending.granted, m_pending.failed, m_pending.itemLevel);
                    m_lastHandledRequestId = m_pending.requestId;
                    WriteStatus(m_pending.gearId, m_pending.failed == 0 ? "ok" : "failed: see UE4SS.log for details");
                    m_pending = PendingGrant{};
                }
                return;
            }

            std::string gearId;
            const GearCommandType cmdType = ReadGearCommand(requestId, gearId);
            if (cmdType == GearCommandType::None) return;
            if (requestId == m_lastHandledRequestId) return;

            if (cmdType == GearCommandType::Remove)
            {
                // Special id, not part of kRemovableOptions - sweeps every item kGearOptions can
                // grant instead of one specific asset.
                if (gearId == "cleanup_all_granted_gear")
                {
                    int32 removedCount = 0;
                    const GiveBestGearResult sweepResult = TryRemoveAllGrantedGear(removedCount);
                    if (sweepResult == GiveBestGearResult::NotReady) return; // retry this same request next tick

                    m_lastHandledRequestId = requestId;
                    Output::send<LogLevel::Verbose>(STR("[DawnwalkerNativeFix] RemoveGear {}: removed={}\n"), ensure_str(gearId), removedCount);
                    WriteRemoveStatus(gearId, sweepResult == GiveBestGearResult::Success
                                                   ? ("ok:" + std::to_string(removedCount))
                                                   : "failed: see UE4SS.log for details");
                    return;
                }

                const RemovableOption* removable = FindRemovableOption(gearId);
                if (!removable)
                {
                    Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] unknown removable gear id: {}\n"), ensure_str(gearId));
                    m_lastHandledRequestId = requestId;
                    WriteRemoveStatus(gearId, "failed: unknown gear id");
                    return;
                }

                int32 removedCount = 0;
                const GiveBestGearResult removeResult = TryRemoveAllOfAsset(removable, removedCount);
                if (removeResult == GiveBestGearResult::NotReady) return; // retry this same request next tick

                m_lastHandledRequestId = requestId;
                Output::send<LogLevel::Verbose>(STR("[DawnwalkerNativeFix] RemoveGear {}: removed={}\n"), ensure_str(gearId), removedCount);
                WriteRemoveStatus(gearId, removeResult == GiveBestGearResult::Success
                                               ? ("ok:" + std::to_string(removedCount))
                                               : "failed: see UE4SS.log for details");
                return;
            }

            const GearOption* option = FindGearOption(gearId);
            if (!option)
            {
                Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] unknown gear id: {}\n"), ensure_str(gearId));
                m_lastHandledRequestId = requestId;
                WriteStatus(gearId, "failed: unknown gear id");
                return;
            }

            const GiveBestGearResult setupResult = BeginGrantSetup(m_pending, requestId, gearId, option);
            if (setupResult == GiveBestGearResult::NotReady) return; // retry this same request next tick
            if (setupResult == GiveBestGearResult::PermanentFailure)
            {
                m_lastHandledRequestId = requestId;
                WriteStatus(gearId, "failed: see UE4SS.log for details");
            }
            // Success: state is now active, AdvanceGrant starts consuming items on the NEXT tick.
        }
        catch (const std::exception& ex)
        {
            m_lastHandledRequestId = requestId;
            const std::string gearId = m_pending.gearId;
            m_pending = PendingGrant{};
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] GiveGear threw: {}\n"), ensure_str(ex.what()));
            WriteStatus(gearId, std::string("error: ") + ex.what());
        }
        catch (...)
        {
            m_lastHandledRequestId = requestId;
            const std::string gearId = m_pending.gearId;
            m_pending = PendingGrant{};
            Output::send<LogLevel::Error>(STR("[DawnwalkerNativeFix] GiveGear threw a non-std exception\n"));
            WriteStatus(gearId, "error: unknown native exception");
        }
    }

private:
    int32 m_lastHandledRequestId = INT32_MIN;
    PendingGrant m_pending;
};

extern "C" __declspec(dllexport) RC::CppUserModBase* start_mod()
{
    return new DawnwalkerNativeFix();
}

extern "C" __declspec(dllexport) void uninstall_mod(RC::CppUserModBase* mod)
{
    delete mod;
}
