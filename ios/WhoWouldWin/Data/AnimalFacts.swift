import Foundation

/// Durable, kid-friendly biology facts for each creature. Unlike the disposable
/// per-battle AI fun-fact, these are persistent and surfaced in the Animal Facts
/// card + the parent "Grown-Up Zone". Written for ages 6-12: simple, vivid,
/// accurate. Comparisons use things a kid knows (school bus, house cat, dad).
struct AnimalFact {
    let diet: String          // "Carnivore", "Herbivore", or "Omnivore"
    let habitat: String       // short, e.g. "African grasslands"
    let weight: String        // kid-relatable, e.g. "as heavy as a small car"
    let speed: String         // e.g. "up to 50 mph — faster than a car on the highway"
    let coolFact: String      // ONE durable wow-fact a kid would repeat (NOT about fighting)
}

enum AnimalFacts {
    /// Look up facts by Animal.id. Returns nil for ids without curated facts
    /// (custom creatures, or any not yet written) — callers show a graceful
    /// "no facts yet" state.
    static func facts(for id: String) -> AnimalFact? { table[id] }

    static let table: [String: AnimalFact] = [
        // MARK: - Air & Birds
        "albatross": AnimalFact(
            diet: "Carnivore",
            habitat: "open oceans and remote islands",
            weight: "about as heavy as a house cat",
            speed: "glides up to 50 mph without flapping",
            coolFact: "It can fly for years without ever touching land, even sleeping in the air."
        ),
        "bald_eagle": AnimalFact(
            diet: "Carnivore",
            habitat: "forests near lakes and rivers",
            weight: "about as heavy as a bowling ball",
            speed: "dives at over 100 mph",
            coolFact: "Its eyes are so sharp it can spot a fish from a mile away."
        ),
        "barn_owl": AnimalFact(
            diet: "Carnivore",
            habitat: "farms, fields, and old barns",
            weight: "about as heavy as a baseball",
            speed: "flies up to 50 mph",
            coolFact: "Its wings are so soft it flies in total silence to surprise mice."
        ),
        "canary": AnimalFact(
            diet: "Herbivore",
            habitat: "gardens and homes as a pet bird",
            weight: "lighter than two paperclips",
            speed: "flits about 20 mph",
            coolFact: "Miners once carried canaries underground to warn of dangerous gas."
        ),
        "cockatiel": AnimalFact(
            diet: "Herbivore",
            habitat: "Australian wetlands and homes as pets",
            weight: "about as heavy as a slice of bread",
            speed: "flies up to 40 mph",
            coolFact: "It can learn to whistle whole tunes and copy doorbells."
        ),
        "crow": AnimalFact(
            diet: "Omnivore",
            habitat: "cities, farms, and forests everywhere",
            weight: "about as heavy as a soda can",
            speed: "flies up to 30 mph",
            coolFact: "Crows are so smart they remember human faces and use tools."
        ),
        "harpy_eagle": AnimalFact(
            diet: "Carnivore",
            habitat: "rainforests of Central and South America",
            weight: "about as heavy as a small dog",
            speed: "flies up to 50 mph",
            coolFact: "Its talons are as big as a grizzly bear's claws."
        ),
        "parakeet": AnimalFact(
            diet: "Herbivore",
            habitat: "Australian grasslands and homes as pets",
            weight: "lighter than a AA battery",
            speed: "flies up to 20 mph",
            coolFact: "One famous parakeet learned to say over 1,700 words."
        ),
        "pelican": AnimalFact(
            diet: "Carnivore",
            habitat: "coasts, lakes, and rivers",
            weight: "about as heavy as a medium dog",
            speed: "flies up to 30 mph",
            coolFact: "Its stretchy throat pouch can hold more water than its own belly."
        ),
        "peregrine_falcon": AnimalFact(
            diet: "Carnivore",
            habitat: "cliffs and tall city buildings",
            weight: "about as heavy as a loaf of bread",
            speed: "dives over 200 mph — the fastest animal on Earth",
            coolFact: "It folds its wings and drops like a missile to snatch other birds right out of the air."
        ),
        "rooster": AnimalFact(
            diet: "Omnivore",
            habitat: "farms and backyards worldwide",
            weight: "about as heavy as a small bag of flour",
            speed: "runs about 9 mph",
            coolFact: "A rooster can feel the sunrise coming and crows before it appears."
        ),

        // MARK: - Land Predators
        "lion": AnimalFact(
            diet: "Carnivore",
            habitat: "African grasslands",
            weight: "as heavy as two grown-ups",
            speed: "up to 50 mph in short bursts",
            coolFact: "A lion's roar is so loud you can hear it from five miles away."
        ),
        "tiger": AnimalFact(
            diet: "Carnivore",
            habitat: "Asian forests and jungles",
            weight: "as heavy as three grown-ups",
            speed: "up to 40 mph",
            coolFact: "Every tiger's stripes are different, like a fingerprint."
        ),
        "cheetah": AnimalFact(
            diet: "Carnivore",
            habitat: "African grasslands",
            weight: "about as heavy as a big dog",
            speed: "up to 70 mph — faster than a car on the highway",
            coolFact: "It is the fastest runner on land and goes 0 to 60 in three seconds."
        ),
        "leopard_gecko": AnimalFact(
            diet: "Carnivore",
            habitat: "rocky deserts of Asia",
            weight: "lighter than a deck of cards",
            speed: "scampers about 5 mph",
            coolFact: "It stores fat in its tail and can drop the tail to escape danger."
        ),
        "wolf": AnimalFact(
            diet: "Carnivore",
            habitat: "forests, mountains, and tundra",
            weight: "about as heavy as a big dog",
            speed: "up to 35 mph",
            coolFact: "Wolves live in family packs and howl to talk to each other."
        ),
        "cobra": AnimalFact(
            diet: "Carnivore",
            habitat: "forests and fields of Asia and Africa",
            weight: "about as heavy as a small cat",
            speed: "slithers about 12 mph",
            coolFact: "A king cobra can stand up tall enough to look a person in the eye."
        ),
        "crocodile": AnimalFact(
            diet: "Carnivore",
            habitat: "rivers and swamps in warm places",
            weight: "as heavy as a small car",
            speed: "swims up to 20 mph",
            coolFact: "Crocodiles have barely changed since the time of the dinosaurs."
        ),
        "komodo_dragon": AnimalFact(
            diet: "Carnivore",
            habitat: "dry islands of Indonesia",
            weight: "about as heavy as a grown-up",
            speed: "runs up to 12 mph",
            coolFact: "It is the world's largest lizard and can smell food from miles away."
        ),

        // MARK: - Big Land Animals
        "grizzly_bear": AnimalFact(
            diet: "Omnivore",
            habitat: "forests and mountains of North America",
            weight: "as heavy as five grown-ups",
            speed: "up to 35 mph",
            coolFact: "Despite its size, a grizzly can run faster than any human sprinter."
        ),
        "elephant": AnimalFact(
            diet: "Herbivore",
            habitat: "African and Asian grasslands and forests",
            weight: "as heavy as a school bus",
            speed: "up to 25 mph",
            coolFact: "It is the largest land animal and 'hears' through its feet."
        ),
        "rhinoceros": AnimalFact(
            diet: "Herbivore",
            habitat: "African and Asian grasslands",
            weight: "as heavy as a small truck",
            speed: "up to 30 mph",
            coolFact: "Its horn is made of keratin, the same stuff as your fingernails."
        ),
        "hippopotamus": AnimalFact(
            diet: "Herbivore",
            habitat: "African rivers and lakes",
            weight: "as heavy as a small truck",
            speed: "up to 19 mph on land",
            coolFact: "It makes its own pink 'sunscreen' to protect its skin."
        ),
        "gorilla": AnimalFact(
            diet: "Herbivore",
            habitat: "African rainforests",
            weight: "as heavy as two grown-ups",
            speed: "moves about 20 mph",
            coolFact: "Gorillas share almost all of their DNA with humans and can learn sign language."
        ),
        "giraffe": AnimalFact(
            diet: "Herbivore",
            habitat: "African grasslands",
            weight: "as heavy as a small car",
            speed: "up to 35 mph",
            coolFact: "It is the tallest animal, and its tongue is nearly two feet long."
        ),
        "zebra": AnimalFact(
            diet: "Herbivore",
            habitat: "African grasslands",
            weight: "about as heavy as a horse",
            speed: "up to 40 mph",
            coolFact: "No two zebras have the same stripe pattern."
        ),
        "moose": AnimalFact(
            diet: "Herbivore",
            habitat: "cold northern forests",
            weight: "as heavy as a small car",
            speed: "up to 35 mph",
            coolFact: "It is the biggest deer in the world and can dive underwater for plants."
        ),
        "boar": AnimalFact(
            diet: "Omnivore",
            habitat: "forests of Europe and Asia",
            weight: "about as heavy as a grown-up",
            speed: "up to 30 mph",
            coolFact: "A wild boar's sense of smell is even better than a dog's."
        ),

        // MARK: - Small Land Critters
        "wolverine": AnimalFact(
            diet: "Carnivore",
            habitat: "cold northern forests and tundra",
            weight: "about as heavy as a medium dog",
            speed: "runs about 30 mph",
            coolFact: "This little animal is strong enough to drag prey many times its own size."
        ),
        "honey_badger": AnimalFact(
            diet: "Omnivore",
            habitat: "deserts and grasslands of Africa and Asia",
            weight: "about as heavy as a small dog",
            speed: "runs about 19 mph",
            coolFact: "Its loose, thick skin lets it shrug off bee stings and snake bites."
        ),
        "tarantula": AnimalFact(
            diet: "Carnivore",
            habitat: "warm deserts and rainforests",
            weight: "lighter than a tennis ball",
            speed: "crawls about 2 mph",
            coolFact: "It can flick tiny itchy hairs off its belly to scare away enemies."
        ),
        "scorpion": AnimalFact(
            diet: "Carnivore",
            habitat: "deserts and warm rocky places",
            weight: "lighter than a slice of bread",
            speed: "scuttles about 1 mph",
            coolFact: "Scorpions glow bright blue-green under a black light."
        ),

        // MARK: - Sea
        "great_white_shark": AnimalFact(
            diet: "Carnivore",
            habitat: "cool coastal oceans",
            weight: "as heavy as a small truck",
            speed: "swims up to 35 mph",
            coolFact: "It can smell a single drop of blood from far across the water."
        ),
        "orca": AnimalFact(
            diet: "Carnivore",
            habitat: "oceans all around the world",
            weight: "as heavy as a school bus",
            speed: "swims up to 34 mph",
            coolFact: "Also called the killer whale, it is actually the largest dolphin."
        ),
        "giant_squid": AnimalFact(
            diet: "Carnivore",
            habitat: "the deep, dark ocean",
            weight: "as heavy as a small car",
            speed: "jets along about 25 mph",
            coolFact: "Its eyes are the size of dinner plates, the biggest eyes of any animal."
        ),
        "piranha": AnimalFact(
            diet: "Omnivore",
            habitat: "rivers of South America",
            weight: "about as heavy as a hamburger",
            speed: "swims about 15 mph",
            coolFact: "Piranhas talk to each other by making barking sounds underwater."
        ),
        "octopus": AnimalFact(
            diet: "Carnivore",
            habitat: "oceans around the world",
            weight: "about as heavy as a house cat",
            speed: "jets along about 25 mph",
            coolFact: "It has three hearts, blue blood, and can squeeze through tiny gaps."
        ),
        "barracuda": AnimalFact(
            diet: "Carnivore",
            habitat: "warm tropical seas",
            weight: "about as heavy as a medium dog",
            speed: "swims up to 35 mph",
            coolFact: "It can zoom forward in fast bursts to surprise smaller fish."
        ),
        "electric_eel": AnimalFact(
            diet: "Carnivore",
            habitat: "muddy rivers of South America",
            weight: "about as heavy as a small child",
            speed: "swims about 5 mph",
            coolFact: "It can make a zap of electricity stronger than a wall socket."
        ),
        "hammerhead_shark": AnimalFact(
            diet: "Carnivore",
            habitat: "warm oceans worldwide",
            weight: "as heavy as a grown-up",
            speed: "swims up to 25 mph",
            coolFact: "Its wide hammer-shaped head lets it see in almost every direction."
        ),
        "mantis_shrimp": AnimalFact(
            diet: "Carnivore",
            habitat: "warm shallow ocean reefs",
            weight: "lighter than a candy bar",
            speed: "swims slowly, but punches superfast",
            coolFact: "Its punch is so fast it boils the water and sounds like a tiny bullet."
        ),
        "blue_ringed_octopus": AnimalFact(
            diet: "Carnivore",
            habitat: "tide pools of the Pacific Ocean",
            weight: "lighter than a golf ball",
            speed: "creeps slowly along the seafloor",
            coolFact: "It flashes glowing blue rings to warn that it is dangerous."
        ),
        "swordfish": AnimalFact(
            diet: "Carnivore",
            habitat: "warm and temperate oceans",
            weight: "as heavy as a grown-up",
            speed: "swims up to 60 mph",
            coolFact: "It uses its long pointy nose like a sword to slash through schools of fish."
        ),
        "coelacanth": AnimalFact(
            diet: "Carnivore",
            habitat: "deep ocean caves near Africa",
            weight: "about as heavy as a grown-up",
            speed: "drifts slowly along, about 2 mph",
            coolFact: "People thought it died with the dinosaurs until one was found alive in 1938."
        ),

        // MARK: - Air Insects & Flyers
        "hornet": AnimalFact(
            diet: "Omnivore",
            habitat: "forests and gardens worldwide",
            weight: "lighter than a paperclip",
            speed: "flies up to 25 mph",
            coolFact: "Hornets build huge paper nests by chewing wood into pulp."
        ),
        "dragonfly": AnimalFact(
            diet: "Carnivore",
            habitat: "ponds, lakes, and wetlands",
            weight: "lighter than a feather",
            speed: "flies up to 35 mph",
            coolFact: "It can fly backwards and hover like a tiny helicopter."
        ),

        // MARK: - Insects / Small
        "army_ant": AnimalFact(
            diet: "Carnivore",
            habitat: "tropical rainforests",
            weight: "lighter than a grain of rice",
            speed: "marches about 0.1 mph",
            coolFact: "Army ants link their bodies together to build living bridges and walls."
        ),
        "bombardier_beetle": AnimalFact(
            diet: "Carnivore",
            habitat: "forests and grasslands worldwide",
            weight: "lighter than a paperclip",
            speed: "scurries slowly along the ground",
            coolFact: "It sprays a boiling-hot chemical from its rear with a loud pop."
        ),
        "bullet_ant": AnimalFact(
            diet: "Omnivore",
            habitat: "rainforests of Central and South America",
            weight: "lighter than a grain of rice",
            speed: "crawls slowly along trees",
            coolFact: "Its sting is named after a bullet because it is the most painful insect sting."
        ),
        "praying_mantis": AnimalFact(
            diet: "Carnivore",
            habitat: "gardens and grasslands worldwide",
            weight: "lighter than a coin",
            speed: "moves slowly, then strikes superfast",
            coolFact: "It can turn its head all the way around to watch you, like an owl."
        ),
        "fire_ant": AnimalFact(
            diet: "Omnivore",
            habitat: "warm fields and lawns",
            weight: "lighter than a grain of sand",
            speed: "crawls slowly along the ground",
            coolFact: "Fire ants can link into a living raft and float on water for weeks."
        ),
        "centipede": AnimalFact(
            diet: "Carnivore",
            habitat: "damp soil, leaves, and under rocks",
            weight: "lighter than a coin",
            speed: "scurries about 1 mph",
            coolFact: "Despite its name, no centipede actually has exactly 100 legs."
        ),
        "wasp": AnimalFact(
            diet: "Omnivore",
            habitat: "gardens, forests, and fields worldwide",
            weight: "lighter than a paperclip",
            speed: "flies up to 20 mph",
            coolFact: "Wasps invented paper millions of years before people did."
        ),
        "stag_beetle": AnimalFact(
            diet: "Herbivore",
            habitat: "woodlands and rotting logs",
            weight: "lighter than a AA battery",
            speed: "lumbers slowly along, flies clumsily",
            coolFact: "The males have giant jaws shaped like a deer's antlers."
        ),

        // MARK: - Pets — Dogs
        "great_dane": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a gentle giant pet",
            weight: "about as heavy as a grown-up",
            speed: "runs up to 30 mph",
            coolFact: "Standing on its back legs, a Great Dane is taller than most people."
        ),
        "german_shepherd": AnimalFact(
            diet: "Carnivore",
            habitat: "homes and working with police",
            weight: "about as heavy as a small adult",
            speed: "runs up to 30 mph",
            coolFact: "Their amazing noses help them work as police and rescue dogs."
        ),
        "golden_retriever": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a friendly family pet",
            weight: "about as heavy as a big child",
            speed: "runs up to 30 mph",
            coolFact: "Their mouths are so gentle they can carry an egg without cracking it."
        ),
        "labrador": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a friendly family pet",
            weight: "about as heavy as a big child",
            speed: "runs up to 30 mph",
            coolFact: "Labs have webbed toes that make them wonderful swimmers."
        ),
        "husky": AnimalFact(
            diet: "Carnivore",
            habitat: "snowy lands and homes as pets",
            weight: "about as heavy as a big child",
            speed: "runs up to 30 mph",
            coolFact: "Sled-pulling huskies can run over 100 miles in a single snowy day."
        ),
        "bulldog": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a calm cuddly pet",
            weight: "about as heavy as a medium dog",
            speed: "trots about 15 mph",
            coolFact: "Bulldogs are too heavy and short to swim, so they need life jackets."
        ),
        "beagle": AnimalFact(
            diet: "Carnivore",
            habitat: "homes and on the trail of scents",
            weight: "about as heavy as a small child",
            speed: "runs up to 20 mph",
            coolFact: "A beagle's nose has about 220 million smell sensors, way more than ours."
        ),
        "poodle": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a clever curly pet",
            weight: "about as heavy as a medium dog",
            speed: "runs up to 30 mph",
            coolFact: "Poodles are one of the smartest dog breeds and were bred to fetch from water."
        ),
        "corgi": AnimalFact(
            diet: "Carnivore",
            habitat: "homes and herding farms",
            weight: "about as heavy as a small dog",
            speed: "runs up to 25 mph",
            coolFact: "Despite tiny legs, corgis were bred to herd big cattle by nipping their heels."
        ),
        "pug": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a snuggly lap pet",
            weight: "about as heavy as a bag of sugar",
            speed: "trots about 10 mph",
            coolFact: "A group of pugs is playfully called a 'grumble.'"
        ),
        "dachshund": AnimalFact(
            diet: "Carnivore",
            habitat: "homes and burrowing after critters",
            weight: "about as heavy as a small cat",
            speed: "runs up to 15 mph",
            coolFact: "Its long 'hot dog' body was made for digging into badger burrows."
        ),
        "chihuahua": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a tiny brave pet",
            weight: "lighter than a bag of apples",
            speed: "scampers about 15 mph",
            coolFact: "It is the smallest dog breed in the whole world."
        ),

        // MARK: - Pets — Cats
        "tabby_cat": AnimalFact(
            diet: "Carnivore",
            habitat: "homes and neighborhoods as a pet",
            weight: "about as heavy as a bag of sugar",
            speed: "runs up to 30 mph",
            coolFact: "The M-shaped mark on a tabby's forehead is part of its natural stripes."
        ),
        "persian_cat": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a fluffy lap pet",
            weight: "about as heavy as a bag of sugar",
            speed: "runs up to 25 mph",
            coolFact: "Its super-fluffy coat needs brushing every day to stay soft."
        ),
        "maine_coon": AnimalFact(
            diet: "Carnivore",
            habitat: "homes as a giant gentle pet",
            weight: "about as heavy as a small dog",
            speed: "runs up to 30 mph",
            coolFact: "It is one of the biggest house cats and loves to play in water."
        ),

        // MARK: - Pets — Small Mammals & Fish
        "hamster": AnimalFact(
            diet: "Omnivore",
            habitat: "cozy cages and burrows",
            weight: "lighter than a slice of bread",
            speed: "scampers about 4 mph",
            coolFact: "It stuffs food into stretchy cheek pouches as big as its whole body."
        ),
        "gerbil": AnimalFact(
            diet: "Omnivore",
            habitat: "dry deserts and homes as pets",
            weight: "lighter than a golf ball",
            speed: "scurries about 5 mph",
            coolFact: "Gerbils thump their back feet on the ground to warn friends of danger."
        ),
        "guinea_pig": AnimalFact(
            diet: "Herbivore",
            habitat: "homes as a chatty cuddly pet",
            weight: "about as heavy as a can of soup",
            speed: "scurries about 5 mph",
            coolFact: "When a guinea pig is happy it does a hopping dance called 'popcorning.'"
        ),
        "pet_rabbit": AnimalFact(
            diet: "Herbivore",
            habitat: "homes and gardens as a pet",
            weight: "about as heavy as a small cat",
            speed: "hops up to 35 mph",
            coolFact: "A happy rabbit does a twisting jump in the air called a 'binky.'"
        ),
        "goldfish": AnimalFact(
            diet: "Omnivore",
            habitat: "ponds and fish bowls",
            weight: "lighter than a coin",
            speed: "swims about 4 mph",
            coolFact: "Goldfish can remember things for months, not just a few seconds."
        ),
        "betta_fish": AnimalFact(
            diet: "Carnivore",
            habitat: "warm shallow waters of Asia",
            weight: "lighter than a paperclip",
            speed: "swims slowly with flowing fins",
            coolFact: "A betta can gulp air from the surface using a special breathing organ."
        ),

        // MARK: - Farm
        "cow": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and grassy pastures",
            weight: "as heavy as a small car",
            speed: "runs about 17 mph",
            coolFact: "A cow has four parts to its stomach to help it digest grass."
        ),
        "bull": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and grassy pastures",
            weight: "as heavy as a small car",
            speed: "runs about 25 mph",
            coolFact: "Bulls can't actually see the color red — they charge at movement."
        ),
        "ox": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and fields worldwide",
            weight: "as heavy as a small car",
            speed: "walks about 5 mph pulling loads",
            coolFact: "Oxen are so strong that people use them to pull heavy plows and carts."
        ),
        "pig": AnimalFact(
            diet: "Omnivore",
            habitat: "farms and muddy pens",
            weight: "about as heavy as two grown-ups",
            speed: "runs about 11 mph",
            coolFact: "Pigs are very smart and roll in mud to stay cool, like sunscreen."
        ),
        "piglet": AnimalFact(
            diet: "Omnivore",
            habitat: "farms beside their mother",
            weight: "about as heavy as a small dog",
            speed: "scampers about 8 mph",
            coolFact: "Baby pigs can run and play within hours of being born."
        ),
        "sheep": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and grassy hills",
            weight: "about as heavy as a grown-up",
            speed: "runs about 20 mph",
            coolFact: "Sheep can recognize and remember the faces of dozens of friends."
        ),
        "lamb": AnimalFact(
            diet: "Herbivore",
            habitat: "farms beside their mother",
            weight: "about as heavy as a small dog",
            speed: "frolics about 15 mph",
            coolFact: "Lambs can stand and wobble around within minutes of being born."
        ),
        "ram": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and rocky mountainsides",
            weight: "about as heavy as a grown-up",
            speed: "runs about 25 mph",
            coolFact: "A ram's curly horns keep growing its whole life and have growth rings."
        ),
        "goat": AnimalFact(
            diet: "Herbivore",
            habitat: "farms, hills, and rocky cliffs",
            weight: "about as heavy as a big child",
            speed: "runs about 15 mph",
            coolFact: "Goats are amazing climbers and can balance on the steepest cliffs."
        ),
        "horse": AnimalFact(
            diet: "Herbivore",
            habitat: "farms, ranches, and open plains",
            weight: "about as heavy as a small car",
            speed: "gallops up to 55 mph",
            coolFact: "Horses can sleep both lying down and standing up."
        ),
        "donkey": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and dry rocky places",
            weight: "about as heavy as a grown-up",
            speed: "runs about 15 mph",
            coolFact: "A donkey's loud bray can be heard up to two miles away."
        ),
        "mule": AnimalFact(
            diet: "Herbivore",
            habitat: "farms and mountain trails",
            weight: "about as heavy as a small horse",
            speed: "runs about 15 mph",
            coolFact: "A mule is half horse and half donkey, and is great at carrying loads up mountains."
        ),
        "llama": AnimalFact(
            diet: "Herbivore",
            habitat: "mountains of South America and farms",
            weight: "about as heavy as a grown-up",
            speed: "runs about 35 mph",
            coolFact: "Llamas hum to each other and spit when they are annoyed."
        ),
        "alpaca": AnimalFact(
            diet: "Herbivore",
            habitat: "mountains of South America and farms",
            weight: "about as heavy as a big child",
            speed: "runs about 25 mph",
            coolFact: "Alpacas have such soft, warm wool that it is woven into cozy sweaters."
        ),
        "chicken": AnimalFact(
            diet: "Omnivore",
            habitat: "farms and backyards worldwide",
            weight: "about as heavy as a bag of sugar",
            speed: "runs about 9 mph",
            coolFact: "Chickens are the closest living relatives of the mighty T-Rex."
        ),
        "duck": AnimalFact(
            diet: "Omnivore",
            habitat: "ponds, lakes, and farms",
            weight: "about as heavy as a bag of sugar",
            speed: "flies up to 60 mph",
            coolFact: "Ducks have waterproof feathers, so water rolls right off their backs."
        ),
        "goose": AnimalFact(
            diet: "Herbivore",
            habitat: "ponds, fields, and farms",
            weight: "about as heavy as a small dog",
            speed: "flies up to 40 mph",
            coolFact: "Geese fly in a V-shape so each one can ride on the air made by the bird in front."
        ),
        "turkey": AnimalFact(
            diet: "Omnivore",
            habitat: "forests and farms of North America",
            weight: "about as heavy as a big child",
            speed: "runs about 25 mph and flies in bursts",
            coolFact: "Wild turkeys can actually fly fast, even though farm turkeys can't."
        ),
        "border_collie": AnimalFact(
            diet: "Carnivore",
            habitat: "farms herding sheep, and homes",
            weight: "about as heavy as a small child",
            speed: "runs up to 30 mph",
            coolFact: "Border collies are the smartest dogs and can learn over 1,000 words."
        ),

        // MARK: - Fantasy
        "dragon": AnimalFact(
            diet: "Carnivore",
            habitat: "myths and legends around the world",
            weight: "as heavy as several elephants",
            speed: "soars faster than any bird",
            coolFact: "In legends, dragons breathe fire and guard piles of golden treasure."
        ),
        "unicorn": AnimalFact(
            diet: "Herbivore",
            habitat: "enchanted forests of legend",
            weight: "about as heavy as a horse",
            speed: "gallops faster than any horse",
            coolFact: "Legends say a unicorn's horn could turn dirty water clean and pure."
        ),
        "griffin": AnimalFact(
            diet: "Carnivore",
            habitat: "Greek and Persian mythology",
            weight: "about as heavy as a small horse",
            speed: "flies faster than an eagle",
            coolFact: "Half eagle and half lion, griffins were said to guard hidden gold."
        ),
        "kraken": AnimalFact(
            diet: "Carnivore",
            habitat: "Norse sea legends",
            weight: "as heavy as a whole ship",
            speed: "lurks deep, then strikes fast",
            coolFact: "Sailors told stories of a giant squid-like beast that could pull ships under the sea."
        ),
        "minotaur": AnimalFact(
            diet: "Carnivore",
            habitat: "Greek mythology, in a maze on Crete",
            weight: "as heavy as two grown-ups",
            speed: "charges like a bull",
            coolFact: "Half man and half bull, it lived in a twisting maze called the Labyrinth."
        ),
        "werewolf": AnimalFact(
            diet: "Carnivore",
            habitat: "folklore and moonlit forests",
            weight: "about as heavy as a grown-up",
            speed: "runs faster than a wolf",
            coolFact: "In legend, a person turns into a werewolf under the light of a full moon."
        ),
        "hydra": AnimalFact(
            diet: "Carnivore",
            habitat: "Greek mythology, in a swamp",
            weight: "as heavy as several grown-ups",
            speed: "strikes with many heads at once",
            coolFact: "In legend, if you cut off one of its heads, two new ones grew back."
        ),
        "phoenix": AnimalFact(
            diet: "Omnivore",
            habitat: "myths of Greece, Egypt, and beyond",
            weight: "about as heavy as a large eagle",
            speed: "flies wrapped in flames",
            coolFact: "Legends say it bursts into flames, then is reborn from its own ashes."
        ),
        "kitsune": AnimalFact(
            diet: "Omnivore",
            habitat: "Japanese folklore",
            weight: "about as heavy as a fox",
            speed: "darts as quick as a fox",
            coolFact: "This magical fox spirit grows an extra tail for every hundred years it lives."
        ),
        "basilisk": AnimalFact(
            diet: "Carnivore",
            habitat: "European legends",
            weight: "about as heavy as a large snake",
            speed: "slithers swiftly",
            coolFact: "Stories called it the 'king of serpents' with a deadly stare."
        ),
        "cerberus": AnimalFact(
            diet: "Carnivore",
            habitat: "Greek mythology, the underworld",
            weight: "as heavy as a small horse",
            speed: "runs fast on powerful legs",
            coolFact: "This giant three-headed dog guarded the gates of the underworld."
        ),
        "leviathan": AnimalFact(
            diet: "Carnivore",
            habitat: "ancient sea legends",
            weight: "as heavy as many whales",
            speed: "glides through the deep sea",
            coolFact: "This enormous sea monster from old stories was said to be bigger than a ship."
        ),

        // MARK: - Prehistoric
        "t_rex": AnimalFact(
            diet: "Carnivore",
            habitat: "Late Cretaceous, 68 million years ago",
            weight: "as heavy as a school bus",
            speed: "ran about 12 mph",
            coolFact: "Its bite was strong enough to crush a car — the most powerful bite of any land animal ever."
        ),
        "triceratops": AnimalFact(
            diet: "Herbivore",
            habitat: "Late Cretaceous, 68 million years ago",
            weight: "as heavy as a small truck",
            speed: "walked about 12 mph",
            coolFact: "Its huge bony frill and three horns made its head as long as a person is tall."
        ),
        "velociraptor": AnimalFact(
            diet: "Carnivore",
            habitat: "Late Cretaceous, 75 million years ago",
            weight: "about as heavy as a large turkey",
            speed: "ran up to 24 mph",
            coolFact: "Real velociraptors were turkey-sized and covered in feathers."
        ),
        "spinosaurus": AnimalFact(
            diet: "Carnivore",
            habitat: "Cretaceous rivers, 95 million years ago",
            weight: "as heavy as a school bus",
            speed: "swam and waded through rivers",
            coolFact: "With a giant sail on its back, it was the first dinosaur known to swim and hunt fish."
        ),
        "megalodon": AnimalFact(
            diet: "Carnivore",
            habitat: "ancient oceans, millions of years ago",
            weight: "as heavy as a school bus",
            speed: "swam up to 18 mph",
            coolFact: "This giant shark's teeth were as big as your hand."
        ),
        "woolly_mammoth": AnimalFact(
            diet: "Herbivore",
            habitat: "Ice Age tundra and grasslands",
            weight: "as heavy as a small truck",
            speed: "walked about 25 mph",
            coolFact: "Its curved tusks could grow as long as a small car."
        ),
        "saber_tooth_tiger": AnimalFact(
            diet: "Carnivore",
            habitat: "Ice Age Americas",
            weight: "about as heavy as a tiger",
            speed: "ran about 30 mph",
            coolFact: "Its huge fangs were as long as a banana."
        ),
        "ankylosaurus": AnimalFact(
            diet: "Herbivore",
            habitat: "Late Cretaceous, 66 million years ago",
            weight: "as heavy as a small truck",
            speed: "lumbered about 6 mph",
            coolFact: "It was covered in bony armor and had a heavy club on the end of its tail."
        ),
        "pteranodon": AnimalFact(
            diet: "Carnivore",
            habitat: "Late Cretaceous coasts, 86 million years ago",
            weight: "about as heavy as a large dog",
            speed: "soared on huge wings",
            coolFact: "Its wings were as wide as a school bus is long, but it weighed very little."
        ),
        "pterodactyl": AnimalFact(
            diet: "Carnivore",
            habitat: "Late Jurassic, 150 million years ago",
            weight: "lighter than a house cat",
            speed: "glided gracefully on leathery wings",
            coolFact: "It was a flying reptile, not a dinosaur, and ruled the prehistoric skies."
        ),
        "dire_wolf": AnimalFact(
            diet: "Carnivore",
            habitat: "Ice Age Americas",
            weight: "about as heavy as a big dog",
            speed: "ran about 30 mph",
            coolFact: "Bigger and stronger than today's wolves, it hunted in large packs."
        ),
        "therizinosaurus": AnimalFact(
            diet: "Herbivore",
            habitat: "Late Cretaceous, 70 million years ago",
            weight: "as heavy as an elephant",
            speed: "ambled slowly on two legs",
            coolFact: "It had the longest claws of any animal ever — as long as your arm."
        ),
        "dodo": AnimalFact(
            diet: "Herbivore",
            habitat: "the island of Mauritius (now extinct)",
            weight: "about as heavy as a big turkey",
            speed: "waddled slowly — it could not fly",
            coolFact: "This gentle bird couldn't fly and sadly went extinct about 350 years ago."
        ),

        // MARK: - Mythic Beasts
        "thunderbird": AnimalFact(
            diet: "Carnivore",
            habitat: "Native American legends",
            weight: "as heavy as a small plane",
            speed: "flies on storm winds",
            coolFact: "Legends say flapping its giant wings makes the rumble of thunder."
        ),
        "manticore": AnimalFact(
            diet: "Carnivore",
            habitat: "Persian mythology",
            weight: "about as heavy as a lion",
            speed: "pounces like a big cat",
            coolFact: "It has a lion's body, a human-like face, and a tail tipped with spikes."
        ),
        "sphinx": AnimalFact(
            diet: "Carnivore",
            habitat: "Greek and Egyptian mythology",
            weight: "about as heavy as a lion",
            speed: "moves with a lion's grace",
            coolFact: "In Greek myth, the sphinx asked travelers a tricky riddle to solve."
        ),
        "chimera": AnimalFact(
            diet: "Carnivore",
            habitat: "Greek mythology",
            weight: "about as heavy as a lion",
            speed: "bounds like a lion",
            coolFact: "It is a mix of three animals: a lion, a goat, and a snake."
        ),
        "wyvern": AnimalFact(
            diet: "Carnivore",
            habitat: "European heraldry and legends",
            weight: "as heavy as an elephant",
            speed: "flies on two leathery wings",
            coolFact: "A wyvern is a dragon with just two legs, often seen on old knights' shields."
        ),
        "kirin": AnimalFact(
            diet: "Herbivore",
            habitat: "Chinese and Japanese mythology",
            weight: "about as heavy as a horse",
            speed: "moves so gently it never bends a blade of grass",
            coolFact: "This gentle creature was said to appear when a wise and kind ruler was near."
        ),
        "roc": AnimalFact(
            diet: "Carnivore",
            habitat: "Middle Eastern legends",
            weight: "as heavy as a small plane",
            speed: "soars high above the clouds",
            coolFact: "This legendary bird was said to be big enough to carry an elephant in its claws."
        ),
        "jackalope": AnimalFact(
            diet: "Herbivore",
            habitat: "American folklore of the Old West",
            weight: "about as heavy as a rabbit",
            speed: "hops up to 35 mph",
            coolFact: "This made-up critter is a jackrabbit with antlers, like a deer."
        ),
        "baku": AnimalFact(
            diet: "Omnivore",
            habitat: "Japanese folklore",
            weight: "about as heavy as an elephant",
            speed: "moves slowly and calmly",
            coolFact: "In legend, this dream-eating spirit gobbles up children's bad dreams."
        ),
        "nue": AnimalFact(
            diet: "Carnivore",
            habitat: "Japanese mythology",
            weight: "about as heavy as a large tiger",
            speed: "moves like a swift cat",
            coolFact: "It is a strange mix of a monkey's face, tiger's body, and snake's tail."
        ),
        "ammit": AnimalFact(
            diet: "Carnivore",
            habitat: "ancient Egyptian mythology",
            weight: "about as heavy as a crocodile",
            speed: "moves like a crocodile",
            coolFact: "It mixes the three scariest animals to ancient Egyptians: croc, lion, and hippo."
        ),
        "peryton": AnimalFact(
            diet: "Herbivore",
            habitat: "medieval-style legends",
            weight: "about as heavy as a large deer",
            speed: "flies as swiftly as a deer runs",
            coolFact: "It is a deer with the wings of a giant bird, casting the shadow of a person."
        ),

        // MARK: - Mount Olympus (Greek deities)
        "zeus": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, atop Mount Olympus",
            weight: "as mighty as a mountain king",
            speed: "moves as fast as a lightning bolt",
            coolFact: "King of the Greek gods, he threw thunderbolts down from the sky."
        ),
        "poseidon": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, deep in the sea",
            weight: "as mighty as the ocean itself",
            speed: "rides the waves like the tide",
            coolFact: "God of the sea, he could stir up storms and earthquakes with his trident."
        ),
        "hades": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, the underworld",
            weight: "as mighty as a god",
            speed: "moves like a passing shadow",
            coolFact: "God of the underworld, he wore a magic helmet that made him invisible."
        ),
        "ares": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, Mount Olympus",
            weight: "as mighty as a warrior god",
            speed: "charges like a war chariot",
            coolFact: "God of war, his chariot was pulled by four fire-breathing horses."
        ),
        "athena": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, Mount Olympus",
            weight: "as mighty as a goddess",
            speed: "thinks faster than she moves",
            coolFact: "Goddess of wisdom, legend says she sprang fully grown from Zeus's head."
        ),
        "hermes": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, Mount Olympus",
            weight: "as mighty as a god",
            speed: "faster than any other god",
            coolFact: "Messenger of the gods, he wore winged sandals to zip across the world."
        ),
        "apollo": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, Mount Olympus",
            weight: "as mighty as a god",
            speed: "rides the sun across the sky",
            coolFact: "God of the sun and music, he was said to pull the sun across the sky each day."
        ),
        "artemis": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, wild forests",
            weight: "as mighty as a goddess",
            speed: "runs swift as a deer",
            coolFact: "Goddess of the hunt and the moon, she roamed the woods with silver arrows."
        ),
        "hephaestus": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, a volcano forge",
            weight: "as mighty as a god",
            speed: "works tirelessly at his forge",
            coolFact: "God of the forge, he built magical armor and even robots out of gold."
        ),
        "hercules": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, ancient Greece",
            weight: "as mighty as the strongest hero",
            speed: "as strong as he is swift",
            coolFact: "The strongest Greek hero, he completed twelve nearly impossible labors."
        ),
        "medusa": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology",
            weight: "about as heavy as a grown-up",
            speed: "moves like a slithering snake",
            coolFact: "She had snakes for hair, and one look in her eyes turned people to stone."
        ),
        "kronos": AnimalFact(
            diet: "Omnivore",
            habitat: "Greek mythology, before the gods",
            weight: "as mighty as a Titan",
            speed: "as endless as time itself",
            coolFact: "He was the leader of the Titans, the giant beings who ruled before the gods."
        ),
    ]
}
