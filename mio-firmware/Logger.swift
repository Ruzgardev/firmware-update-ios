//
//  Logger.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import Foundation
import SwiftUI

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let category: String
    
    var formattedMessage: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] [\(level.rawValue)] [\(category)] \(message)"
    }
}

// MARK: - Logger
class Logger: ObservableObject {
    static let shared = Logger()
    
    @Published var logs: [LogEntry] = []
    @Published var isLoggingEnabled = true
    
    private let maxLogs = 1000
    
    private init() {}
    
    // MARK: - Public Methods
    
    func debug(_ message: String, category: String = "General") {
        log(level: .debug, message: message, category: category)
    }
    
    func info(_ message: String, category: String = "General") {
        log(level: .info, message: message, category: category)
    }
    
    func warning(_ message: String, category: String = "General") {
        log(level: .warning, message: message, category: category)
    }
    
    func error(_ message: String, category: String = "General") {
        log(level: .error, message: message, category: category)
    }
    
    // MARK: - Bluetooth Specific Logs
    
    func bluetooth(_ message: String, level: LogLevel = .info) {
        log(level: level, message: message, category: "Bluetooth")
    }
    
    func firmware(_ message: String, level: LogLevel = .info) {
        log(level: level, message: message, category: "Firmware")
    }
    
    func connection(_ message: String, level: LogLevel = .info) {
        log(level: level, message: message, category: "Connection")
    }
    
    // MARK: - Private Methods
    
    private func log(level: LogLevel, message: String, category: String) {
        guard isLoggingEnabled else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category
        )
        
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            
            // Limit log count
            if self.logs.count > self.maxLogs {
                self.logs = Array(self.logs.prefix(self.maxLogs))
            }
        }
        
        // Console output
        print(entry.formattedMessage)
    }
    
    // MARK: - Utility Methods
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
    
    func exportLogs() -> String {
        return logs.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    func getLogsByCategory(_ category: String) -> [LogEntry] {
        return logs.filter { $0.category == category }
    }
    
    func getLogsByLevel(_ level: LogLevel) -> [LogEntry] {
        return logs.filter { $0.level == level }
    }
}

// MARK: - Log View
struct LogView: View {
    @ObservedObject private var logger = Logger.shared
    @State private var selectedCategory = "All"
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText = ""
    
    private var categories: [String] {
        let allCategories = Set(logger.logs.map { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }
    
    private var filteredLogs: [LogEntry] {
        var filtered = logger.logs
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by level
        if let level = selectedLevel {
            filtered = filtered.filter { $0.level == level }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                filterView
                
                // Logs
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLogs) { log in
                            LogRowView(log: log)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Temizle") {
                        logger.clearLogs()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportLogs()
                    }
                }
            }
        }
    }
    
    private var filterView: some View {
        VStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Log ara...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Category and Level filters
            HStack {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                // Level picker
                Picker("Level", selection: $selectedLevel) {
                    Text("All Levels").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level as LogLevel?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private func exportLogs() {
        let logsText = logger.exportLogs()
        let activityVC = UIActivityViewController(activityItems: [logsText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Log Row View
struct LogRowView: View {
    let log: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            Circle()
                .fill(log.level.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                // Timestamp and category
                HStack {
                    Text(log.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("[\(log.category)]")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(.systemGray5))
                        .cornerRadius(3)
                    
                    Spacer()
                }
                
                // Message
                Text(log.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LogView()
}

