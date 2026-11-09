local _, FC = ...

FC.CampData = {
    benefitAuraSpellID = 1229741,
    sharedCooldownSeconds = 3600,
    hostKits = {
        { key = "BASIC", name = "Basic Campfire Kit", capacity = 3 },
        { key = "JOURNEYMAN", name = "Journeyman Campfire Kit", capacity = 5 },
        { key = "EXPERT", name = "Expert Campfire Kit", capacity = 10 },
    },
    professions = {
        [171] = {
            key = "ALCHEMY",
            name = "Alchemy",
            tiers = {
                { skill = 20, name = "Mana Well", benefit = "Mana regeneration while resting nearby." },
                { skill = 140, name = "Fermenter", benefit = "Reagent crafting plus the Mana Well benefit." },
                { skill = 300, name = "Alchemy Laboratory", benefit = "Alchemy Lab recipes plus the Mana Well benefit." },
            },
        },
        [164] = {
            key = "BLACKSMITHING",
            name = "Blacksmithing",
            tiers = {
                { skill = 20, name = "Sharpening Wheel", benefit = "Strength-oriented camp benefit." },
                { skill = 140, name = "Anvil", benefit = "Anvil utility plus the Sharpening Wheel benefit." },
                { skill = 300, name = "Master Forge", benefit = "Forge-required recipes plus the Sharpening Wheel benefit." },
            },
        },
        [333] = {
            key = "ENCHANTING",
            name = "Enchanting",
            tiers = {
                { skill = 20, name = "Enchanted Lute", benefit = "Armor-oriented camp benefit." },
                { skill = 140, name = "Arcane Salvager", benefit = "Disenchanting utility plus the Enchanted Lute benefit." },
                { skill = 300, name = "Arcane Forge", benefit = "Arcane Forge recipes plus the Enchanted Lute benefit." },
            },
        },
        [202] = {
            key = "ENGINEERING",
            name = "Engineering",
            tiers = {
                { skill = 20, name = "Reagent Bot", benefit = "Reagent-vendor camp utility." },
                { skill = 140, name = "Repair Bot", benefit = "Repair and reagent-vendor camp utility." },
                { skill = 300, name = "Anarchist's Workbench", benefit = "Workbench-required Engineering recipes." },
            },
        },
        [182] = {
            key = "HERBALISM",
            name = "Herbalism",
            tiers = {
                { skill = 20, name = "Incense Candle", benefit = "Intellect-oriented camp benefit." },
                { skill = 140, name = "Greenhouse", benefit = "Herbalism utility plus the Incense Candle benefit." },
                { skill = 300, name = "Seed Hybridizer", benefit = "Seed utility plus the Incense Candle benefit." },
            },
        },
        [165] = {
            key = "LEATHERWORKING",
            name = "Leatherworking",
            tiers = {
                { skill = 20, name = "Camp Tent", benefit = "Raises rested XP up to 5% of a level when applicable." },
                { skill = 140, name = "Tanning Rack", benefit = "Leatherworking workspace utility plus the Camp Tent benefit." },
                { skill = 300, name = "Sewing Machine", benefit = "Sewing Machine recipes plus the Camp Tent benefit." },
            },
        },
        [186] = {
            key = "MINING",
            name = "Mining",
            tiers = {
                { skill = 20, name = "Lodestone", benefit = "Melee attack-power-oriented camp benefit." },
                { skill = 140, name = "Rock Garden", benefit = "Mining utility plus the Lodestone benefit." },
                { skill = 300, name = "Molten Foundry", benefit = "Foundry-required recipes plus the Lodestone benefit." },
            },
        },
        [393] = {
            key = "SKINNING",
            name = "Skinning",
            tiers = {
                { skill = 20, name = "Camp Chair", benefit = "Critical-strike-oriented camp benefit." },
                { skill = 140, name = "Field Guide", benefit = "Higher-tier Skinning camp utility plus the Camp Chair benefit." },
                { skill = 300, name = "Trapper's Workbench", benefit = "Trap/workbench utility plus the Camp Chair benefit." },
            },
        },
        [197] = {
            key = "TAILORING",
            name = "Tailoring",
            tiers = {
                { skill = 20, name = "Faction Banner", benefit = "Spirit-oriented camp benefit." },
                { skill = 140, name = "Spinning Wheel", benefit = "Tailoring workspace utility plus the Faction Banner benefit." },
                { skill = 300, name = "Loom", benefit = "Loom-required recipes plus the Faction Banner benefit." },
            },
        },
        [185] = {
            key = "COOKING",
            name = "Cooking",
            hostingProfession = true,
            tiers = {},
        },
        [129] = {
            key = "FIRST_AID",
            name = "First Aid",
            tiers = {
                { skill = 20, name = "First Aid Kit", benefit = "Stamina-oriented camp benefit." },
                { skill = 140, name = "Toxin Study", benefit = "Advanced First Aid camp utility; exact beta effect remains data-dependent." },
                { skill = 300, name = "Plague Doctor's Laboratory", benefit = "High-tier First Aid camp utility; exact beta effect remains data-dependent." },
            },
        },
        [356] = {
            key = "FISHING",
            name = "Fishing",
            tiers = {
                { skill = 20, name = "Fish Bowl", benefit = "All-stat-oriented camp benefit." },
                { skill = 140, name = "Fishing Rack", benefit = "Fishing utility plus the Fish Bowl benefit." },
                { skill = 300, name = "Fishing Hut", benefit = "Higher-tier fishing utility plus the Fish Bowl benefit." },
            },
        },
    },
}
