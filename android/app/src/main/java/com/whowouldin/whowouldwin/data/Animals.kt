package com.whowouldin.whowouldwin.data

import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalCategory

/**
 * Port of iOS Animals.swift — the full roster of built-in creatures.
 * Ids, names, emojis, categories, pixel colors and sizes must match iOS exactly
 * for cross-platform parity (stats generation is deterministic from id).
 */
object Animals {
    // region Land (20)
    val lion            = Animal("lion",            "Lion",            "\uD83E\uDD81", AnimalCategory.LAND, "#D4A017", 4)
    val tiger           = Animal("tiger",           "Tiger",           "\uD83D\uDC2F", AnimalCategory.LAND, "#FF6B00", 4)
    val grizzly_bear    = Animal("grizzly_bear",    "Grizzly Bear",    "\uD83D\uDC3B", AnimalCategory.LAND, "#8B4513", 5)
    val wolf            = Animal("wolf",            "Wolf",            "\uD83D\uDC3A", AnimalCategory.LAND, "#708090", 3)
    val elephant        = Animal("elephant",        "Elephant",        "\uD83D\uDC18", AnimalCategory.LAND, "#808080", 5)
    val rhinoceros      = Animal("rhinoceros",      "Rhinoceros",      "\uD83E\uDD8F", AnimalCategory.LAND, "#696969", 5)
    val hippopotamus    = Animal("hippopotamus",    "Hippopotamus",    "\uD83E\uDD9B", AnimalCategory.LAND, "#9B8B7B", 5)
    val gorilla         = Animal("gorilla",         "Gorilla",         "\uD83E\uDD8D", AnimalCategory.LAND, "#2F2F2F", 4)
    val cheetah         = Animal("cheetah",         "Cheetah",         "\uD83D\uDC06", AnimalCategory.LAND, "#E8C84B", 3)
    val crocodile       = Animal("crocodile",       "Crocodile",       "\uD83D\uDC0A", AnimalCategory.LAND, "#4A7C59", 4)
    val komodo_dragon   = Animal("komodo_dragon",   "Komodo Dragon",   "\uD83E\uDD8E", AnimalCategory.LAND, "#6B8E23", 4)
    val wolverine       = Animal("wolverine",       "Wolverine",       "\uD83E\uDDA1", AnimalCategory.LAND, "#4A3728", 2)
    val honey_badger    = Animal("honey_badger",    "Honey Badger",    "\uD83E\uDDA6", AnimalCategory.LAND, "#C0B283", 2)
    val giraffe         = Animal("giraffe",         "Giraffe",         "\uD83E\uDD92", AnimalCategory.LAND, "#D4A857", 5)
    val zebra           = Animal("zebra",           "Zebra",           "\uD83E\uDD93", AnimalCategory.LAND, "#F5F5DC", 3)
    val moose           = Animal("moose",           "Moose",           "\uD83E\uDECE", AnimalCategory.LAND, "#8B6914", 5)
    val boar            = Animal("boar",            "Boar",            "\uD83D\uDC17", AnimalCategory.LAND, "#8B7355", 3)
    val tarantula       = Animal("tarantula",       "Tarantula",       "\uD83D\uDD77\uFE0F", AnimalCategory.LAND, "#3D2B1F", 1)
    val scorpion        = Animal("scorpion",        "Scorpion",        "\uD83E\uDD82", AnimalCategory.LAND, "#C8A951", 1)
    val cobra           = Animal("cobra",           "Cobra",           "\uD83D\uDC0D", AnimalCategory.LAND, "#556B2F", 2)
    // endregion

    // region Sea (12)
    val great_white_shark   = Animal("great_white_shark",   "Great White Shark",   "\uD83E\uDD88", AnimalCategory.SEA, "#C0C0C0", 5)
    val orca                = Animal("orca",                "Orca",                "\uD83D\uDC0B", AnimalCategory.SEA, "#1C1C1C", 5)
    val giant_squid         = Animal("giant_squid",         "Giant Squid",         "\uD83E\uDD91", AnimalCategory.SEA, "#8B0000", 4)
    val piranha             = Animal("piranha",             "Piranha",             "\uD83D\uDC1F", AnimalCategory.SEA, "#FF4500", 1)
    val octopus             = Animal("octopus",             "Octopus",             "\uD83D\uDC19", AnimalCategory.SEA, "#FF6347", 3)
    val barracuda           = Animal("barracuda",           "Barracuda",           "\uD83D\uDC20", AnimalCategory.SEA, "#4682B4", 3)
    val electric_eel        = Animal("electric_eel",        "Electric Eel",        "\u26A1",       AnimalCategory.SEA, "#FFD700", 2)
    val hammerhead_shark    = Animal("hammerhead_shark",    "Hammerhead Shark",    "\uD83E\uDD88", AnimalCategory.SEA, "#708090", 4)
    val mantis_shrimp       = Animal("mantis_shrimp",       "Mantis Shrimp",       "\uD83E\uDD90", AnimalCategory.SEA, "#FF1493", 1)
    val blue_ringed_octopus = Animal("blue_ringed_octopus", "Blue-ringed Octopus", "\uD83D\uDC19", AnimalCategory.SEA, "#0000FF", 1)
    val swordfish           = Animal("swordfish",           "Swordfish",           "\uD83D\uDC1F", AnimalCategory.SEA, "#4169E1", 3)
    val coelacanth          = Animal("coelacanth",          "Coelacanth",          "\uD83D\uDC1F", AnimalCategory.SEA, "#2E4057", 3)
    // endregion

    // region Air (9)
    val bald_eagle       = Animal("bald_eagle",       "Bald Eagle",       "\uD83E\uDD85", AnimalCategory.AIR, "#8B4513", 3)
    val peregrine_falcon = Animal("peregrine_falcon", "Peregrine Falcon", "\uD83E\uDD85", AnimalCategory.AIR, "#708090", 2)
    val harpy_eagle      = Animal("harpy_eagle",      "Harpy Eagle",      "\uD83E\uDD85", AnimalCategory.AIR, "#696969", 3)
    val barn_owl         = Animal("barn_owl",         "Barn Owl",         "\uD83E\uDD89", AnimalCategory.AIR, "#F5DEB3", 2)
    val hornet           = Animal("hornet",           "Hornet",           "\uD83D\uDC1D", AnimalCategory.AIR, "#FFD700", 1)
    val dragonfly        = Animal("dragonfly",        "Dragonfly",        "\uD83E\uDEB2", AnimalCategory.AIR, "#00CED1", 1)
    val albatross        = Animal("albatross",        "Albatross",        "\uD83D\uDC26", AnimalCategory.AIR, "#FFFAF0", 3)
    val pelican          = Animal("pelican",          "Pelican",          "\uD83D\uDC26", AnimalCategory.AIR, "#FAEBD7", 3)
    val crow             = Animal("crow",             "Crow",             "\uD83D\uDC26\u200D\u2B1B", AnimalCategory.AIR, "#1C1C1C", 1)
    // endregion

    // region Insect/Small (8)
    val army_ant          = Animal("army_ant",          "Army Ant",          "\uD83D\uDC1C", AnimalCategory.INSECT, "#8B4513", 1)
    val bombardier_beetle = Animal("bombardier_beetle", "Bombardier Beetle", "\uD83D\uDC1E", AnimalCategory.INSECT, "#228B22", 1)
    val bullet_ant        = Animal("bullet_ant",        "Bullet Ant",        "\uD83D\uDC1C", AnimalCategory.INSECT, "#2F1B0E", 1)
    val praying_mantis    = Animal("praying_mantis",    "Praying Mantis",    "\uD83E\uDD97", AnimalCategory.INSECT, "#228B22", 1)
    val fire_ant          = Animal("fire_ant",          "Fire Ant",          "\uD83D\uDC1C", AnimalCategory.INSECT, "#FF2400", 1)
    val centipede         = Animal("centipede",         "Centipede",         "\uD83D\uDC1B", AnimalCategory.INSECT, "#8B0000", 1)
    val wasp              = Animal("wasp",              "Wasp",              "\uD83D\uDC1D", AnimalCategory.INSECT, "#FFD700", 1)
    val stag_beetle       = Animal("stag_beetle",       "Stag Beetle",       "\uD83E\uDEB2", AnimalCategory.INSECT, "#3D2B1F", 1)
    // endregion

    // region Fantasy (12)
    val dragon    = Animal("dragon",    "Dragon",    "\uD83D\uDC09", AnimalCategory.FANTASY, "#C40000", 5)
    val unicorn   = Animal("unicorn",   "Unicorn",   "\uD83E\uDD84", AnimalCategory.FANTASY, "#C77DFF", 4)
    val griffin   = Animal("griffin",   "Griffin",   "\uD83E\uDD85", AnimalCategory.FANTASY, "#D4A017", 4)
    val kraken    = Animal("kraken",    "Kraken",    "\uD83E\uDD91", AnimalCategory.FANTASY, "#1A1A5E", 5)
    val minotaur  = Animal("minotaur",  "Minotaur",  "\uD83D\uDC03", AnimalCategory.FANTASY, "#5C3317", 5)
    val werewolf  = Animal("werewolf",  "Werewolf",  "\uD83D\uDC3A", AnimalCategory.FANTASY, "#4A4A6A", 4)
    val hydra     = Animal("hydra",     "Hydra",     "\uD83D\uDC32", AnimalCategory.FANTASY, "#2D6A4F", 5)
    val phoenix   = Animal("phoenix",   "Phoenix",   "\uD83D\uDC26\u200D\uD83D\uDD25", AnimalCategory.FANTASY, "#FF4500", 4)
    val kitsune   = Animal("kitsune",   "Kitsune",   "\uD83E\uDD8A", AnimalCategory.FANTASY, "#FF8C00", 3)
    val basilisk  = Animal("basilisk",  "Basilisk",  "\uD83D\uDC0D", AnimalCategory.FANTASY, "#556B2F", 3)
    val cerberus  = Animal("cerberus",  "Cerberus",  "\uD83D\uDC15\u200D\uD83E\uDDBA", AnimalCategory.FANTASY, "#2F2F2F", 4)
    val leviathan = Animal("leviathan", "Leviathan", "\uD83D\uDC0B", AnimalCategory.FANTASY, "#003049", 5)
    // endregion

    // region Prehistoric Pack (13) — real extinct creatures, public domain
    val t_rex             = Animal("t_rex",             "T-Rex",             "\uD83E\uDD96", AnimalCategory.PREHISTORIC, "#7B5E3A", 5)
    val triceratops       = Animal("triceratops",       "Triceratops",       "\uD83E\uDD8F", AnimalCategory.PREHISTORIC, "#6B8E5E", 5)
    val velociraptor      = Animal("velociraptor",      "Velociraptor",      "\uD83E\uDD8E", AnimalCategory.PREHISTORIC, "#8A9A5B", 3)
    val spinosaurus       = Animal("spinosaurus",       "Spinosaurus",       "\uD83D\uDC0A", AnimalCategory.PREHISTORIC, "#4A7C59", 5)
    val megalodon         = Animal("megalodon",         "Megalodon",         "\uD83E\uDD88", AnimalCategory.PREHISTORIC, "#5A7A8A", 5)
    val woolly_mammoth    = Animal("woolly_mammoth",    "Woolly Mammoth",    "\uD83E\uDDA3", AnimalCategory.PREHISTORIC, "#8B6914", 5)
    val saber_tooth_tiger = Animal("saber_tooth_tiger", "Saber-Tooth Tiger", "\uD83D\uDC2F", AnimalCategory.PREHISTORIC, "#D4A017", 4)
    val ankylosaurus      = Animal("ankylosaurus",      "Ankylosaurus",      "\uD83D\uDC22", AnimalCategory.PREHISTORIC, "#556B2F", 4)
    val pteranodon        = Animal("pteranodon",        "Pteranodon",        "\uD83E\uDD87", AnimalCategory.PREHISTORIC, "#8FBC8F", 4)
    val pterodactyl       = Animal("pterodactyl",       "Pterodactyl",       "\uD83E\uDD95", AnimalCategory.PREHISTORIC, "#8FBC8F", 4)
    val dire_wolf         = Animal("dire_wolf",         "Dire Wolf",         "\uD83D\uDC3A", AnimalCategory.PREHISTORIC, "#5A5A7A", 3)
    val therizinosaurus   = Animal("therizinosaurus",   "Therizinosaurus",   "\uD83E\uDD95", AnimalCategory.PREHISTORIC, "#8B7355", 5)
    val dodo              = Animal("dodo",              "Dodo",              "\uD83E\uDDA4", AnimalCategory.PREHISTORIC, "#C8A87A", 1)
    // endregion

    // region Mythic Beasts Pack (12) — ancient public-domain mythology & folklore
    val thunderbird = Animal("thunderbird", "Thunderbird", "\uD83E\uDD85", AnimalCategory.MYTHIC, "#1A3A8A", 5)
    val manticore   = Animal("manticore",   "Manticore",   "\uD83E\uDD82", AnimalCategory.MYTHIC, "#C8500A", 5)
    val sphinx      = Animal("sphinx",      "Sphinx",      "\uD83E\uDD81", AnimalCategory.MYTHIC, "#D4A017", 4)
    val chimera     = Animal("chimera",     "Chimera",     "\uD83D\uDC10", AnimalCategory.MYTHIC, "#8B3A3A", 4)
    val wyvern      = Animal("wyvern",      "Wyvern",      "\uD83D\uDC09", AnimalCategory.MYTHIC, "#2D6A2D", 4)
    val kirin       = Animal("kirin",       "Kirin",       "\uD83D\uDC32", AnimalCategory.MYTHIC, "#A07850", 4)
    val roc         = Animal("roc",         "Roc",         "\uD83E\uDDA2", AnimalCategory.MYTHIC, "#C8A000", 5)
    val jackalope   = Animal("jackalope",   "Jackalope",   "\uD83D\uDC07", AnimalCategory.MYTHIC, "#C8A87A", 2)
    val baku        = Animal("baku",        "Baku",        "\uD83D\uDC18", AnimalCategory.MYTHIC, "#6A4A8A", 4)
    val nue         = Animal("nue",         "Nue",         "\uD83D\uDC12", AnimalCategory.MYTHIC, "#3A3A5A", 3)
    val ammit       = Animal("ammit",       "Ammit",       "\uD83D\uDC0A", AnimalCategory.MYTHIC, "#C8A000", 3)
    val peryton     = Animal("peryton",     "Peryton",     "\uD83E\uDD8C", AnimalCategory.MYTHIC, "#2D6A4F", 3)
    // endregion

    // region Mount Olympus (cheat-code only)
    val zeus        = Animal("zeus",        "Zeus",        "\u26A1\uFE0F", AnimalCategory.OLYMPUS, "#FFD700", 5)
    val poseidon    = Animal("poseidon",    "Poseidon",    "\uD83D\uDD31", AnimalCategory.OLYMPUS, "#1565C0", 5)
    val hades       = Animal("hades",       "Hades",       "\uD83D\uDC80", AnimalCategory.OLYMPUS, "#4A0E8F", 5)
    val ares        = Animal("ares",        "Ares",        "\uD83E\uDE96", AnimalCategory.OLYMPUS, "#AA0000", 5)
    val athena      = Animal("athena",      "Athena",      "\uD83E\uDD89", AnimalCategory.OLYMPUS, "#7E9EB5", 4)
    val apollo      = Animal("apollo",      "Apollo",      "\u2600\uFE0F", AnimalCategory.OLYMPUS, "#FF9900", 4)
    val artemis     = Animal("artemis",     "Artemis",     "\uD83C\uDFF9", AnimalCategory.OLYMPUS, "#2D8A4E", 4)
    val hermes      = Animal("hermes",      "Hermes",      "\uD83E\uDEBD", AnimalCategory.OLYMPUS, "#B0C4DE", 4)
    val hephaestus  = Animal("hephaestus",  "Hephaestus",  "\uD83D\uDD25", AnimalCategory.OLYMPUS, "#CC4400", 5)
    val hercules    = Animal("hercules",    "Hercules",    "\uD83D\uDCAA", AnimalCategory.OLYMPUS, "#CD7F32", 5)
    val medusa      = Animal("medusa",      "Medusa",      "\uD83D\uDC0D", AnimalCategory.OLYMPUS, "#006400", 4)
    val kronos      = Animal("kronos",      "Kronos",      "\uD83C\uDF00", AnimalCategory.OLYMPUS, "#2A0A5E", 5)
    // endregion

    /** All built-in creatures, in the same order as iOS. */
    val all: List<Animal> = listOf(
        // Land
        lion, tiger, grizzly_bear, wolf, elephant, rhinoceros, hippopotamus, gorilla,
        cheetah, crocodile, komodo_dragon, wolverine, honey_badger, giraffe, zebra,
        moose, boar, tarantula, scorpion, cobra,
        // Sea
        great_white_shark, orca, giant_squid, piranha, octopus, barracuda,
        electric_eel, hammerhead_shark, mantis_shrimp, blue_ringed_octopus,
        swordfish, coelacanth,
        // Air
        bald_eagle, peregrine_falcon, harpy_eagle, barn_owl,
        hornet, dragonfly, albatross, pelican, crow,
        // Insect/Small
        army_ant, bombardier_beetle, bullet_ant, praying_mantis, fire_ant,
        centipede, wasp, stag_beetle,
        // Fantasy
        dragon, unicorn, griffin, kraken, minotaur, werewolf,
        hydra, phoenix, kitsune, basilisk, cerberus, leviathan,
        // Prehistoric
        t_rex, triceratops, velociraptor, spinosaurus, megalodon, woolly_mammoth,
        saber_tooth_tiger, ankylosaurus, pteranodon, pterodactyl, dire_wolf,
        therizinosaurus, dodo,
        // Mythic
        thunderbird, manticore, sphinx, chimera, wyvern, kirin,
        roc, jackalope, baku, nue, ammit, peryton,
        // Mount Olympus (hidden — cheat code only)
        zeus, poseidon, hades, ares, athena, apollo,
        artemis, hermes, hephaestus, hercules, medusa, kronos,
    )
}
