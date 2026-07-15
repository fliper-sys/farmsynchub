#!/usr/bin/env python3
"""Generate enriched lesson code for extra-034 through extra-100."""

lessons = [
    {
        'id': 'extra-034',
        'title': 'Compost tea basics',
        'overview': 'Steep finished compost in water with aeration to activate beneficial microbes and nutrients for crops.',
        'steps': ['Fill bucket with water', 'Add finished compost and aerate 24-48 hours', 'Strain through cloth', 'Dilute and spray on leaf undersides at dawn'],
        'q1': ('What is the main benefit of compost tea?', ['It provides beneficial microbes and slow-release nutrients', 'It replaces all pest management', 'It makes soil waterproof'], 0, 'Compost tea delivers living microbes that improve soil health and available nutrients.'),
        'q2': ('How long should compost tea brew?', ['24-48 hours with aeration', '5 minutes', 'One week in sunlight'], 0, 'Aeration during 24-48 hours allows beneficial microbes to multiply before use.'),
        'q3': ('When is the best time to spray compost tea?', ['Early morning when leaves are damp', 'Midday in full sun', 'During rain'], 0, 'Early morning spray allows microbes to establish on leaves before sun stress kills them.'),
        'video': 'Ov-ZCDS2p8g',
        'website': 'https://www.gardenersworld.com/how-to-make-compost-tea/',
    },
    {
        'id': 'extra-035',
        'title': 'Basic soil cover',
        'overview': 'Bare soil erodes in rain and loses nutrients. Cover with residues or live crops to protect soil structure.',
        'steps': ['Collect crop residues', 'Spread 5-10 cm layer evenly', 'Plant cover crops if area will be bare long-term'],
        'q1': ('Why is bare soil a problem?', ['It erodes easily and loses nutrients', 'It stores water too well', 'It reduces pest habitat'], 0, 'Rain impact breaks down soil structure; water washes away topsoil and nutrients.'),
        'q2': ('What is a good soil cover source?', ['Crop residues or cover crop plants', 'Plastic sheeting only', 'Rocks and gravel'], 0, 'Organic cover improves soil while preventing erosion.'),
        'q3': ('How deep should mulch cover be?', ['5-10 cm for good protection', 'Barely visible', 'Over 20 cm thick'], 0, '5-10 cm protects soil while allowing water penetration and decomposition.'),
        'video': 'sJ9LpL7X4Ys',
        'website': 'https://www.agronomy.org/cover-crops',
    },
]

def generate_lesson(lesson):
    """Generate Dart code for a lesson."""
    q1_prompt, q1_opts, q1_corr, q1_exp = lesson['q1']
    q2_prompt, q2_opts, q2_corr, q2_exp = lesson['q2']
    q3_prompt, q3_opts, q3_corr, q3_exp = lesson['q3']
    
    opts1_str = ',\n          '.join(f"'{opt}'" for opt in q1_opts)
    opts2_str = ',\n          '.join(f"'{opt}'" for opt in q2_opts)
    opts3_str = ',\n          '.join(f"'{opt}'" for opt in q3_opts)
    
    steps_str = ',\n      '.join(f"'{s}'" for s in lesson['steps'])
    
    code = f"""  const LearningLesson(
    id: '{lesson['id']}',
    title: '{lesson['title']}',
    subtitle: '{lesson['subtitle']}',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFEDE8FF),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.eco_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: '{lesson['overview']}',
    steps: <String>[
      {steps_str}
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: '{lesson['id']}-1',
        prompt: '{q1_prompt}',
        options: <String>[
          {opts1_str}
        ],
        correctOptionIndex: {q1_corr},
        explanation: '{q1_exp}',
      ),
      LessonQuestion(
        id: '{lesson['id']}-2',
        prompt: '{q2_prompt}',
        options: <String>[
          {opts2_str}
        ],
        correctOptionIndex: {q2_corr},
        explanation: '{q2_exp}',
      ),
      LessonQuestion(
        id: '{lesson['id']}-3',
        prompt: '{q3_prompt}',
        options: <String>[
          {opts3_str}
        ],
        correctOptionIndex: {q3_corr},
        explanation: '{q3_exp}',
      ),
    ],
    tools: <String>['Bucket, aerator'],
    youtubeVideoId: '{lesson['video']}',
    websiteUrl: '{lesson['website']}',
  ),"""
    return code

if __name__ == '__main__':
    for lesson in lessons:
        print(generate_lesson(lesson))
