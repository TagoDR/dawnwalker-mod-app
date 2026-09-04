// Ids MUST match native-mods/DawnwalkerNativeFix/dllmain.cpp's kGearOptions exactly - the native
// mod looks up the granted item(s) by this id when it reads command.txt's `giveGearId=` line.
export const GEAR_CATALOG = [
  {
    category: "Weapon",
    options: [
      { value: "weapon_short_sword", label: "Short Sword - Blacksmith's Masterpiece" },
      { value: "weapon_long_sword", label: "Long Sword - Erkas" },
      { value: "weapon_greatsword", label: "Greatsword - Dawnwalker's Blade (auto-equips)" },
      { value: "weapon_heavy", label: "Heavy Weapon - Master's Mace" },
      { value: "weapon_ambrus", label: "Sword - Ambrus" },
      { value: "weapon_ancient", label: "Sword - Ancient" },
      { value: "weapon_gargoyle", label: "Sword - Gargoyle" },
      { value: "weapon_vampiric", label: "Sword - Vampiric" },
      { value: "weapon_mercenary", label: "Sword - Mercenary" },
      { value: "weapon_unique_1", label: "Sword - Unique 1" },
      { value: "weapon_unique_2", label: "Sword - Unique 2" },
      { value: "weapon_unique_3", label: "Sword - Unique 3" },
    ],
  },
  {
    category: "Armor Set",
    options: [
      { value: "armor_set_ancient", label: "Ancient Set - Chest / Legs / Hands / Feet (auto-equips)" },
      { value: "armor_set_dawnwalker_1", label: "Dawnwalker Set I - Chest / Legs / Hands / Feet (auto-equips)" },
      { value: "armor_set_dawnwalker_2", label: "Dawnwalker Set II - Chest / Legs / Hands / Feet (auto-equips)" },
      { value: "armor_set_mercenary", label: "Mercenary Set - Chest / Legs / Hands / Feet (auto-equips)" },
      { value: "armor_set_vampiric", label: "Vampiric Set - Chest / Legs / Hands / Feet (auto-equips)" },
    ],
  },
  {
    category: "Ring",
    options: [
      { value: "ring_new_1", label: "New Unique Ring 1" },
      { value: "ring_new_2", label: "New Unique Ring 2" },
      { value: "ring_new_3", label: "New Unique Ring 3" },
      { value: "ring_new_4", label: "New Unique Ring 4" },
      { value: "ring_new_5", label: "New Unique Ring 5" },
      { value: "ring_vampiric", label: "Vampiric Ring" },
      { value: "ring_bakir", label: "Bakir Ring" },
      { value: "ring_dawnwalkers", label: "Dawnwalker's Ring" },
      { value: "ring_astrologists", label: "Astrologist's Ring" },
      { value: "ring_alchemists", label: "Alchemist's Ring" },
      { value: "ring_ancient_heros", label: "Ancient Hero's Ring" },
      { value: "ring_farkas", label: "Farkas's Ring" },
      { value: "ring_lacras", label: "Lacra's Ring" },
      { value: "ring_leonikas", label: "Leonika's Ring" },
      { value: "ring_mercenarys", label: "Mercenary's Ring" },
    ],
  },
  {
    category: "Amulet",
    options: [
      { value: "amulet_new_1", label: "New Unique Amulet 1" },
      { value: "amulet_new_2", label: "New Unique Amulet 2" },
      { value: "amulet_new_3", label: "New Unique Amulet 3" },
      { value: "amulet_new_4", label: "New Unique Amulet 4" },
      { value: "amulet_new_5", label: "New Unique Amulet 5" },
      { value: "amulet_matriarchs", label: "Matriarch's Amulet" },
      { value: "amulet_vampiric", label: "Vampiric Amulet" },
      { value: "amulet_dawnwalkers", label: "Dawnwalker's Amulet" },
      { value: "amulet_vichos_cross", label: "Vicho's Cross" },
      { value: "amulet_ancient_heros", label: "Ancient Hero's Amulet" },
      { value: "amulet_astral", label: "Astral Amulet" },
      { value: "amulet_cursed", label: "Cursed Amulet" },
      { value: "amulet_mercenarys", label: "Mercenary's Amulet" },
    ],
  },
];

// Some unique gear's quest chain grants an associated readable/quest item alongside it (e.g.
// granting the Dawnwalker gear repeatedly piles up undeletable "Monastery Map" duplicates - not a
// bug in granting itself, just a byproduct of granting the same quest-linked item many times).
// These bypass the in-game UI's "can't discard quest items" restriction via a direct RemoveItem
// reflection call. Ids MUST match native-mods/DawnwalkerNativeFix/dllmain.cpp's kRemovableOptions.
export const CLEANUP_CATALOG = [
  {
    category: "Cleanup",
    options: [
      { value: "cleanup_monastery_map", label: "Monastery Map (quest item duplicates)" },
      { value: "cleanup_all_granted_gear", label: "All Granted Gear (every weapon/armor/ring/amulet duplicate)" },
    ],
  },
];
