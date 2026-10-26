import 'supabase_service.dart';

class AmlContentRepository {
  static const _aml10Image =
      'https://aml-ci.com/wp-content/uploads/2026/06/122225-img-20260609-wa0016-1920x1280.webp';

  Future<List<Map<String, dynamic>>> published({String? type}) async {
    final c = SupabaseService.client;
    if (c != null) {
      try {
        var q = c.from('aml_content_items').select('*').eq('status', 'published');
        if (type != null) q = q.eq('content_type', type);
        final rows = await q.order('published_at', ascending: false).limit(50);
        final result = List<Map<String, dynamic>>.from(rows);
        if (result.isNotEmpty) return result;
      } catch (_) {
        // On garde le contenu officiel embarqué en secours.
      }
    }
    return _officialFallback(type: type);
  }

  List<Map<String, dynamic>> _officialFallback({String? type}) {
    final items = <Map<String, dynamic>>[
      {
        'id': 'aml10-official',
        'title': 'AML 10 : L’Afrique du MMA se donne rendez-vous à Korhogo',
        'excerpt': 'Une édition anniversaire placée sous le signe de la Jeunesse et de la Solidarité, avec des combattants venus de plusieurs pays.',
        'content_type': 'event',
        'image_url': _aml10Image,
        'source_url': 'https://aml-ci.com/aml-10-lafrique-du-mma-se-donne-rendez-vous-a-korhogo-pour-une-edition-jeunesse-et-solidarite/',
      },
      {
        'id': 'aml-immaf-2026',
        'title': 'MMA africain : cinq Ivoiriens prêts pour Luanda 2026',
        'excerpt': 'La AML met en avant la sélection ivoirienne engagée sur la scène internationale de l’IMMAF.',
        'content_type': 'news',
        'image_url': '',
        'source_url': 'https://aml-ci.com/',
      },
      {
        'id': 'aml-ramadan-2026',
        'title': 'AML : sport, solidarité et fraternité',
        'excerpt': 'Retour sur l’action de solidarité menée à l’Université Félix Houphouët-Boigny de Cocody.',
        'content_type': 'news',
        'image_url': '',
        'source_url': 'https://aml-ci.com/',
      },
      {
        'id': 'aml-season2',
        'title': 'AML : une saison 2 qui s’achève dans la gloire',
        'excerpt': 'La saison 2 s’est terminée avec treize combats et plusieurs ceintures en jeu.',
        'content_type': 'news',
        'image_url': '',
        'source_url': 'https://aml-ci.com/news/',
      },
    ];

    if (type == null) return items;
    return items.where((item) => item['content_type'] == type).toList();
  }
}
