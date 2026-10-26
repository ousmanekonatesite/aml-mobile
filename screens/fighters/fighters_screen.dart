import 'package:flutter/material.dart';

import 'fighter_profile_screen.dart';
import '../../services/fighter_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets_flag.dart';

class FightersScreen extends StatefulWidget {
  const FightersScreen({super.key});

  @override
  State<FightersScreen> createState() => _FightersScreenState();
}

class _FightersScreenState extends State<FightersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FighterRepository _repository = FighterRepository();

  String selectedCategory = 'Tous';
  bool _loading = true;
  String? _loadError;

  List<Map<String, dynamic>> fighters = [];

  @override
  void initState() {
    super.initState();
    _loadFighters();
  }

  Future<void> _loadFighters() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final live = await _repository.getFighters();
      if (!mounted) return;
      setState(() {
        if (live.isNotEmpty) fighters = live;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Impossible de charger les données AML pour le moment.';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = fighters.where((fighter) {
      final query = _searchController.text.toLowerCase();

      final matchesSearch =
          fighter['name'].toString().toLowerCase().contains(query) ||
          fighter['nickname'].toString().toLowerCase().contains(query);

      final matchesCategory =
          selectedCategory == 'Tous' ||
          fighter['category'] == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text(
          'Fighters',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un fighter',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: const Color(0xFF171717),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                'Tous',
                'Poids légers',
                'Poids mi-moyens',
                'Poids lourds',
              ].map((category) {
                final selected = selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    selectedColor: const Color(0xFF00AEEF),
                    backgroundColor: const Color(0xFF171717),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 15, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final fighter = filtered[index];

                return _fighterCard(
                  context,
                  fighter,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fighterCard(
    BuildContext context,
    Map<String, dynamic> fighter,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FighterProfileScreen(
              fighter: fighter,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(16),
              ),
              child: (fighter['photo_url']?.toString().trim().isNotEmpty ?? false)
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: fighter['photo_url'].toString(), width: 64, height: 76, fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white38, size: 38)))
                  : const Icon(Icons.person, color: Colors.white38, size: 38),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (fighter['name']?.toString().trim().isNotEmpty == true) ? fighter['name'] : 'Combattant à confirmer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if ((fighter['nickname']?.toString() ?? '').trim().isNotEmpty)
                    Text(
                      '"${fighter['nickname']}"',
                      style: const TextStyle(
                        color: Color(0xFF00AEEF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(children: [
                    AmlFlag(code: fighter['countryCode']?.toString(), height: 12),
                    const SizedBox(width: 7),
                    Flexible(child: Text('${fighter['category']}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '${fighter['wins']} V  •  ${fighter['losses']} D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

