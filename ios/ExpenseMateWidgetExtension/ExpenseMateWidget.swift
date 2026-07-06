import WidgetKit
import SwiftUI

struct WidgetEntry: TimelineEntry {
    let date: Date
    let thisMonthSpend: String
    let youGet: String
    let youOwe: String
    let budgetLeft: String
    let budgetLimit: String
    let expensesToday: String
    let topCategory: String
    let monthName: String
    let hasBudget: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            thisMonthSpend: "₹4,520",
            youGet: "₹850",
            youOwe: "₹250",
            budgetLeft: "₹15,480",
            budgetLimit: "₹20,000",
            expensesToday: "3",
            topCategory: "Food",
            monthName: "June",
            hasBudget: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let defaults = UserDefaults(suiteName: "group.com.mathan.espenseai")
        let entry = WidgetEntry(
            date: Date(),
            thisMonthSpend: defaults?.string(forKey: "thisMonthSpend") ?? "₹0",
            youGet: defaults?.string(forKey: "youGet") ?? "₹0",
            youOwe: defaults?.string(forKey: "youOwe") ?? "₹0",
            budgetLeft: defaults?.string(forKey: "budgetLeft") ?? "₹0",
            budgetLimit: defaults?.string(forKey: "budgetLimit") ?? "₹0",
            expensesToday: defaults?.string(forKey: "expensesToday") ?? "0",
            topCategory: defaults?.string(forKey: "topCategory") ?? "None",
            monthName: defaults?.string(forKey: "monthName") ?? "This Month",
            hasBudget: defaults?.bool(forKey: "hasBudget") ?? false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: "group.com.mathan.espenseai")
        let entry = WidgetEntry(
            date: Date(),
            thisMonthSpend: defaults?.string(forKey: "thisMonthSpend") ?? "₹0",
            youGet: defaults?.string(forKey: "youGet") ?? "₹0",
            youOwe: defaults?.string(forKey: "youOwe") ?? "₹0",
            budgetLeft: defaults?.string(forKey: "budgetLeft") ?? "₹0",
            budgetLimit: defaults?.string(forKey: "budgetLimit") ?? "₹0",
            expensesToday: defaults?.string(forKey: "expensesToday") ?? "0",
            topCategory: defaults?.string(forKey: "topCategory") ?? "None",
            monthName: defaults?.string(forKey: "monthName") ?? "This Month",
            hasBudget: defaults?.bool(forKey: "hasBudget") ?? false
        )
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This Month")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
            
            Text(entry.thisMonthSpend)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Get \(entry.youGet)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.green)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("Owe \(entry.youOwe)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.red)
                }
            }
            
            if entry.hasBudget {
                Spacer(minLength: 0)
                Text("Left: \(entry.budgetLeft)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.04, blue: 0.11), Color(red: 0.09, green: 0.08, blue: 0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Dashboard Section
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("💸 ExpenseMate")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.73, green: 0.53, blue: 0.99)) // BB86FC equivalent
                    
                    Text("This Month Spend")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
                        .padding(.top, 2)
                    
                    Text(entry.thisMonthSpend)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Get \(entry.youGet)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.green)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                    
                    HStack(spacing: 4) {
                        Text("Owe \(entry.youOwe)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.red)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                    
                    if entry.hasBudget {
                        Text("Left: \(entry.budgetLeft)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.bottom, 8)
            
            Spacer()
            
            // Bottom Quick Actions
            HStack(spacing: 8) {
                Link(destination: URL(string: "expensemate://add_expense")!) {
                    HStack {
                        Text("➕ Add Expense")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Link(destination: URL(string: "expensemate://splits")!) {
                    HStack {
                        Text("👥 Splits")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .frame(height: 32)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.04, blue: 0.11), Color(red: 0.09, green: 0.08, blue: 0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack {
                Text("💸 ExpenseMate")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.73, green: 0.53, blue: 0.99))
                Spacer()
                Text(entry.monthName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
            }
            .padding(.bottom, 6)
            
            // Spend & Splits Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Month Spend")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
                    Text(entry.thisMonthSpend)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Get \(entry.youGet)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.green)
                    Text("Owe \(entry.youOwe)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.red)
                }
            }
            .padding(.bottom, 6)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.bottom, 6)
            
            // Budget Block (Visible only if hasBudget is true)
            if entry.hasBudget {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Budget Remaining")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
                        Spacer()
                        Text("Limit: \(entry.budgetLimit)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
                    }
                    Text("\(entry.budgetLeft) left")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.bottom, 6)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.bottom, 6)
            }
            
            // Daily Summary & Top Category Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Count")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
                    Text("\(entry.expensesToday) txn")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Top Category")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.69))
                    Text(entry.topCategory)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.25, green: 0.77, blue: 1.0))
                }
            }
            
            Spacer()
            
            // Bottom Action buttons (Link views)
            HStack(spacing: 8) {
                Link(destination: URL(string: "expensemate://add_expense")!) {
                    HStack {
                        Text("➕ Add")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Link(destination: URL(string: "expensemate://splits")!) {
                    HStack {
                        Text("👥 Splits")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Link(destination: URL(string: "expensemate://dashboard")!) {
                    HStack {
                        Text("📊 Dashboard")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .frame(height: 32)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.04, blue: 0.11), Color(red: 0.09, green: 0.08, blue: 0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct ExpenseMateWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

@main
struct ExpenseMateWidget: Widget {
    let kind: String = "ExpenseMateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ExpenseMateWidgetView(entry: entry)
        }
        .configurationDisplayName("ExpenseMate Widget")
        .description("Keep track of your monthly spend, get/owe splits, and budget status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
