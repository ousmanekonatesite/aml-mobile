import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../widgets_flag.dart';

class FighterCardScreen extends StatelessWidget {
  final Map<String, dynamic> fighter;

  const FighterCardScreen({
    super.key,
    required this.fighter,
  });

  @override
  Widget build(BuildContext context) {
    final profileUrl =
        'https://aml.africa/fighter/${fighter['id']}';

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text(
          'Carte professionnelle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _professionalCard(profileUrl),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('RETOUR AU PROFIL & AUX STATISTIQUES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00AEEF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Parcours AML',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _infoRow(
              Icons.sports_mma,
              'Style',
              fighter['style'],
            ),

            _infoRow(
              Icons.groups,
              'Club',
              fighter['club'],
            ),

            _infoRow(
              Icons.location_on,
              'Ville',
              fighter['city'],
            ),

            _infoRow(
              Icons.flag,
              'Pays',
              fighter['countryName'],
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Statistiques',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _stat(
                  'Victoires',
                  fighter['wins'].toString(),
                ),
                _stat(
                  'Défaites',
                  fighter['losses'].toString(),
                ),
                _stat(
                  'Nuls',
                  fighter['draws'].toString(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _stat(
                  'KO/TKO',
                  fighter['ko'].toString(),
                ),
                _stat(
                  'Soumissions',
                  fighter['submissions'].toString(),
                ),
                _stat(
                  'Décisions',
                  fighter['decisions'].toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _professionalCard(String profileUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF191919),
            Color(0xFF090909),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF00AEEF).withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00AEEF).withOpacity(0.12),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AML',
                style: TextStyle(
                  color: Color(0xFF00AEEF),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                fighter['category'],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF252525),
              border: Border.all(
                color: const Color(0xFF00AEEF),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white38,
              size: 65,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            fighter['name'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '"${fighter['nickname']}"',
            style: const TextStyle(
              color: Color(0xFF00AEEF),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AmlFlag(code: fighter['countryCode']?.toString(), height: 16),
            const SizedBox(width: 8),
            Flexible(child: Text('${fighter['countryName']}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))),
          ]),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _cardRecord(
                'V',
                fighter['wins'].toString(),
              ),
              _cardRecord(
                'D',
                fighter['losses'].toString(),
              ),
              _cardRecord(
                'N',
                fighter['draws'].toString(),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: profileUrl,
              version: QrVersions.auto,
              size: 145,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'SCANNER POUR VOIR LE PROFIL AML',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'aml.africa',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardRecord(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF00AEEF),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
