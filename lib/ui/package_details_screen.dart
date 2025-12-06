import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class PackageDetailsScreen extends StatelessWidget {
  final String packageId;
  final Map<String, dynamic> packageData;

  const PackageDetailsScreen({
    Key? key,
    required this.packageId,
    required this.packageData,
  }) : super(key: key);

  static const Color accent = Color(0xFFC2868B);
  static const Color lightPink = Color(0xFFFADADD);

  @override
  Widget build(BuildContext context) {
    final String name = (packageData['name'] ?? '') as String;
    final String location =
    (packageData['location'] ?? 'Kuala Lumpur, Malaysia') as String;
    final String description =
    (packageData['description'] ?? 'No description provided.') as String;

    final double price =
        (packageData['price'] as num?)?.toDouble() ?? 0.0;

    // these are optional lists you can fill from Admin side later
    final List<String> roomFacilities =
    _castStringList(packageData['roomFacilities']);
    final List<String> motherServices =
    _castStringList(packageData['motherServices']);
    final List<String> babyServices =
    _castStringList(packageData['babyServices']);

    final List<String> images =
    _castStringList(packageData['images']);

    final double priceOneMonth = price;
    final double priceTwoMonth = price * 1.5; // +50% for 2nd month

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: accent),
        title: const Text(
          'Package Details',
          style: TextStyle(
            color: accent,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------- HEADER IMAGE / CAROUSEL ----------
            _HeaderImages(images: images),

            const SizedBox(height: 16),

            // ---------- TITLE + LOCATION + PRICE ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 18, color: accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // price
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: lightPink,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confinement Pricing',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1 month (28 days): RM ${priceOneMonth.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '2 months (56 days): RM ${priceTwoMonth.toStringAsFixed(2)}   (+50% long-stay)',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(thickness: 0.7, height: 0),

            // ---------- OVERVIEW / DESCRIPTION ----------
            _SectionWrapper(
              title: 'Overview',
              child: Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),

            // ---------- ROOM FACILITIES ----------
            _SectionWrapper(
              title: 'Room & Centre Facilities',
              child: _buildBulletList(
                roomFacilities,
                emptyText:
                'Admin can fill room facilities here (e.g. Single room, attached bathroom, TV, Wi-Fi, daily housekeeping).',
              ),
            ),

            // ---------- MOTHER CARE SERVICES ----------
            _SectionWrapper(
              title: 'Mother Care Services',
              child: _buildBulletList(
                motherServices,
                emptyText:
                'Admin can list mother care services here (e.g. Postpartum check-ups, breastfeeding guidance, herbal baths).',
              ),
            ),

            // ---------- BABY CARE SERVICES ----------
            _SectionWrapper(
              title: 'Baby Care Services',
              child: _buildBulletList(
                babyServices,
                emptyText:
                'Admin can list baby care services here (e.g. 24/7 baby monitoring, jaundice observation, daily bath).',
              ),
            ),

            const SizedBox(height: 90), // space above bottom button
          ],
        ),
      ),

      // ---------- FLOATING BOOK BUTTON ----------
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.black26, width: 1.3),
                ),
                elevation: 3,
                shadowColor: Colors.black26,
              ),
              onPressed: () {
                // Directly go to checkout with this one package (qty=1)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      selectedPackages: [
                        {
                          'id': packageId,
                          'name': name,
                          'price': price,
                          'location': location,
                          'quantity': 1,
                        }
                      ],
                    ),
                  ),
                );
              },
              child: const Text(
                'Select & Book Package',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------- HELPERS ---------

  static List<String> _castStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  Widget _buildBulletList(List<String> items, {required String emptyText}) {
    if (items.isEmpty) {
      return Text(
        emptyText,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Colors.black54,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((text) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ',
                  style: TextStyle(fontSize: 14, height: 1.4)),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HeaderImages extends StatefulWidget {
  final List<String> images;

  const _HeaderImages({Key? key, required this.images}) : super(key: key);

  @override
  State<_HeaderImages> createState() => _HeaderImagesState();
}

class _HeaderImagesState extends State<_HeaderImages> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.images.isNotEmpty;

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        children: [
          // main image area
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: hasImages
                ? PageView.builder(
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, index) {
                final url = widget.images[index];
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFFADADD),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.black45,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            )
                : Container(
              color: const Color(0xFFFADADD),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: Colors.black45,
                ),
              ),
            ),
          ),

          // dot indicator
          if (hasImages)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final bool active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                      active ? Colors.white : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionWrapper({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
