import 'supabase_service.dart';

class FighterRepository {
  Future<List<Map<String, dynamic>>> getFighters() async {
    final client = SupabaseService.client;
    if (client == null) return [];

    final rows = await client.from('fighters').select('*');
    final fighters = List<Map<String, dynamic>>.from(rows);

    final countryRows = await _safeRows(client, 'countries');
    final categoryRows = await _safeRows(client, 'weight_categories');
    final clubRows = await _safeRows(client, 'clubs');
    final statsRows = await _safeRows(client, 'fighter_stats');

    final countries = _index(countryRows);
    final countriesByCode = {
      for (final row in countryRows)
        if (row['code'] != null) row['code'].toString().toUpperCase(): row,
    };
    final categories = _index(categoryRows);
    final clubs = _index(clubRows);
    final stats = _indexByFighter(statsRows);

    return fighters.map((row) {
      final country = countries[row['country_id']] ?? countriesByCode[(row['country_code'] ?? '').toString().trim().toUpperCase()];
      final category = categories[row['weight_category_id'] ?? row['category_id']];
      final club = clubs[row['club_id']];
      final fighterStats = stats[row['id']];

      return _normalize(row, country, category, club, fighterStats);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getFightHistory(String fighterId) async {
    final client = SupabaseService.client;
    if (client == null || fighterId.isEmpty) return [];
    final rows = await client.from('fights').select('id,event_id,fighter_a_id,fighter_b_id,weight_category_id,bout_order,scheduled_rounds,status,winner_fighter_id,result,finish_round,finish_time,decision_type').or('fighter_a_id.eq.$fighterId,fighter_b_id.eq.$fighterId').order('bout_order', ascending: false);
    final fights = List<Map<String, dynamic>>.from(rows);
    if (fights.isEmpty) return [];
    final eventIds = fights.map((x) => x['event_id']?.toString()).whereType<String>().where((x) => x.isNotEmpty).toSet().toList();
    final opponentIds = <String>{};
    for (final f in fights) {
      final a = f['fighter_a_id']?.toString();
      final b = f['fighter_b_id']?.toString();
      final opponent = a == fighterId ? b : a;
      if (opponent != null && opponent.isNotEmpty) opponentIds.add(opponent);
    }
    final events = <String, Map<String, dynamic>>{};
    final opponents = <String, Map<String, dynamic>>{};
    if (eventIds.isNotEmpty) {
      final data = await client.from('events').select('id,name,city,starts_at').inFilter('id', eventIds);
      for (final row in List<Map<String, dynamic>>.from(data)) events[row['id'].toString()] = row;
    }
    if (opponentIds.isNotEmpty) {
      final data = await client.from('fighters').select('id,first_name,last_name,nickname,photo_url').inFilter('id', opponentIds.toList());
      for (final row in List<Map<String, dynamic>>.from(data)) opponents[row['id'].toString()] = row;
    }
    return fights.map((f) {
      final opponentId = f['fighter_a_id']?.toString() == fighterId ? f['fighter_b_id']?.toString() : f['fighter_a_id']?.toString();
      final opponent = opponents[opponentId];
      final winner = f['winner_fighter_id']?.toString();
      final result = winner == null ? 'Résultat officiel à venir' : (winner == fighterId ? 'Victoire' : 'Défaite');
      return {
        ...f,
        'event': events[f['event_id']?.toString()] ?? <String, dynamic>{},
        'opponent': opponent ?? <String, dynamic>{},
        'display_result': result,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _safeRows(dynamic client, String table) async {
    try {
      final data = await client.from(table).select('*');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  int _ageFrom(dynamic dob) {
    final d = DateTime.tryParse((dob ?? '').toString());
    if (d == null) return 0;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age < 0 ? 0 : age;
  }

  Map<dynamic, Map<String, dynamic>> _index(List<Map<String, dynamic>> rows) {
    return {
      for (final row in rows)
        if (row['id'] != null) row['id']: row,
    };
  }

  Map<dynamic, Map<String, dynamic>> _indexByFighter(
    List<Map<String, dynamic>> rows,
  ) {
    return {
      for (final row in rows)
        if (row['fighter_id'] != null) row['fighter_id']: row,
    };
  }

  Map<String, dynamic> _normalize(
    Map<String, dynamic> row,
    Map<String, dynamic>? country,
    Map<String, dynamic>? category,
    Map<String, dynamic>? club,
    Map<String, dynamic>? stats,
  ) {
    final firstName = (row['first_name'] ?? '').toString().trim();
    final lastName = (row['last_name'] ?? '').toString().trim();
    final fullName = (row['name'] ?? '$firstName $lastName').toString().trim();

    final wins = _int(row['wins'] ?? stats?['wins']);
    final losses = _int(row['losses'] ?? stats?['losses']);
    final draws = _int(row['draws'] ?? stats?['draws']);

    return {
      ...row,
      'name': fullName,
      'nickname': row['nickname'] ?? '',
      'country': country?['flag_emoji'] ?? country?['flag'] ?? '',
      'countryCode': (row['country_code'] ?? country?['code'] ?? '').toString().trim().toUpperCase(),
      'countryName': country?['name'] ?? row['country_name'] ?? '—',
      'category': category?['name'] ?? row['category_name'] ?? '—',
      'club': club?['name'] ?? row['club_name'] ?? '—',
      'city': row['city'] ?? club?['city'] ?? '—',
      'style': row['fighting_style'] ?? row['style'] ?? 'MMA',
      'id': row['id']?.toString(),
      'slug': row['slug']?.toString() ?? '',
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'ko': _int(row['ko_wins'] ?? row['ko'] ?? stats?['ko_tko_wins'] ?? stats?['ko_wins'] ?? stats?['ko']),
      'submissions': _int(row['submission_wins'] ?? row['submissions'] ?? stats?['submission_wins'] ?? stats?['submissions']),
      'decisions': _int(row['decision_wins'] ?? row['decisions'] ?? stats?['decision_wins'] ?? stats?['decisions']),
      'fights': _int(row['fights'] ?? stats?['fights'], fallback: wins + losses + draws),
      'age': _int(row['age'] ?? stats?['age'], fallback: _ageFrom(row['date_of_birth'])),
      'height': _formatCm(row['height_cm'] ?? row['height']),
      'reach': _formatCm(row['reach_cm'] ?? row['reach']),
      'stance': row['stance'] ?? '—',
      'knockdowns': _int(row['knockdowns'] ?? stats?['knockdowns']),
      'sigStrikes': _int(row['sig_strikes_attempted'] ?? stats?['sig_strikes_attempted']),
      'sigStrikesLanded': _int(row['sig_strikes_landed'] ?? stats?['sig_strikes_landed']),
      'takedowns': _int(row['takedowns_attempted'] ?? stats?['takedowns_attempted']),
      'takedownsLanded': _int(row['takedowns_landed'] ?? stats?['takedowns_landed']),
      'subAttempts': _int(row['submission_attempts'] ?? stats?['submission_attempts']),
      'controlTime': row['control_time'] ?? stats?['control_time'] ?? '00:00',
      'headStrikes': _int(row['head_strikes_landed'] ?? stats?['head_strikes_landed']),
      'bodyStrikes': _int(row['body_strikes_landed'] ?? stats?['body_strikes_landed']),
      'legStrikes': _int(row['leg_strikes_landed'] ?? stats?['leg_strikes_landed']),
      'avgFightTime': row['avg_fight_time'] ?? stats?['avg_fight_time'] ?? '—',
    };
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  String _formatCm(dynamic value) {
    if (value == null) return '—';
    final number = double.tryParse(value.toString());
    if (number == null) return value.toString();
    if (number >= 3) return '${number.toStringAsFixed(0)} cm';
    return '${number.toStringAsFixed(2)} m';
  }
}
