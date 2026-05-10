/// Application string constants for FarmSync Jos South.
/// All user-facing text should be referenced from this file for consistency
/// and to support future internationalization.
abstract final class AppStrings {
  // Navigation
  static const String home = 'Home';
  static const String farms = 'Farms';
  static const String crops = 'Crops';
  static const String livestock = 'Livestock';
  static const String finance = 'Finance';
  static const String profile = 'Profile';

  // Sync Status
  static const String syncStatusSynced = 'Synced';
  static const String syncStatusPending = 'Pending';
  static const String syncStatusOffline = 'Offline';

  // Common Actions
  static const String openMenu = 'Open menu';
  static const String add = 'Add';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String ok = 'OK';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String previous = 'Previous';
  static const String done = 'Done';
  static const String close = 'Close';

  // Farmer Categories
  static const String subsistenceFarmer = 'Subsistence';
  static const String semiCommercialFarmer = 'Semi-Commercial';
  static const String marketOrientedFarmer = 'Market-Oriented';

  // Dashboard
  static const String goodMorning = 'Good morning';
  static const String goodAfternoon = 'Good afternoon';
  static const String goodEvening = 'Good evening';
  static const String welcomeBack = 'Welcome back';
  static const String totalFarms = 'Total Farms';
  static const String totalCrops = 'Total Crops';
  static const String totalLivestock = 'Total Livestock';
  static const String monthlyBalance = 'Monthly Balance';
  static const String quickActions = 'Quick Actions';
  static const String recentActivity = 'Recent Activity';
  static const String weather = 'Weather';
  static const String temperature = 'Temperature';
  static const String humidity = 'Humidity';
  static const String rainfall = 'Rainfall';

  // Farms
  static const String addFarm = 'Add Farm';
  static const String farmName = 'Farm Name';
  static const String farmLocation = 'Location';
  static const String farmSize = 'Farm Size (ha)';
  static const String soilType = 'Soil Type';
  static const String waterSource = 'Water Source';
  static const String farmerCategory = 'Farmer Category';
  static const String noFarmsYet = 'No farms added yet';
  static const String addYourFirstFarm = 'Add your first farm to get started';

  // Crops
  static const String addCrop = 'Add Crop';
  static const String cropName = 'Crop Name';
  static const String cropVariety = 'Variety';
  static const String plantingDate = 'Planting Date';
  static const String expectedHarvest = 'Expected Harvest';
  static const String areaPlanted = 'Area Planted (ha)';
  static const String currentStage = 'Current Stage';
  static const String growthStages = 'Growth Stages';
  static const String seeding = 'Seeding';
  static const String germination = 'Germination';
  static const String vegetative = 'Vegetative';
  static const String flowering = 'Flowering';
  static const String fruiting = 'Fruiting';
  static const String noCropsYet = 'No crops planted yet';
  static const String plantYourFirstCrop = 'Plant your first crop to track growth';

  // Livestock
  static const String addLivestock = 'Add Livestock';
  static const String species = 'Species';
  static const String breed = 'Breed';
  static const String count = 'Count';
  static const String maleCount = 'Male Count';
  static const String femaleCount = 'Female Count';
  static const String purpose = 'Purpose';
  static const String housing = 'Housing';
  static const String healthStatus = 'Health Status';
  static const String vaccination = 'Vaccination';
  static const String treatment = 'Treatment';
  static const String checkup = 'Checkup';
  static const String birth = 'Birth';
  static const String death = 'Death';
  static const String noLivestockYet = 'No livestock added yet';
  static const String addYourFirstAnimal = 'Add your first animal to monitor health';

  // Finance
  static const String addTransaction = 'Add Transaction';
  static const String income = 'Income';
  static const String expense = 'Expense';
  static const String category = 'Category';
  static const String amount = 'Amount';
  static const String description = 'Description';
  static const String date = 'Date';
  static const String balance = 'Balance';
  static const String totalIncome = 'Total Income';
  static const String totalExpenses = 'Total Expenses';
  static const String cropSales = 'Crop Sales';
  static const String livestockSales = 'Livestock Sales';
  static const String inputs = 'Inputs';
  static const String labour = 'Labour';
  static const String veterinary = 'Veterinary';
  static const String other = 'Other';
  static const String noTransactionsYet = 'No transactions recorded yet';
  static const String recordYourFirstTransaction = 'Record your first transaction to track finances';

  // AI Advisor
  static const String askAI = 'Ask AI';
  static const String cropAdvice = 'Crop Advice';
  static const String animalHealth = 'Animal Health';
  static const String soilManagement = 'Soil Management';
  static const String marketPrices = 'Market Prices';
  static const String learn = 'Learn';
  static const String weatherForecast = 'Weather Forecast';
  static const String snapAndDiagnose = 'Snap & Diagnose';
  static const String takePhoto = 'Take Photo';
  static const String uploadImage = 'Upload Image';
  static const String typeYourQuestion = 'Type your question...';
  static const String send = 'Send';

  // Learn
  static const String continueLearning = 'Continue Learning';
  static const String lessons = 'Lessons';
  static const String progress = 'Progress';
  static const String completed = 'Completed';

  // Profile
  static const String farmerName = 'Farmer Name';
  static const String phoneNumber = 'Phone Number';
  static const String ward = 'Ward';
  static const String language = 'Language';
  static const String english = 'English';
  static const String hausa = 'Hausa';
  static const String berom = 'Berom';
  static const String theme = 'Theme';
  static const String lightMode = 'Light Mode';
  static const String darkMode = 'Dark Mode';
  static const String voiceMode = 'Voice Mode';
  static const String exportReport = 'Export Report';
  static const String settings = 'Settings';
  static const String logout = 'Logout';
  static const String version = 'Version';

  // Validation Messages
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String invalidAmount = 'Please enter a valid amount';
  static const String invalidDate = 'Please enter a valid date';

  // Error Messages
  static const String somethingWentWrong = 'Something went wrong';
  static const String noInternetConnection = 'No internet connection';
  static const String failedToLoad = 'Failed to load data';
  static const String failedToSave = 'Failed to save data';

  // Success Messages
  static const String savedSuccessfully = 'Saved successfully';
  static const String deletedSuccessfully = 'Deleted successfully';
  static const String exportedSuccessfully = 'Exported successfully';

  // Loading
  static const String loading = 'Loading...';
  static const String saving = 'Saving...';
  static const String deleting = 'Deleting...';
}
