/**
 * Curated "did you know" facts for the daily digest notification.
 *
 * Each `lessonId` MUST match a real id in the Flutter app's
 * `_learningLessons` list (lib/presentation/screens/learn/learn_screen.dart)
 * so tapping the notification opens a real lesson via `/learn/lesson/:id`.
 * Verified against that file before adding an entry here.
 */

export type FunFactCategory = "crop" | "livestock" | "general";

export interface FunFact {
  fact: string;
  lessonId: string;
  category: FunFactCategory;
}

export const FUN_FACTS: FunFact[] = [
  {
    fact: "Checking topsoil moisture first thing in the morning — before the sun warms it — gives the most accurate read on whether a field actually needs water today.",
    lessonId: "soil-moisture",
    category: "crop",
  },
  {
    fact: "A thin layer of mulch over exposed beds can noticeably slow surface drying between waterings, stretching the time between irrigation rounds.",
    lessonId: "soil-moisture",
    category: "crop",
  },
  {
    fact: "Spotting pest pressure early — before it spreads across beds — is far cheaper than treating an infestation that's already taken hold.",
    lessonId: "crop-pest-scouting",
    category: "crop",
  },
  {
    fact: "A short pest-scouting walk through your crop rows a few times a week catches problems while they're still small and easy to manage.",
    lessonId: "crop-pest-scouting",
    category: "crop",
  },
  {
    fact: "A simple dated vaccine calendar is one of the most reliable ways to avoid missed doses across a livestock group.",
    lessonId: "livestock-vaccination",
    category: "livestock",
  },
  {
    fact: "Logging reactions, missed doses, and next steps right after a vaccination event makes follow-up far easier later.",
    lessonId: "livestock-vaccination",
    category: "livestock",
  },
  {
    fact: "A steady feeding and watering routine — same times, same amounts — keeps livestock healthier than irregular feeding.",
    lessonId: "feeding-and-grazing",
    category: "livestock",
  },
  {
    fact: "Consistent grazing and feed timing reduces stress on animals, which shows up in better growth and health over time.",
    lessonId: "feeding-and-grazing",
    category: "livestock",
  },
  {
    fact: "Sometimes holding produce a little longer instead of selling immediately can mean a noticeably better price at market.",
    lessonId: "market-timing",
    category: "general",
  },
  {
    fact: "Reading market timing well — knowing when to sell and when to hold stock — is a skill that pays off as much as the harvest itself.",
    lessonId: "market-timing",
    category: "general",
  },
  {
    fact: "Using rain, temperature, and humidity forecasts to plan farm tasks ahead of time helps avoid wasted work on bad-weather days.",
    lessonId: "weather-work-plan",
    category: "general",
  },
  {
    fact: "A quick look at the week's weather outlook before scheduling spraying, harvesting, or transport can save a lot of rework.",
    lessonId: "weather-work-plan",
    category: "general",
  },
  {
    fact: "Careful post-harvest handling keeps produce fresher for longer between the field and the buyer, protecting the value of your harvest.",
    lessonId: "post-harvest-handling",
    category: "general",
  },
  {
    fact: "Simple farm record keeping — income, expenses, and yields — often makes the difference when applying for finance or credit later.",
    lessonId: "record-keeping",
    category: "general",
  },
  {
    fact: "Keeping a basic log of what was planted, spent, and sold turns guesswork into real decisions for next season.",
    lessonId: "record-keeping",
    category: "general",
  },
  {
    fact: "Mixing composted manure or crop residue back into the soil before planting rebuilds nutrients the last harvest pulled out, cutting how much fertilizer you need to buy.",
    lessonId: "soil-fertility-compost",
    category: "crop",
  },
  {
    fact: "A handful of soil that crumbles and smells earthy usually has healthier microbial life than soil that's hard, pale, and odorless — a quick fertility check before you even test it.",
    lessonId: "soil-fertility-compost",
    category: "crop",
  },
  {
    fact: "Seedlings raised in a shaded, well-watered nursery bed transplant with far less shock than seed sown directly into a hot, exposed field.",
    lessonId: "seedling-nursery-management",
    category: "crop",
  },
  {
    fact: "Hardening off seedlings — gradually cutting back water and shade a few days before transplanting — toughens them up so fewer die in the first week outside.",
    lessonId: "seedling-nursery-management",
    category: "crop",
  },
  {
    fact: "A simple foot-dip or boot-wash station at the pen entrance is one of the cheapest ways to stop disease hitching a ride in on visitors' shoes.",
    lessonId: "farm-biosecurity",
    category: "livestock",
  },
  {
    fact: "New animals kept separate from the main herd for a short quarantine period give any hidden illness time to show up before it spreads to the whole group.",
    lessonId: "farm-biosecurity",
    category: "livestock",
  },
  {
    fact: "Drip lines deliver water straight to the root zone, so far less is lost to evaporation or runoff compared to flooding a whole bed.",
    lessonId: "drip-irrigation",
    category: "crop",
  },
  {
    fact: "Watering a little and often through drip lines keeps soil moisture steady, which many crops respond to better than a big soak followed by a dry stretch.",
    lessonId: "drip-irrigation",
    category: "crop",
  },
  {
    fact: "Good cross-ventilation in a poultry house keeps ammonia buildup down, which protects birds' lungs and keeps growth rates up.",
    lessonId: "poultry-housing",
    category: "livestock",
  },
  {
    fact: "Keeping litter dry inside the coop is one of the simplest ways to cut down on the bacteria and parasites that cause flock health problems.",
    lessonId: "poultry-housing",
    category: "livestock",
  },
  {
    fact: "Knowing your true cost per unit — inputs, labour, and transport included — stops a busy market day from quietly turning into a loss.",
    lessonId: "pricing-and-margin",
    category: "general",
  },
  {
    fact: "Tracking which products actually turn the best profit, not just the ones that sell the most, helps decide what to plant or raise more of next season.",
    lessonId: "pricing-and-margin",
    category: "general",
  },
  {
    fact: "Pushing a finger or stick a few centimetres into the soil tells you far more than the surface look — the top layer can appear dry while there's still enough moisture just below for roots to use.",
    lessonId: "soil-moisture",
    category: "crop",
  },
  {
    fact: "Checking the underside of leaves during a scouting walk catches many pests and eggs that are invisible from a normal top-down glance.",
    lessonId: "crop-pest-scouting",
    category: "crop",
  },
  {
    fact: "Storing vaccines at the right temperature on the way from the shop to the farm matters as much as the injection itself — a broken cold chain can quietly make a dose ineffective.",
    lessonId: "livestock-vaccination",
    category: "livestock",
  },
  {
    fact: "Clean, fresh water available at all times often has a bigger effect on animal growth than a slightly richer feed ration.",
    lessonId: "feeding-and-grazing",
    category: "livestock",
  },
  {
    fact: "Checking prices at more than one nearby market before selling can reveal a gap worth the extra trip, especially for produce that travels well.",
    lessonId: "market-timing",
    category: "general",
  },
  {
    fact: "Spraying pesticide or fertilizer right before a heavy rain often washes most of it away before it can work — checking the short-term forecast first saves the input cost.",
    lessonId: "weather-work-plan",
    category: "general",
  },
  {
    fact: "Sorting out bruised or damaged produce immediately after harvest keeps it from spreading spoilage to the healthy produce packed around it.",
    lessonId: "post-harvest-handling",
    category: "general",
  },
  {
    fact: "Recording the exact date of each farm activity, not just what was done, makes it possible to compare this season's timing against last season's results.",
    lessonId: "record-keeping",
    category: "general",
  },
  {
    fact: "Turning a compost heap every couple of weeks brings air to the center, which speeds up decomposition and produces usable compost much sooner.",
    lessonId: "soil-fertility-compost",
    category: "crop",
  },
  {
    fact: "Spacing seedlings a little further apart in the nursery bed, even if it takes more trays, grows stockier plants than crowding them in tight.",
    lessonId: "seedling-nursery-management",
    category: "crop",
  },
  {
    fact: "Cleaning and disinfecting feeding and watering equipment between uses is one of the easiest disease-prevention habits to skip — and one of the most costly to skip.",
    lessonId: "farm-biosecurity",
    category: "livestock",
  },
  {
    fact: "Checking drip lines regularly for clogged emitters catches uneven watering early, before some plants show stress from missing water while others get too much.",
    lessonId: "drip-irrigation",
    category: "crop",
  },
  {
    fact: "Giving each bird enough floor space to move freely reduces feather-pecking and stress-related health problems in the flock.",
    lessonId: "poultry-housing",
    category: "livestock",
  },
  {
    fact: "Separating fixed costs like land and equipment from variable costs like seed and feed makes it much easier to see which farm activities are actually profitable.",
    lessonId: "pricing-and-margin",
    category: "general",
  },
];

export function pickRandomFunFact(category: FunFactCategory): FunFact {
  const inCategory = FUN_FACTS.filter((entry) => entry.category === category);
  const pool = inCategory.length > 0 ? inCategory : FUN_FACTS;
  return pool[Math.floor(Math.random() * pool.length)];
}
