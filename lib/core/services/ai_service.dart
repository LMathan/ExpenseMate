import 'package:hive/hive.dart';
import '../storage/hive_helper.dart';

class AiService {
  String? _pendingItemName;
  String? _pendingCategory;
  String? _lastItemName;
  String? _lastCategory;
  // Generates customized financial insights cards for the AI dashboard
  List<Map<String, dynamic>> generateInsights() {
    final tBox = Hive.box(HiveHelper.transactionsBox);
    final bBox = Hive.box(HiveHelper.budgetsBox);

    final income = bBox.get('monthly_income', defaultValue: 65000.0) as double;
    
    // Calculate category spending
    double foodSpent = 0;
    double shoppingSpent = 0;
    double totalSpent = 0;

    final now = DateTime.now();
    for (var key in tBox.keys) {
      final tx = Map<String, dynamic>.from(tBox.get(key));
      final dateVal = tx['date'];
      DateTime txDate;
      if (dateVal is DateTime) {
        txDate = dateVal;
      } else if (dateVal is String) {
        txDate = DateTime.tryParse(dateVal) ?? now;
      } else {
        txDate = now;
      }

      if (txDate.month == now.month && txDate.year == now.year) {
        final amt = tx['amount'] as double;
        final cat = tx['category'] as String;
        totalSpent += amt;
        if (cat == 'Food') foodSpent += amt;
        if (cat == 'Shopping') shoppingSpent += amt;
      }
    }

    final savings = income - totalSpent;
    final List<Map<String, dynamic>> insights = [];

    // Insight 1: Food spend warning
    if (foodSpent > 4000) {
      insights.add({
        'title': 'High Food Spending Alert',
        'description': 'You have spent ₹${foodSpent.toStringAsFixed(0)} on food delivery and dining. Reducing online orders by 20% could save you ₹1,500.',
        'type': 'warning',
        'savingPotential': 1500.0,
      });
    }

    // Insight 2: Shopping speed check
    if (shoppingSpent > 3000) {
      insights.add({
        'title': 'Shopping Momentum',
        'description': 'Shopping accounts for ${(shoppingSpent / income * 100).toStringAsFixed(0)}% of your monthly income. Wait 48 hours before your next check-out to avoid impulse buys.',
        'type': 'suggestion',
        'savingPotential': 1200.0,
      });
    }

    // Insight 3: General positive check
    if (savings > income * 0.3) {
      insights.add({
        'title': 'Healthy Savings Rate',
        'description': 'Amazing job! You have saved ₹${savings.toStringAsFixed(0)} (${(savings / income * 100).toStringAsFixed(0)}% of income) so far this month.',
        'type': 'success',
        'savingPotential': 0.0,
      });
    } else {
      insights.add({
        'title': 'Savings Boost Opportunity',
        'description': 'Your current savings rate is below 15%. Directing ₹3,000 into a recurring deposit immediately on payday can automate your savings goals.',
        'type': 'tip',
        'savingPotential': 3000.0,
      });
    }

    return insights;
  }

  // Answers custom questions in natural language, using actual user budget parameters
  String answerFinancialQuery(String query) {
    final tBox = Hive.box(HiveHelper.transactionsBox);
    final bBox = Hive.box(HiveHelper.budgetsBox);
    final settingsBox = Hive.box(HiveHelper.settingsBox);
    final rawName = settingsBox.get('user_name', defaultValue: 'User') as String;
    final userName = rawName.split(' ').first;

    final income = bBox.get('monthly_income', defaultValue: 65000.0) as double;
    final now = DateTime.now();
    double totalSpent = 0;
    for (var key in tBox.keys) {
      final tx = Map<String, dynamic>.from(tBox.get(key));
      final dateVal = tx['date'];
      DateTime txDate;
      if (dateVal is DateTime) {
        txDate = dateVal;
      } else if (dateVal is String) {
        txDate = DateTime.tryParse(dateVal) ?? now;
      } else {
        txDate = now;
      }

      if (txDate.month == now.month && txDate.year == now.year) {
        totalSpent += tx['amount'] as double;
      }
    }

    final balance = income - totalSpent;
    final q = query.toLowerCase();

    // Helper to extract a number from query
    double? extractAmount(String text) {
      final amtMatch = RegExp(r'(\d+[\d,]*\d*)').firstMatch(text);
      if (amtMatch != null) {
        final rawAmt = amtMatch.group(1)?.replaceAll(',', '') ?? '0';
        return double.tryParse(rawAmt);
      }
      return null;
    }

    // Step 1: Detect item category keywords in the user's message
    String? matchedItem;
    String? matchedCategory;

    // Food keywords
    final foodKeywords = ['biriyani', 'biryani', 'pizza', 'coffee', 'starbucks', 'zomato', 'swiggy', 'burger', 'restaurant', 'eat', 'food'];
    // Fashion keywords
    final fashionKeywords = ['shoes', 'sneakers', 'shirt', 'jeans', 'clothes', 'shopping', 'zara', 'hm', 'watch'];
    // Gadgets keywords
    final gadgetKeywords = ['iphone', 'phone', 'airpods', 'ipad', 'laptop', 'macbook', 'gadget', 'samsung', 'playstation', 'ps5', 'xbox'];
    // Entertainment keywords
    final entKeywords = ['movie', 'cinema', 'netflix', 'pub', 'party', 'beer', 'club', 'drinks', 'alcohol', 'hotstar', 'prime'];
    // Travel keywords
    final travelKeywords = ['goa', 'trip', 'vacation', 'travel', 'flight', 'hotel', 'roadtrip'];

    // Helper to match list of keywords in a query
    String? findKeyword(List<String> list) {
      for (var word in list) {
        if (q.contains(word)) return word;
      }
      return null;
    }

    if (findKeyword(foodKeywords) != null) {
      matchedItem = findKeyword(foodKeywords);
      matchedCategory = 'Food';
    } else if (findKeyword(fashionKeywords) != null) {
      matchedItem = findKeyword(fashionKeywords);
      matchedCategory = 'Shopping';
    } else if (findKeyword(gadgetKeywords) != null) {
      matchedItem = findKeyword(gadgetKeywords);
      matchedCategory = 'Shopping';
    } else if (findKeyword(entKeywords) != null) {
      matchedItem = findKeyword(entKeywords);
      matchedCategory = 'Entertainment';
    } else if (findKeyword(travelKeywords) != null) {
      matchedItem = findKeyword(travelKeywords);
      matchedCategory = 'Travel';
    }

    final price = extractAmount(q);

    // Step 2: Handle matching routes
    if (matchedItem != null) {
      if (price != null && price > 0) {
        _lastItemName = matchedItem;
        _lastCategory = matchedCategory;
        _pendingItemName = null;
        _pendingCategory = null;
        return _generateWittyBudgetAnalysis(matchedItem, matchedCategory!, price, balance, income, userName);
      } else {
        _pendingItemName = matchedItem;
        _pendingCategory = matchedCategory;

        final Map<String, String> prompts = {
          'Food': "Mmm, $matchedItem sounds delicious! 🤤 But how much does it cost? Please tell me the price so I can check your budget balance.",
          'Shopping': "Oh, looking to buy a $matchedItem? 🛍️ Nice choice! How much does it cost? Let me check if your wallet approves.",
          'Entertainment': "Going for a $matchedItem? 🍿 Fun! But what's the damage? Tell me the cost so I can check your monthly sheet.",
          'Travel': "A $matchedItem trip? ✈️ Exciting! How much is it going to cost? Give me the budget details so we don't break the bank.",
        };

        return prompts[matchedCategory] ?? "Interesting purchase! How much does it cost? Tell me the price so I can verify your remaining budget.";
      }
    } else if (price != null && price > 0) {
      if (_pendingItemName != null) {
        final itemName = _pendingItemName!;
        final category = _pendingCategory ?? 'Other';
        
        _lastItemName = itemName;
        _lastCategory = category;
        _pendingItemName = null;
        _pendingCategory = null;

        return _generateWittyBudgetAnalysis(itemName, category, price, balance, income, userName);
      } else if (_lastItemName != null) {
        final itemName = _lastItemName!;
        final category = _lastCategory ?? 'Other';
        return _generateWittyBudgetAnalysis(itemName, category, price, balance, income, userName);
      } else {
        return _generateWittyBudgetAnalysis('this purchase', 'Other', price, balance, income, userName);
      }
    }

    // Step 3: Check if they asked general "afford" or "buy" questions with no price
    if (q.contains('afford') || q.contains('buy') || q.contains('cost') || q.contains('price')) {
      return "To give you precise advice on what you can afford, please tell me what you want to buy and its cost (e.g., 'Can I buy a ₹1,200 watch?').";
    }

    // Step 4: How much should I save question
    if (q.contains('save') || q.contains('savings')) {
      final recommendedSavings = income * 0.2;
      return "Based on your monthly income of ₹${income.toStringAsFixed(0)}, following the 50/30/20 rule, you should aim to save at least 20% (₹${recommendedSavings.toStringAsFixed(0)}) every month. Currently, your remaining balance is ₹${balance.toStringAsFixed(0)}. Saving a portion of this in a designated 'Goals' fund is a smart choice.";
    }

    // Step 5: General greetings/help
    return "Hi, I am your ExpenseMate Financial Advisor. I have analyzed your income (₹${income.toStringAsFixed(0)}) and expenses (₹${totalSpent.toStringAsFixed(0)}). You can ask me questions like:\n- 'Can I eat biryani today?'\n- 'Can I buy shoes?'\n- 'Should I buy a bike of ₹1,20,000?'\n- 'Can I go to Goa?'";
  }

  String _generateWittyBudgetAnalysis(String item, String category, double price, double balance, double income, String userName) {
    final itemCapitalized = item[0].toUpperCase() + item.substring(1);
    final consumptionRate = balance > 0 ? (price / balance) * 100 : 100.0;
    final seed = DateTime.now().microsecondsSinceEpoch;

    // Verbs and target mapping
    String verb;
    String verbIng;
    String targetName;
    
    switch (category) {
      case 'Food':
        verb = 'order';
        verbIng = 'ordering';
        targetName = 'this meal';
        break;
      case 'Entertainment':
        verb = 'go for';
        verbIng = 'going for';
        targetName = 'this';
        break;
      case 'Travel':
        verb = 'go on';
        verbIng = 'going on';
        targetName = 'this trip';
        break;
      default:
        verb = 'buy';
        verbIng = 'buying';
        targetName = 'it';
    }

    // Over draft check (Cost > Remaining Balance)
    if (price > balance) {
      if (price > income * 2) {
        return "Whoa! $itemCapitalized costs ₹${price.toStringAsFixed(0)} which is more than 2 months of your gross income (₹${income.toStringAsFixed(0)})! 🚨 Unless this is a critical emergency, spending this much is a financial disaster. Abort immediately! 💸";
      }
      
      final deficit = price - balance;
      List<String> roasts;

      switch (category) {
        case 'Food':
          roasts = [
            "No way! $itemCapitalized costs ₹${price.toStringAsFixed(0)}, but your remaining balance is ₹${balance.toStringAsFixed(0)}. You are short by ₹${deficit.toStringAsFixed(0)}. Zomato and Swiggy are rich enough—go cook some Maggi! 🍜",
            "Error 404: Budget for $item not found! 🚫 Remaining balance is only ₹${balance.toStringAsFixed(0)}. Your wallet says water is also a beverage. Drink that instead! 🚰",
            "Biryani? Pizza? More like boiled rice and regret! 🍚 You are ₹${deficit.toStringAsFixed(0)} short of affording this. Your bank account is requesting a fasting month!",
          ];
          break;
        case 'Entertainment':
          roasts = [
            "Nope! Going for $item costs ₹${price.toStringAsFixed(0)}, but you only have ₹${balance.toStringAsFixed(0)} left. Netflix and chill is free if you borrow your friend's password. Why spend on a ticket? 🍿",
            "Slowing down, superstar! You are ₹${deficit.toStringAsFixed(0)} short for this. The only trip/show you should go for is walking to your balcony and looking at the sky! 🌌",
            "Are you trying to make your wallet cry? 😭 You can't afford ₹${price.toStringAsFixed(0)} right now. Watch some funny finance reels on YouTube for free entertainment!",
          ];
          break;
        case 'Travel':
          roasts = [
            "Goa? A trip? 🏖️ Unless you plan on walking there and sleeping on the beach, your remaining balance of ₹${balance.toStringAsFixed(0)} says 'Stay home and watch travel vlogs!'. You're short by ₹${deficit.toStringAsFixed(0)}.",
            "Vacation denied! ✈️ Cost: ₹${price.toStringAsFixed(0)}, Balance: ₹${balance.toStringAsFixed(0)}. A trip to your local supermarket is the only vacation you can afford this week! 🛒",
            "Your wanderlust is fighting with your bank account, and your bank account is losing badly. You need another ₹${deficit.toStringAsFixed(0)} to make this happen. Stay in bed!",
          ];
          break;
        default: // Shopping, Tech, Shoes, etc.
          roasts = [
            "No way! $itemCapitalized costs ₹${price.toStringAsFixed(0)}, but your remaining balance is ₹${balance.toStringAsFixed(0)}. You are short by ₹${deficit.toStringAsFixed(0)}. Window shopping is free, stick to that! 🛍️",
            "Zara? H&M? New gadgets? 📱 Your bank account says you belong to the local bazaar right now. Let's wait until next month!",
            "Warning: Insufficient brain funds detected! 🧠 Buying a ₹${price.toStringAsFixed(0)} $item when you only have ₹${balance.toStringAsFixed(0)} is how you end up begging your friends for a split-bill loan. Please don't.",
          ];
      }

      return roasts[seed % roasts.length];
    }

    // Critically low balance warning (balance - price < 5% of monthly income)
    final remainingPercent = (balance - price) / income;
    if (remainingPercent < 0.05) {
      final warnings = [
        "Technically, you have ₹${balance.toStringAsFixed(0)} left, so you *can* $verb the ₹${price.toStringAsFixed(0)} $item. But doing so leaves you with less than 5% of your income for emergencies. ⚠️ Prepare to survive on instant noodles and pure willpower for the rest of the month!",
        "Yes, you have the cash, but you'll be living on the edge of financial breakdown! 📉 Doing this leaves you with almost nothing. If your car breaks down or you lose your keys, you'll be in trouble. Think twice!",
        "Warning: Wallet on life support! 🚨 $itemCapitalized is affordable, but it wipes out your safety buffer. Unless this is an emergency, let's keep that ₹${balance.toStringAsFixed(0)} intact.",
      ];
      return warnings[seed % warnings.length];
    }

    // High price consumption (costs > 35% of remaining balance)
    if (consumptionRate > 35.0) {
      final cautions = [
        "$itemCapitalized costs ₹${price.toStringAsFixed(0)}, which consumes ${consumptionRate.toStringAsFixed(0)}% of your remaining balance (₹${balance.toStringAsFixed(0)}). 💸 This is a massive blow to your monthly cash flow. I highly suggest sleeping on it for 48 hours. If you still want it then, cut back on other expenses!",
        "Wait! 🛑 That's ${consumptionRate.toStringAsFixed(0)}% of all the money you have left! Spend this and you'll have to cancel all other fun activities this month. Are you sure this $item is worth that sacrifice?",
        "Ouch! That ₹${price.toStringAsFixed(0)} is going to make a huge dent in your remaining balance. Let's hold off or find a cheaper alternative. Don't make impulsive decisions!",
      ];
      return cautions[seed % cautions.length];
    }

    // Safe purchase (healthy balance)
    List<String> successStories;
    switch (category) {
      case 'Food':
        successStories = [
          "Go ahead, $verb $targetName! 🎉 At ₹${price.toStringAsFixed(0)}, it consumes only ${consumptionRate.toStringAsFixed(0)}% of your remaining balance (₹${balance.toStringAsFixed(0)}). Treat yourself and satisfy your cravings! 🍕",
          "Approved! 🤤 Your wallet is giving you a green light. Go order that delicious food and enjoy it guilt-free!",
          "Yes! You managed your budget beautifully this month, so you've earned this meal. Enjoy every bite! 🍔",
        ];
        break;
      case 'Entertainment':
        successStories = [
          "Approved! 🍿 Going for this costs ₹${price.toStringAsFixed(0)}, which is a tiny drop in your remaining balance (₹${balance.toStringAsFixed(0)}). Go and enjoy yourself!",
          "Go for it! 🎉 Your budget is healthy, and a little entertainment is well deserved. Have fun!",
          "Guilt-free green light! 🎬 You have plenty of balance left, so go enjoy this experience without looking back!",
        ];
        break;
      case 'Travel':
        successStories = [
          "Approved! ✈️ At ₹${price.toStringAsFixed(0)}, you can easily afford $targetName. Pack your bags, enjoy your travel, and make some memories! 🧳",
          "Yes! Your savings rate is healthy, and this trip is fully funded. Go explore and have a great time! 🏖️",
          "Wanderlust approved! 🗺️ Spending ₹${price.toStringAsFixed(0)} won't hurt your finances at all. Have a safe and happy trip!",
        ];
        break;
      default:
        successStories = [
          "Go ahead, $verb $targetName! 🛍️ At ₹${price.toStringAsFixed(0)}, it consumes only ${consumptionRate.toStringAsFixed(0)}% of your remaining balance (₹${balance.toStringAsFixed(0)}). Go reward yourself! 🏆",
          "Approved! You have saved enough to buy this $item easily. Go ahead and get it!",
          "Green light! 🟢 Your budget is in top shape. Buy this guilt-free—you've earned it!",
        ];
    }

    return successStories[seed % successStories.length];
  }
}
