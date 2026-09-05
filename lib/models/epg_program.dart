class EpgProgram {
  final String channelId;
  final String title;
  final DateTime start;

  const EpgProgram({
    required this.channelId,
    required this.title,
    required this.start,
  });
}
