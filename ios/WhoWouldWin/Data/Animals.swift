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
    static let swordfish = Animal(id: "swordfish", name: "Swordfish", emoji: "🐡", category: .sea, pixelColor: "#4169E1", size: 3)
    static let coelacanth = Animal(id: "coelacanth", name: "Coelacanth", emoji: "🐟", category: .sea, pixelColor: "#2E4057", size: 3)

    // MARK: - Air (10)
    static let bald_eagle = Animal(id: "bald_eagle", name: "Bald Eagle", emoji: "🦅", category: .air, pixelColor: "#8B4513", size: 3)
    static let peregrine_falcon = Animal(id: "peregrine_falcon", name: "Peregrine Falcon", emoji: "🦅", category: .air, pixelColor: "#708090", size: 2)
    static let harpy_eagle = Animal(id: "harpy_eagle", name: "Harpy Eagle", emoji: "🦅", category: .air, pixelColor: "#696969", size: 3)
    static let barn_owl = Animal(id: "barn_owl", name: "Barn Owl", emoji: "🦉", category: .air, pixelColor: "#F5DEB3", size: 2)
    static let pterodactyl = Animal(id: "pterodactyl", name: "Pterodactyl", emoji: "🦕", category: .air, pixelColor: "#8FBC8F", size: 4)
    static let hornet = Animal(id: "hornet", name: "Hornet", emoji: "🐝", category: .air, pixelColor: "#FFD700", size: 1)
    static let dragonfly = Animal(id: "dragonfly", name: "Dragonfly", emoji: "🪲", category: .air, pixelColor: "#00CED1", size: 1)
    static let albatross = Animal(id: "albatross", name: "Albatross", emoji: "🐦", category: .air, pixelColor: "#FFFAF0", size: 3)
    static let pelican = Animal(id: "pelican", name: "Pelican", emoji: "🐦", category: .air, pixelColor: "#FAEBD7", size: 3)
    static let crow = Animal(id: "crow", name: "Crow", emoji: "🐦‍⬛", category: .air, pixelColor: "#1C1C1C", size: 1)

    // MARK: - Insect/Small (8)
    static let army_ant = Animal(id: "army_ant", name: "Army Ant", emoji: "🐜", category: .insect, pixelColor: "#8B4513", size: 1)
    static let bombardier_beetle = Animal(id: "bombardier_beetle", name: "Bombardier Beetle", emoji: "🪲", category: .insect, pixelColor: "#228B22", size: 1)
    static let bullet_ant = Animal(id: "bullet_ant", name: "Bullet Ant", emoji: "🐜", category: .insect, pixelColor: "#2F1B0E", size: 1)
    static let praying_mantis = Animal(id: "praying_mantis", name: "Praying Mantis", emoji: "🦗", category: .insect, pixelColor: "#228B22", size: 1)
    static let fire_ant = Animal(id: "fire_ant", name: "Fire Ant", emoji: "🐜", category: .insect, pixelColor: "#FF2400", size: 1)
    static let centipede = Animal(id: "centipede", name: "Centipede", emoji: "🐛", category: .insect, pixelColor: "#8B0000", size: 1)
    static let wasp = Animal(id: "wasp", name: "Wasp", emoji: "🐝", category: .insect, pixelColor: "#FFD700", size: 1)
    static let stag_beetle = Animal(id: "stag_beetle", name: "Stag Beetle", emoji: "🪲", category: .insect, pixelColor: "#3D2B1F", size: 1)

    // MARK: - Fantasy (12)
    static let dragon     = Animal(id: "dragon",     name: "Dragon",      emoji: "🐉", category: .fantasy, pixelColor: "#C40000", size: 5)
    static let unicorn    = Animal(id: "unicorn",    name: "Unicorn",     emoji: "🦄", category: .fantasy, pixelColor: "#C77DFF", size: 4)
    static let griffin    = Animal(id: "griffin",    name: "Griffin",     emoji: "🦁", category: .fantasy, pixelColor: "#D4A017", size: 4)
    static let kraken     = Animal(id: "kraken",     name: "Kraken",      emoji: "🐙", category: .fantasy, pixelColor: "#1A1A5E", size: 5)
    static let minotaur   = Animal(id: "minotaur",   name: "Minotaur",    emoji: "🐂", category: .fantasy, pixelColor: "#5C3317", size: 5)
    static let werewolf   = Animal(id: "werewolf",   name: "Werewolf",    emoji: "🐺", category: .fantasy, pixelColor: "#4A4A6A", size: 4)
    static let hydra      = Animal(id: "hydra",      name: "Hydra",       emoji: "🐲", category: .fantasy, pixelColor: "#2D6A4F", size: 5)
    static let phoenix    = Animal(id: "phoenix",    name: "Phoenix",     emoji: "🔥", category: .fantasy, pixelColor: "#FF4500", size: 4)
    static let kitsune    = Animal(id: "kitsune",    name: "Kitsune",     emoji: "🦊", category: .fantasy, pixelColor: "#FF8C00", size: 3)
    static let basilisk   = Animal(id: "basilisk",   name: "Basilisk",    emoji: "🐍", category: .fantasy, pixelColor: "#556B2F", size: 3)
    static let cerberus   = Animal(id: "cerberus",   name: "Cerberus",    emoji: "🐕", category: .fantasy, pixelColor: "#2F2F2F", size: 4)
    static let leviathan  = Animal(id: "leviathan",  name: "Leviathan",   emoji: "🐋", category: .fantasy, pixelColor: "#003049", size: 5)

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
        bald_eagle, peregrine_falcon, harpy_eagle, barn_owl, pterodactyl,
        hornet, dragonfly, albatross, pelican, crow,
        // Insect/Small
        army_ant, bombardier_beetle, bullet_ant, praying_mantis, fire_ant,
        centipede, wasp, stag_beetle,
        // Fantasy
        dragon, unicorn, griffin, kraken, minotaur, werewolf,
        hydra, phoenix, kitsune, basilisk, cerberus, leviathan
    ]
}
