#if DEBUG
import Foundation

/// Only invoked after the explicit UI-test flag. Resolver unit tests remain real.
enum RetroTestFixtures {
    /// Deliberately longer than ordinary narration. Separate from battle-success,
    /// whose exact short answer is used by the battle lifecycle tests.
    static let readingStory = """
    The lion stepped into the sunny clearing while the gorilla watched from the shade of a broad tree. Neither rushed forward. The lion circled carefully, looking for room to turn, and the gorilla planted both feet beside a fallen branch. A breeze stirred the tall grass between them. When the lion moved closer, the gorilla raised its arms and gave a warning call. The lion stopped, lowered its shoulders, and chose a different path around the clearing instead of meeting that powerful guard head on.

    For a moment, it looked as though the gorilla had the better position. Its strong arms could protect a wide space, and the nearby tree left very little room behind it. But the lion kept changing direction. First it moved toward the long grass, then it made a quick turn back toward the open ground. The gorilla followed each movement carefully. That small change of pace gave the lion a chance to move past the branch before the gorilla could turn around.

    The contest ended with a final roar and a clear patch of ground between the two animals. The lion had used quick footwork to gain the better position. The gorilla stepped back into the shade, safe and ready to rest. Both animals showed their strengths, but patience and a well-timed turn decided this imaginary match.
    """

    static let readingTeamStory = """
    The two teams gathered on opposite sides of the open arena. The lion and tiger stayed close to the grass, while the gorilla and wolf watched the middle. Across the clearing, the elephant stood beside the great white shark's water lane. High above them, the bald eagle circled as the T-Rex took a slow step forward. Every fighter had a different strength, so the teams needed more than speed to find a way through. They paused, watched, and waited for a useful opening.

    The elephant's size made the center difficult to cross. The wolf spotted a narrower path near the edge and guided its teammates toward it. The tiger moved first, with the lion following a few steps behind. Meanwhile, the gorilla stayed near the group so that nobody became separated. The eagle noticed their plan and swept overhead, but the team changed direction together. That careful movement gave them enough space to regroup before the larger fighters could turn to meet them.

    At the end of the imaginary contest, Team A held the open ground. The lion earned the star-player badge for keeping the group together during the final turn. The other team returned safely to its side of the arena. Size, strength, and speed all mattered, but this time the winning team made the most of its teamwork.
    """

    static let readingWhy = "The lion found room to turn while the gorilla guarded a smaller space. Quick changes of direction helped the lion reach the open ground first. This imaginary result describes the match in the story; it does not mean that one animal always wins in nature."
    static let readingFact = "Lions are social cats that often live in groups called prides. They spend much of the day resting, especially when the weather is hot. Their loud calls help members of a pride stay in touch across long distances. A real animal's daily life includes resting, finding food, and caring for its young."

    static func battle(_ fighter1: Animal, _ fighter2: Animal) throws -> BattleResult {
        if AppConfig.fixtureScenario == "offline" { throw BattleError.networkUnavailable }
        if AppConfig.fixtureScenario == "reading-long" {
            return BattleResult(winner: fighter1.id, narration: readingStory,
                funFact: readingFact, winnerHealthPercent: 72, loserHealthPercent: 18,
                why: readingWhy)
        }
        let draw = AppConfig.fixtureScenario == "battle-draw"
        return BattleResult(winner: draw ? "draw" : fighter1.id,
            narration: "Fixture battle completed.",
            funFact: "This deterministic result is used only by automated UI tests.",
            winnerHealthPercent: 72, loserHealthPercent: 18)
    }

    static func melee(_ teamA: [Animal], _ teamB: [Animal]) throws -> MeleeResult {
        if AppConfig.fixtureScenario == "offline" { throw BattleError.networkUnavailable }
        guard let mvp = teamA.first else { throw BattleError.serverError }
        if AppConfig.fixtureScenario == "reading-long" {
            return MeleeResult(winningTeam: .A, narration: readingTeamStory,
                funFact: readingFact, mvp: mvp.id, teamAHealth: 72, teamBHealth: 18)
        }
        return MeleeResult(winningTeam: .A, narration: "Fixture battle completed.",
            funFact: "Team fixtures do not contact external services.", mvp: mvp.id,
            teamAHealth: 72, teamBHealth: 18)
    }
}
#endif
