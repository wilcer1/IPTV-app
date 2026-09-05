import 'competition.dart';
import 'team.dart';

class MatchFixture {
  final int id;
  final DateTime utcKickoff;
  final String status;
  final Competition competition;
  final Team homeTeam;
  final Team awayTeam;
  final int? homeScore;
  final int? awayScore;

  const MatchFixture({
    required this.id,
    required this.utcKickoff,
    required this.status,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
  });

  bool get isLive => status == 'IN_PLAY' || status == 'PAUSED';
  bool get isFinished => status == 'FINISHED';

  factory MatchFixture.fromJson(Map<String, dynamic> json) {
    final score = json['score'] as Map<String, dynamic>?;
    final fullTime = score?['fullTime'] as Map<String, dynamic>?;

    return MatchFixture(
      id: json['id'] as int,
      utcKickoff: DateTime.parse(json['utcDate'] as String),
      status: json['status'] as String? ?? 'SCHEDULED',
      competition: Competition.fromJson(json['competition'] as Map<String, dynamic>),
      homeTeam: Team.fromJson(json['homeTeam'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(json['awayTeam'] as Map<String, dynamic>),
      homeScore: fullTime?['home'] as int?,
      awayScore: fullTime?['away'] as int?,
    );
  }
}
