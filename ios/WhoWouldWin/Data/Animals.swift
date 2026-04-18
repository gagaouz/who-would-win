import Foundation

struct Animals {
    // MARK: - Land (20)
    static let lion = Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4)
    static let tiger = Animal(id: "tiger", name: "Tiger", emoji: "🐯", category: .land, pixelColor: "#FF6B00", size: 4)
    static let grizzly_bear = Animal(id: "grizzly_bear", name: "Grizzly Bear", emoji: "🐻", category: .land, pixelColor: "#8B4513", size: 5)
    static let wolf = Animal(id: "wolf", name: "Wolf", emoji: "🐺", category: .land, pixelColor: "#708090", size: 3)
    static let elephant = Animal(id: "elephant", name: "Elephant", emoji: "🐘", category: .land, pixelColor: "#808080", size: 5)
    static let rhinoceros = Animal(id: "rhinoceros", name: "Rhinoceros", emoji: "🦏", category: .land, pixelColor: "#696969", size: 5)
    static let hippopotamus = Animal(id: "hippopotamus", name: "Hippopotamus", emoji: "🦛", category: .land, pixelColor: "#9B8B7B", size: 5)
    static let gorilla = Animal(id: "gorilla", name: "Gorilla", emoji: "🦍", category: .land, pixelColor: "#2F2F2F", size: 4)
    static let cheetah = Animal(id: "cheetah", name: "Cheetah", emoji: "🐆", category: .land, pixelColor: "#E8C84B", size: 3)
    static let crocodile = Animal(id: "crocodile", name: "Crocodile", emoji: "🐊", category: .land, pixelColor: "#4A7C59", size: 4)
    static let komodo_dragon = Animal(id: "komodo_dragon", name: "Komodo Dragon", emoji: "🦎", category: .land, pixelColor: "#6B8E23", size: 4)
    static let wolverine = Animal(id: "wolverine", name: "Wolverine", emoji: "🦡", category: .land, pixelColor: "#4A3728", size: 2)
    static let honey_badger = Animal(id: "honey_badger", name: "Honey Badger", emoji: "🦦", category: .land, pixelColor: "#C0B283", size: 2)
    static let giraffe = Animal(id: "giraffe", name: "Giraffe", emoji: "🦒", category: .land, pixelColor: "#D4A857", size: 5)
    static let zebra = Animal(id: "zebra", name: "Zebra", emoji: "🦓", category: .land, pixelColor: "#F5F5DC", size: 3)
    static let moose = Animal(id: "moose", name: "Moose", emoji: "🫎", category: .land, pixelColor: "#8B6914", size: 5)
    static let boar = Animal(id: "boar", name: "Boar", emoji: "🐗", category: .land, pixelColor: "#8B7355", size: 3)
    static let tarantula = Animal(id: "tarantula", name: "Tarantula", emoji: "🕷️", category: .land, pixelColor: "#3D2B1F", size: 1)
    static let scorpion = Animal(id: "scorpion", name: "Scorpion", emoji: "🦂", category: .land, pixelColor: "#C8A951", size: 1)
    static let cobra = Animal(id: "cobra", name: "Cobra", emoji: "🐍", category: .land, pixelColor: "#556B2F", size: 2)

    // MARK: - Sea (12)
    static let great_white_shark = Animal(id: "great_white_shark", name: "Great White Shark", emoji: "🦈", category: .sea, pixelColor: "#C0C0C0", size: 5)
    static let orca = Animal(id: "orca", name: "Orca", emoji: "🐋", category: .sea, pixelColor: "#1C1C1C", size: 5)
    static let giant_squid = Animal(id: "giant_squid", name: "Giant Squid", emoji: "🦑", category: .sea, pixelColor: "#8B0000", size: 4)
    static let piranha = Animal(id: "piranha", name: "Piranha", emoji: "🐟", category: .sea, pixelColor: "#FF4500", size: 1)
    static let octopus = Animal(id: "octopus", name: "Octopus", emoji: "🐙", category: .sea, pixelColor: "#FF6347", size: 3)
    static let barracuda = Animal(id: "barracuda", name: "Barracuda", emoji: "🐠", category: .sea, pixelColor: "#4682B4", size: 3)
    static let electric_eel = Animal(id: "electric_eel", name: "Electric Eel", emoji: "⚡", category: .sea, pixelColor: "#FFD700", size: 2)
    static let hammerhead_shark = Animal(id: "hammerhead_shark", name: "Hammerhead Shark", emoji: "🦈", category: .sea, pixelColor: "#708090", size: 4)
    static let mantis_shrimp = Animal(id: "mantis_shrimp", name: "Mantis Shrimp", emoji: "🦐", category: .sea, pixelColor: "#FF1493", size: 1)
    static let blue_ringed_octopus = Animal(id: "blue_ringed_octopus", name: "Blue-ringed Octopus", emoji: "🐙", category: .sea, pixelColor: "#0000FF", size: 1)
    static let swordfish = Animal(id: "swordfish", name: "Swordfish", emoji: "🐟", category: .sea, pixelColor: "#4169E1", size: 3)
    static let coelacanth = Animal(id: "coelacanth", name: "Coelacanth", emoji: "🐟", category: .sea, pixelColor: "#2E4057", size: 3)

    // MARK: - Air (9)
    static let bald_eagle = Animal(id: "bald_eagle", name: "Bald Eagle", emoji: "🦅", category: .air, pixelColor: "#8B4513", size: 3)
    static let peregrine_falcon = Animal(id: "peregrine_falcon", name: "Peregrine Falcon", emoji: "🦅", category: .air, pixelColor: "#708090", size: 2)
    static let harpy_eagle = Animal(id: "harpy_eagle", name: "Harpy Eagle", emoji: "🦅", category: .air, pixelColor: "#696969", size: 3)
    static let barn_owl = Animal(id: "barn_owl", name: "Barn Owl", emoji: "🦉", category: .air, pixelColor: "#F5DEB3", size: 2)
    static let hornet = Animal(id: "hornet", name: "Hornet", emoji: "🐝", category: .air, pixelColor: "#FFD700", size: 1)
    static let dragonfly = Animal(id: "dragonfly", name: "Dragonfly", emoji: "🪲", category: .air, pixelColor: "#00CED1", size: 1)
    static let albatross = Animal(id: "albatross", name: "Albatross", emoji: "🐦", category: .air, pixelColor: "#FFFAF0", size: 3)
    static let pelican = Animal(id: "pelican", name: "Pelican", emoji: "🐦", category: .air, pixelColor: "#FAEBD7", size: 3)
    static let crow = Animal(id: "crow", name: "Crow", emoji: "🐦‍⬛", category: .air, pixelColor: "#1C1C1C", size: 1)

    // MARK: - Insect/Small (8)
    static let army_ant = Animal(id: "army_ant", name: "Army Ant", emoji: "🐜", category: .insect, pixelColor: "#8B4513", size: 1)
    static let bombardier_beetle = Animal(id: "bombardier_beetle", name: "Bombardier Beetle", emoji: "🐞", category: .insect, pixelColor: "#228B22", size: 1)
    static let bullet_ant = Animal(id: "bullet_ant", name: "Bullet Ant", emoji: "🐜", category: .insect, pixelColor: "#2F1B0E", size: 1)
    static let praying_mantis = Animal(id: "praying_mantis", name: "Praying Mantis", emoji: "🦗", category: .insect, pixelColor: "#228B22", size: 1)
    static let fire_ant = Animal(id: "fire_ant", name: "Fire Ant", emoji: "🐜", category: .insect, pixelColor: "#FF2400", size: 1)
    static let centipede = Animal(id: "centipede", name: "Centipede", emoji: "🐛", category: .insect, pixelColor: "#8B0000", size: 1)
    static let wasp = Animal(id: "wasp", name: "Wasp", emoji: "🐝", category: .insect, pixelColor: "#FFD700", size: 1)
    static let stag_beetle = Animal(id: "stag_beetle", name: "Stag Beetle", emoji: "🪲", category: .insect, pixelColor: "#3D2B1F", size: 1)

    // MARK: - Fantasy (12)
    static let dragon     = Animal(id: "dragon",     name: "Dragon",      emoji: "🐉", category: .fantasy, pixelColor: "#C40000", size: 5)
    static let unicorn    = Animal(id: "unicorn",    name: "Unicorn",     emoji: "🦄", category: .fantasy, pixelColor: "#C77DFF", size: 4)
    static let griffin    = Animal(id: "griffin",    name: "Griffin",     emoji: "🦅", category: .fantasy, pixelColor: "#D4A017", size: 4)
    static let kraken     = Animal(id: "kraken",     name: "Kraken",      emoji: "🦑", category: .fantasy, pixelColor: "#1A1A5E", size: 5)
    static let minotaur   = Animal(id: "minotaur",   name: "Minotaur",    emoji: "🐃", category: .fantasy, pixelColor: "#5C3317", size: 5)
    static let werewolf   = Animal(id: "werewolf",   name: "Werewolf",    emoji: "🐺", category: .fantasy, pixelColor: "#4A4A6A", size: 4)
    static let hydra      = Animal(id: "hydra",      name: "Hydra",       emoji: "🐲", category: .fantasy, pixelColor: "#2D6A4F", size: 5)
    static let phoenix    = Animal(id: "phoenix",    name: "Phoenix",     emoji: "🐦‍🔥", category: .fantasy, pixelColor: "#FF4500", size: 4)
    static let kitsune    = Animal(id: "kitsune",    name: "Kitsune",     emoji: "🦊", category: .fantasy, pixelColor: "#FF8C00", size: 3)
    static let basilisk   = Animal(id: "basilisk",   name: "Basilisk",    emoji: "🐍", category: .fantasy, pixelColor: "#556B2F", size: 3)
    static let cerberus   = Animal(id: "cerberus",   name: "Cerberus",    emoji: "🐕‍🦺", category: .fantasy, pixelColor: "#2F2F2F", size: 4)
    static let leviathan  = Animal(id: "leviathan",  name: "Leviathan",   emoji: "🐋", category: .fantasy, pixelColor: "#003049", size: 5)

    // MARK: - Prehistoric Pack (13) — real extinct creatures, public domain
    static let t_rex             = Animal(id: "t_rex",             name: "T-Rex",             emoji: "🦖", category: .prehistoric, pixelColor: "#7B5E3A", size: 5)
    static let triceratops       = Animal(id: "triceratops",       name: "Triceratops",       emoji: "🦏", category: .prehistoric, pixelColor: "#6B8E5E", size: 5)
    static let velociraptor      = Animal(id: "velociraptor",      name: "Velociraptor",      emoji: "🦎", category: .prehistoric, pixelColor: "#8A9A5B", size: 3)
    static let spinosaurus       = Animal(id: "spinosaurus",       name: "Spinosaurus",       emoji: "🐊", category: .prehistoric, pixelColor: "#4A7C59", size: 5)
    static let megalodon         = Animal(id: "megalodon",         name: "Megalodon",         emoji: "🦈", category: .prehistoric, pixelColor: "#5A7A8A", size: 5)
    static let woolly_mammoth    = Animal(id: "woolly_mammoth",    name: "Woolly Mammoth",    emoji: "🦣", category: .prehistoric, pixelColor: "#8B6914", size: 5)
    static let saber_tooth_tiger = Animal(id: "saber_tooth_tiger", name: "Saber-Tooth Tiger", emoji: "🐯", category: .prehistoric, pixelColor: "#D4A017", size: 4)
    static let ankylosaurus      = Animal(id: "ankylosaurus",      name: "Ankylosaurus",      emoji: "🐢", category: .prehistoric, pixelColor: "#556B2F", size: 4)
    static let pteranodon        = Animal(id: "pteranodon",        name: "Pteranodon",        emoji: "🦇", category: .prehistoric, pixelColor: "#8FBC8F", size: 4)
    static let pterodactyl       = Animal(id: "pterodactyl",       name: "Pterodactyl",       emoji: "🦕", category: .prehistoric, pixelColor: "#8FBC8F", size: 4)
    static let dire_wolf         = Animal(id: "dire_wolf",         name: "Dire Wolf",         emoji: "🐺", category: .prehistoric, pixelColor: "#5A5A7A", size: 3)
    static let therizinosaurus   = Animal(id: "therizinosaurus",   name: "Therizinosaurus",   emoji: "🦕", category: .prehistoric, pixelColor: "#8B7355", size: 5)
    static let dodo              = Animal(id: "dodo",              name: "Dodo",              emoji: "🦤", category: .prehistoric, pixelColor: "#C8A87A", size: 1)

    // MARK: - Mythic Beasts Pack (12) — ancient public-domain mythology & folklore
    static let thunderbird = Animal(id: "thunderbird", name: "Thunderbird", emoji: "🦅", category: .mythic, pixelColor: "#1A3A8A", size: 5)
    static let manticore   = Animal(id: "manticore",   name: "Manticore",   emoji: "🦂", category: .mythic, pixelColor: "#C8500A", size: 5)
    static let sphinx      = Animal(id: "sphinx",      name: "Sphinx",      emoji: "🦁", category: .mythic, pixelColor: "#D4A017", size: 4)
    static let chimera     = Animal(id: "chimera",     name: "Chimera",     emoji: "🐐", category: .mythic, pixelColor: "#8B3A3A", size: 4)
    static let wyvern      = Animal(id: "wyvern",      name: "Wyvern",      emoji: "🐉", category: .mythic, pixelColor: "#2D6A2D", size: 4)
    static let kirin       = Animal(id: "kirin",       name: "Kirin",       emoji: "🐲", category: .mythic, pixelColor: "#A07850", size: 4)
    static let roc         = Animal(id: "roc",         name: "Roc",         emoji: "🦢", category: .mythic, pixelColor: "#C8A000", size: 5)
    static let jackalope   = Animal(id: "jackalope",   name: "Jackalope",   emoji: "🐇", category: .mythic, pixelColor: "#C8A87A", size: 2)
    static let baku        = Animal(id: "baku",        name: "Baku",        emoji: "🐘", category: .mythic, pixelColor: "#6A4A8A", size: 4)
    static let nue         = Animal(id: "nue",         name: "Nue",         emoji: "🐒", category: .mythic, pixelColor: "#3A3A5A", size: 3)
    static let ammit       = Animal(id: "ammit",       name: "Ammit",       emoji: "🐊", category: .mythic, pixelColor: "#C8A000", size: 3)
    static let peryton     = Animal(id: "peryton",     name: "Peryton",     emoji: "🦌", category: .mythic, pixelColor: "#2D6A4F", size: 3)

    // MARK: - Mount Olympus (cheat-code only)
    static let zeus        = Animal(id: "zeus",        name: "Zeus",        emoji: "⚡️", category: .olympus, pixelColor: "#FFD700", size: 5)
    static let poseidon    = Animal(id: "poseidon",    name: "Poseidon",    emoji: "🔱", category: .olympus, pixelColor: "#1565C0", size: 5)
    static let hades       = Animal(id: "hades",       name: "Hades",       emoji: "💀", category: .olympus, pixelColor: "#4A0E8F", size: 5)
    static let ares        = Animal(id: "ares",        name: "Ares",        emoji: "🪖", category: .olympus, pixelColor: "#AA0000", size: 5)
    static let athena      = Animal(id: "athena",      name: "Athena",      emoji: "🦉", category: .olympus, pixelColor: "#7E9EB5", size: 4)
    static let apollo      = Animal(id: "apollo",      name: "Apollo",      emoji: "☀️", category: .olympus, pixelColor: "#FF9900", size: 4)
    static let artemis     = Animal(id: "artemis",     name: "Artemis",     emoji: "🏹", category: .olympus, pixelColor: "#2D8A4E", size: 4)
    static let hermes      = Animal(id: "hermes",      name: "Hermes",      emoji: "🪽", category: .olympus, pixelColor: "#B0C4DE", size: 4)
    static let hephaestus  = Animal(id: "hephaestus",  name: "Hephaestus",  emoji: "🔥", category: .olympus, pixelColor: "#CC4400", size: 5)
    static let hercules    = Animal(id: "hercules",    name: "Hercules",    emoji: "💪", category: .olympus, pixelColor: "#CD7F32", size: 5)
    static let medusa      = Animal(id: "medusa",      name: "Medusa",      emoji: "🐍", category: .olympus, pixelColor: "#006400", size: 4)
    static let kronos      = Animal(id: "kronos",      name: "Kronos",      emoji: "🌀", category: .olympus, pixelColor: "#2A0A5E", size: 5)

    // MARK: - All Animals
    static let all: [Animal] = [
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
        artemis, hermes, hephaestus, hercules, medusa, kronos
    ]
}
