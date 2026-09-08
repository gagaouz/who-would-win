import Foundation

/// On-device power data ported from the backend's claudeService.ts /
/// battleResolver.ts (the authoritative source). Used by OnDeviceResolver so
/// the local winner-picker matches the cloud's tier-based outcomes — without
/// it, AnimalStats' compressed 0–100 range let absurd upsets through
/// (e.g. an army ant 'beating' a lion). KEEP IN SYNC with the backend.
enum OnDeviceTiers {

    /// Animal id → power tier (1 = tiny bug, 10 = primordial god).
    static let tier: [String: Int] = [
        "albatross": 2, "alligator": 6, "ammit": 7, "ankylosaurus": 7,
        "army_ant": 1, "baku": 6, "bald_eagle": 4, "barn_owl": 2,
        "barracuda": 4, "basilisk": 8, "blue_ringed_octopus": 3, "boar": 4,
        "bombardier_beetle": 1, "bullet_ant": 1, "centipede": 1, "cerberus": 8,
        "cheetah": 4, "chimera": 8, "cobra": 3, "coelacanth": 3,
        "crocodile": 7, "crow": 2, "dire_wolf": 5, "dodo": 1,
        "dragon": 9, "dragonfly": 1, "electric_eel": 4, "elephant": 8,
        "fire_ant": 1, "giant_squid": 7, "giraffe": 5, "gorilla": 6,
        "great_white_shark": 8, "griffin": 7, "grizzly_bear": 7, "hammerhead_shark": 7,
        "harpy_eagle": 4, "hippopotamus": 7, "honey_badger": 3, "hornet": 1,
        "hydra": 9, "jackalope": 3, "kirin": 7, "kitsune": 6,
        "komodo_dragon": 5, "kraken": 9, "leviathan": 9, "lion": 6,
        "manticore": 7, "mantis_shrimp": 2, "megalodon": 9, "minotaur": 6,
        "moose": 6, "nue": 7, "octopus": 3, "orca": 9,
        "pelican": 2, "peregrine_falcon": 3, "peryton": 5, "phoenix": 8,
        "piranha": 2, "praying_mantis": 1, "pteranodon": 5, "pterodactyl": 3,
        "rhinoceros": 7, "roc": 8, "saber_tooth_tiger": 6, "scorpion": 2,
        "sphinx": 7, "spinosaurus": 8, "stag_beetle": 1, "swordfish": 5,
        "t_rex": 8, "tarantula": 2, "therizinosaurus": 6, "thunderbird": 9,
        "tiger": 6, "triceratops": 7, "unicorn": 6, "velociraptor": 5,
        "wasp": 1, "werewolf": 6, "wolf": 4, "wolverine": 4,
        "woolly_mammoth": 7, "wyvern": 7, "zebra": 4,
    ]

    /// Greek deities — beat any mortal creature.
    static let deities: Set<String> = ["apollo", "ares", "artemis", "athena", "hades", "hephaestus", "hercules", "hermes", "kronos", "medusa", "poseidon", "zeus"]

    /// Sea creatures — crippled out of water (land/sky arenas).
    static let sea: Set<String> = ["barracuda", "blue_ringed_octopus", "coelacanth", "electric_eel", "giant_squid", "great_white_shark", "hammerhead_shark", "kraken", "leviathan", "mantis_shrimp", "megalodon", "octopus", "orca", "piranha", "swordfish"]

    /// Air creatures — drown in deep ocean.
    static let air: Set<String> = ["albatross", "bald_eagle", "barn_owl", "crow", "dragonfly", "harpy_eagle", "hornet", "pelican", "peregrine_falcon", "pteranodon", "pterodactyl", "roc", "thunderbird"]

    /// Semi-aquatic — function on land AND in water.
    static let semiAquatic: Set<String> = ["hippopotamus", "alligator", "crocodile"]

    /// Fine-grained realism nudges WITHIN a tier (fractional). The integer tier
    /// table is coarse — these express well-established 1v1 edges between
    /// same-tier creatures without bumping anyone a full tier. Effective power
    /// is `2^(tier + adjust)`. Keep each |adjust| < 1.0 so a nudge never
    /// leapfrogs a real tier gap.
    ///   • Tiger beats Lion: bigger, more muscular, and a solitary fighter
    ///     (lions evolved for pack combat). Historical staged fights + expert
    ///     consensus favor the tiger.
    static let tierAdjust: [String: Double] = [
        "tiger": 0.45,   // edges its tier-6 peers (lion, gorilla) in single combat
    ]

    /// Integer tier for an id, defaulting to 4 (a mid creature) when unknown.
    static func tier(for id: String) -> Int {
        if deities.contains(id) { return 10 }
        return tier[id] ?? 4
    }

    /// Effective fractional tier = integer tier + realism nudge.
    static func effectiveTier(for id: String) -> Double {
        Double(tier(for: id)) + (tierAdjust[id] ?? 0)
    }
}
