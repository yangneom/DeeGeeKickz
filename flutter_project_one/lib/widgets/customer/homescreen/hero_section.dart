import 'package:flutter/material.dart';

/// Hero / banner section.
///
/// Matches HTML:
/// <section class="relative w-full h-[85vh] overflow-hidden bg-primary
///   flex items-center justify-start">
///   <img class="... opacity-80 grayscale mix-blend-luminosity" .../>
///   <div class="relative z-10 ... max-w-2xl text-on-primary">
///     <p>NEW SEASON ARRIVAL</p>
///     <h2>ENGINEERED FOR SPEED</h2>
///     <p>Discover the next generation...</p>
///   </div>
/// </section>
///
/// Headline font size: 32px (text-headline-lg-mobile) on mobile,
/// 80px (text-display-lg) on md and up.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  static const String _heroImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBxJxWno1DIhKpCA7lZJF763DHKcT385Nn_g8Hy9ss8hlnvnU6sHLwjTuTGsQ8srJNRV2a0rGXvXBmWhJQXmc-_CapyJJ-x5PI9PqBXy8v0DKjrvvUjlGWIIMTynFbXu9stNjuLJIvORDxZfg6ug2DPGqbYmK21U_5262TMpnVKDaIzztQcCsRf7oXNfSibeMXzQDS4v6dJGpuaJKwo2H8gUZ5QnkIEpILR7kcviERSO4phWurzHBcHrxz8I_wm8hxdVreXoJxkZXY';

  static const double _mdBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      height: screenHeight * 0.85, // h-[85vh]
      color: Colors.black, // bg-primary
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image, grayscale + 80% opacity to mimic
          // `opacity-80 grayscale mix-blend-luminosity`
          Opacity(
            opacity: 0.8,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: Image.network(
                _heroImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Foreground text content
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= _mdBreakpoint;
              final horizontalPadding = isDesktop ? 48.0 : 16.0;

              return Align(
                alignment: Alignment.centerLeft,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // NEW SEASON ARRIVAL
                              const Text(
                                'NEW SEASON ARRIVAL',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14, // label-lg
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.8, // tracking-[0.2em]
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16), // mb-4

                              // ENGINEERED FOR SPEED
                              Text(
                                'ENGINEERED\nFOR SPEED',
                                style: TextStyle(
                                  fontFamily: 'Archivo Narrow',
                                  fontSize: isDesktop ? 80 : 32,
                                  height: isDesktop ? 88 / 80 : 36 / 32,
                                  letterSpacing: -0.02 * (isDesktop ? 80 : 32),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8), // mb-base

                              // Body copy
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 448), // max-w-md
                                child: const Text(
                                  'Discover the next generation of performance footwear. '
                                  'Precision crafted for those who demand more from every step.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18, // body-lg
                                    height: 28 / 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 48), // mb-lg
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}