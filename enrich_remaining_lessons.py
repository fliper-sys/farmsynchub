#!/usr/bin/env python3
"""Generate enriched Dart code for lessons 034-100."""

import json

lessons_data = {
    'extra-034': {
        'title': 'Compost tea basics',
        'subtitle': 'A low-cost foliar feed and microbial booster.',
        'overview': 'Steep finished compost in water with aeration to activate beneficial microbes and nutrients for leaf and soil health.',
        'steps': ['Fill bucket with water', 'Add finished compost and aerate 24-48 hours', 'Strain through cloth', 'Dilute and spray at dawn'],
        'duration': '6 min',
        'q1': ('What is the main benefit of compost tea?', ['Beneficial microbes and slow-release nutrients', 'Replaces all pest management', 'Makes soil waterproof'], 0),
        'q1_exp': 'Compost tea delivers living microbes that improve soil health and nutrient availability.',
        'q2': ('How long should compost tea brew?', ['24-48 hours with aeration', '5 minutes', 'One week in sunlight'], 0),
        'q2_exp': 'Aeration during 24-48 hours allows beneficial microbes to multiply significantly.',
        'q3': ('When is the best time to spray?', ['Early morning when leaves are damp', 'Midday in full sun', 'During rain'], 0),
        'q3_exp': 'Early morning spray allows microbes to establish before sun stress kills them.',
        'video': 'Ov-ZCDS2p8g',
        'website': 'https://www.gardenmyths.com/compost-tea/',
        'track': 'AppStrings.soilManagement',
        'difficulty': 'Practical',
        'icon': 'Icons.bubble_chart_rounded',
        'tint': '0xFFEDE8FF',
    },
    'extra-035': {
        'title': 'Basic soil cover',
        'subtitle': 'Protect bare soil to reduce erosion.',
        'overview': 'Bare soil erodes quickly in rain and loses nutrients. Cover with residues or living crops to protect structure.',
        'steps': ['Collect crop residues after harvest', 'Spread 5-10 cm layer evenly', 'Plant cover crops if bare long-term'],
        'duration': '4 min',
        'q1': ('Why is bare soil a problem?', ['Erodes easily and loses nutrients', 'Stores water too well', 'Reduces pest habitat'], 0),
        'q1_exp': 'Rain impact breaks soil structure; water washes away topsoil and nutrients.',
        'q2': ('What is good soil cover?', ['Crop residues or cover plants', 'Plastic sheeting only', 'Rocks and gravel'], 0),
        'q2_exp': 'Organic cover improves soil while preventing erosion and wind damage.',
        'q3': ('How deep should cover be?', ['5-10 cm for protection', 'Barely visible', 'Over 20 cm thick'], 0),
        'q3_exp': '5-10 cm protects soil while allowing water and air penetration.',
        'video': 'sJ9LpL7X4Ys',
        'website': 'https://www.agronomy.org/cover-crops',
        'track': 'AppStrings.soilManagement',
        'difficulty': 'Practical',
        'icon': 'Icons.landscape_rounded',
        'tint': '0xFFDFF1FF',
    },
}

def generate_lesson(lesson_id, data):
    """Generate Dart code for a lesson."""
    q1_prompt, q1_opts, q1_corr = data['q1']
    q2_prompt, q2_opts, q2_corr = data['q2']
    q3_prompt, q3_opts, q3_corr = data['q3']
    
    steps_lines = ',\n      '.join(f"'{s}'" for s in data['steps'])
    opts1 = ',\n          '.join(f"'{o}'" for o in q1_opts)
    opts2 = ',\n          '.join(f"'{o}'" for o in q2_opts)
    opts3 = ',\n          '.join(f"'{o}'" for o in q3_opts)
    
    code = f"""  const LearningLesson(
    id: '{lesson_id}',
    title: '{data['title']}',
    subtitle: '{data['subtitle']}',
    baseProgress: 0.05,
    duration: '{data.get('duration', '5 min')}',
    tint: Color(0x{data['tint']}),
    track: {data['track']},
    difficulty: '{data['difficulty']}',
    icon: {data['icon']},
    imageAsset: AppAssets.uiGallery01,
    overview: '{data['overview']}',
    steps: <String>[
      {steps_lines}
    ],
    questions: <LessonQuestion>[
      LessonQuestion(
        id: '{lesson_id}-1',
        prompt: '{q1_prompt}',
        options: <String>[
          {opts1}
        ],
        correctOptionIndex: {q1_corr},
        explanation: '{data['q1_exp']}',
      ),
      LessonQuestion(
        id: '{lesson_id}-2',
        prompt: '{q2_prompt}',
        options: <String>[
          {opts2}
        ],
        correctOptionIndex: {q2_corr},
        explanation: '{data['q2_exp']}',
      ),
      LessonQuestion(
        id: '{lesson_id}-3',
        prompt: '{q3_prompt}',
        options: <String>[
          {opts3}
        ],
        correctOptionIndex: {q3_corr},
        explanation: '{data['q3_exp']}',
      ),
    ],
    tools: <String>['Tools'],
    youtubeVideoId: '{data['video']}',
    websiteUrl: '{data['website']}',
  ),"""
    return code

if __name__ == '__main__':
    for lesson_id, data in lessons_data.items():
        print(generate_lesson(lesson_id, data))
        print()
