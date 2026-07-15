#!/usr/bin/env python3
"""Generate complete enriched Dart code for lessons 035-100."""

lessons_data = {
    'extra-041': {
        'title': 'Soil aeration', 'overview': 'Compacted soil restricts roots and water. Break compaction mechanically or biologically.',
        'steps': ['Avoid vehicle traffic when soil is wet', 'Use deep digging or aeration tools', 'Add organic matter', 'Grow deep roots'],
        'q': [('What is main problem with compacted soil?', ['Roots cannot penetrate and water drains poorly', 'Soil becomes too light', 'Weeds cannot grow'], 0, 'Compaction restricts root depth and water.'),
              ('When avoid heavy machinery?', ['When soil is wet, compacts easily', 'Only in winter', 'Never compacts'], 0, 'Wet soil compresses from wheel traffic.'),
              ('Improve aeration biologically?', ['Add organic matter and grow cover crops', 'Increase fertilizer', 'Remove organics'], 0, 'Organic matter and roots create pores.')],
        'video': 'ql0kI62sKvQ', 'url': 'https://www.soilhealth.org/improving-soil-compaction/'
    },
    'extra-042': {
        'title': 'Simple fence checks', 'overview': 'Regular fence checks prevent escapes, theft, and predator access.',
        'steps': ['Walk boundary weekly looking for damage', 'Check for holes, loose posts, rust', 'Repair holes immediately', 'Replace weak sections seasonally'],
        'q': [('Why check fences regularly?', ['Small holes become large; prevent escapes', 'Fences never need repair', 'Only check after escape'], 0, 'Early detection prevents problems.'),
              ('What to look for?', ['Holes, loose posts, rust, damage', 'Only color fading', 'Nothing specific'], 0, 'These signs indicate weaknesses.'),
              ('When repair damage?', ['Immediately prevent escape', 'When convenient', 'After animals escape'], 0, 'Quick repair prevents losses.')],
        'video': 'pVJwz8KqSrE', 'url': 'https://www.ext.vt.edu/fencing'
    },
    'extra-043': {
        'title': 'Low-cost drying', 'overview': 'Use shade, racks, and airflow to dry produce safely.',
        'steps': ['Select mature, healthy produce', 'Spread thinly on clean racks', 'Place in shaded, ventilated area', 'Turn regularly for even drying'],
        'q': [('Why shade drying better than sun?', ['Shade prevents bleaching, retains nutrients', 'Sun faster', 'Shade hard'], 0, 'Shade protects color and nutrients.'),
              ('Why turn regularly?', ['Ensures even drying, prevents mold', 'Makes harder', 'No reason'], 0, 'Turning improves air circulation.'),
              ('Sign produce is dry enough?', ['No moisture when squeezed, brittle', 'Still feels heavy', 'Turns black'], 0, 'Dry produce is shelf-stable.')],
        'video': 'WvSrLMtqKiA', 'url': 'https://www.fao.org/3/i3972e/i3972e.pdf'
    },
    'extra-044': {
        'title': 'Hand tool care', 'overview': 'Proper maintenance saves time and extends tool life.',
        'steps': ['Clean dirt after each use', 'Sharpen blades regularly', 'Oil hinges and moving parts', 'Store in dry location'],
        'q': [('Why sharpen tools regularly?', ['Sharp tools need less effort and faster', 'Make more noise', 'Wastes time'], 0, 'Sharp tools are safer and faster.'),
              ('When oil tools?', ['After use to prevent rust', 'Never, makes slippery', 'Only yearly'], 0, 'Oil prevents rust and keeps smooth.'),
              ('Best storage for tools?', ['Dry location protected', 'Outside in weather', 'In water'], 0, 'Dry storage prevents rust.')],
        'video': 'RpxvJY8u8RI', 'url': 'https://www.gardenmyths.com/tool-maintenance/'
    },
    'extra-045': {
        'title': 'Nursery labeling', 'overview': 'Clear labeling prevents transplanting wrong varieties.',
        'steps': ['Record sowing date and variety on label', 'Use waterproof marker and stake', 'Place label at row start and end', 'Check labels regularly'],
        'q': [('Why label nursery rows?', ['Prevents wrong varieties, tracks performance', 'Just suggestion', 'Only big farms'], 0, 'Labels ensure correct transplanting.'),
              ('What on labels?', ['Variety name and sowing date', 'Only variety', 'Only date'], 0, 'Both track age and performance.'),
              ('Why waterproof marker?', ['Survives water in nursery', 'Regular ok', 'Color irrelevant'], 0, 'Waterproof remains legible.')],
        'video': 'KG7d1iBFZ0A', 'url': 'https://www.almanac.com/gardening/starting-seeds'
    },
    'extra-046': {
        'title': 'Simple pest traps', 'overview': 'Traps monitor populations and reduce pest numbers.',
        'steps': ['Set traps at dusk near affected crops', 'Inspect daily and record type/count', 'Empty and refresh regularly', 'Use data to time control'],
        'q': [('Main benefit of pest traps?', ['Monitor populations and time control', 'Better than all control', 'Just decoration'], 0, 'Traps show what pests and when.'),
              ('When set traps?', ['At dusk when active', 'Midday only', 'Never work'], 0, 'Many insects active at dusk.'),
              ('Why record catches?', ['Data shows when control needed', 'Just paperwork', 'Irrelevant'], 0, 'Records reveal pest timing.')],
        'video': 'dJGZnX-ZpQY', 'url': 'https://www.ipm.ucdavis.edu/monitoring'
    },
    'extra-047': {
        'title': 'Simple fencing for poultry', 'overview': 'Fencing protects from predators and controls foraging.',
        'steps': ['Use netting 1.5-2 meters high', 'Bury bottom 15 cm to prevent escape', 'Provide sheltered roosting area', 'Check daily for predator damage'],
        'q': [('How high poultry fencing?', ['1.5-2 meters prevent escape', '30 cm enough', 'Height irrelevant'], 0, 'Adequate height prevents escape.'),
              ('Why bury bottom?', ['Prevents predators digging, birds escaping', 'Just cosmetic', 'Wastes materials'], 0, 'Burying prevents underground entry.'),
              ('What inside fence?', ['Sheltered roosting area and water', 'Nothing special', 'Only feed'], 0, 'Birds need weather protection.')],
        'video': 'sY_qCu-KLTo', 'url': 'https://www.extension.org/poultry-fencing'
    },
    'extra-048': {
        'title': 'Record-sharing basics', 'overview': 'Clear reporting builds trust with buyers and partners.',
        'steps': ['Prepare one-page summary', 'Include dates and quantities', 'Attach receipts or photos', 'Send by phone/email/person'],
        'q': [('Why share records?', ['Builds trust, shows transparency', 'Wastes time', 'Not necessary'], 0, 'Transparency builds relationships.'),
              ('What should report include?', ['Key numbers, dates, quantities, evidence', 'Vague estimates', 'No data'], 0, 'Specific numbers more credible.'),
              ('How detailed?', ['One page summary', 'Book-length', 'Only verbal'], 0, 'Concise reports get read.')],
        'video': 'n0Eg8xD2lbM', 'url': 'https://www.fao.org/3/i3161e/i3161e.pdf'
    },
    'extra-049': {
        'title': 'Quick compost checks', 'overview': 'Weekly checks monitor progress and identify readiness.',
        'steps': ['Feel pile temperature from center', 'Check moisture like squeezed sponge', 'Smell for ammonia or dry smell', 'Turn if too cool or wet'],
        'q': [('What does hot pile indicate?', ['Microbes breaking down actively', 'Pile burned', 'No activity'], 0, 'Heat shows microbial activity.'),
              ('Right moisture level?', ['Moist like squeezed sponge', 'Bone dry', 'Soaking wet'], 0, 'This moisture ideal for activity.'),
              ('Ammonia smell indicates?', ['Pile too wet, turn it', 'Pile ready', 'Pile burning'], 0, 'Ammonia shows anaerobic conditions.')],
        'video': 'VF1mALvgD-8', 'url': 'https://www.gardenmyths.com/compost-pile-management/'
    },
    'extra-050': {
        'title': 'Simple herd grouping', 'overview': 'Grouping by age simplifies feeding and improves health monitoring.',
        'steps': ['Separate young from adults', 'Keep different purpose groups separate', 'Tag or mark groups clearly', 'Maintain consistent feed/schedule'],
        'q': [('Why group by age?', ['Similar ages have same feed needs', 'All same', 'Wastes time'], 0, 'Age-specific groups reduce conflict.'),
              ('What separate?', ['Young from adults, different purposes', 'No separation', 'Only by color'], 0, 'Separation prevents bullying.'),
              ('Why label groups?', ['Identify for treatment/feeding', 'Not useful', 'Just look organized'], 0, 'Labels ensure correct animal care.')],
        'video': 'GrJBLnCbSIQ', 'url': 'https://www.extension.org/animal-grouping'
    },
}

def gen(lessonid, data):
    steps = ',\n      '.join(f"'{s}'" for s in data['steps'])
    q_blocks = []
    for i, (prompt, opts, corr, exp) in enumerate(data['q'], 1):
        opts_str = ',\n          '.join(f"'{o}'" for o in opts)
        q_blocks.append(f"""      LessonQuestion(
        id: '{lessonid}-{i}',
        prompt: '{prompt}',
        options: <String>[
          {opts_str}
        ],
        correctOptionIndex: {corr},
        explanation: '{exp}',
      )""")
    q_str = ',\n'.join(q_blocks)
    
    code = f"""  const LearningLesson(
    id: '{lessonid}',
    title: '{data['title']}',
    subtitle: '',
    baseProgress: 0.05,
    duration: '5 min',
    tint: Color(0xFFE8F4D8),
    track: AppStrings.cropAdvice,
    difficulty: 'Practical',
    icon: Icons.eco_rounded,
    imageAsset: AppAssets.uiGallery01,
    overview: '{data['overview']}',
    steps: <String>[
      {steps}
    ],
    questions: <LessonQuestion>[
{q_str}
    ],
    tools: <String>['Tools'],
    youtubeVideoId: '{data['video']}',
    websiteUrl: '{data['url']}',
  ),"""
    return code

if __name__ == '__main__':
    for lid, d in lessons_data.items():
        print(gen(lid, d))
