import SwiftUI
import SwiftData
import Charts

struct RevenueTrendChart: View {
    let transactions: [Transaction]
    
    var groupedData: [(Date, Decimal)] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.timestamp)
        }
        let dailyAmounts = grouped.map { date, transactions in
            (date, transactions.reduce(0, { $0 + $1.amount }))
        }
        return dailyAmounts.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Daily Revenue")
                .font(.headline)
            
            let chartContent = Chart {
                ForEach(groupedData, id: \.0) { date, amount in
                    // Line chart
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Amount", amount)
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // Area under the line
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Amount", amount)
                    )
                    .foregroundStyle(.green.opacity(0.1))
                }
            }
            
            chartContent
                .chartYAxis {
                    AxisMarks { value in
                        let amount = value.as(Decimal.self) ?? 0
                        AxisValueLabel {
                            Text(amount.formatted(.currency(code: "XCD")))
                        }
                    }
                }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
} 