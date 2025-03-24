// MARK: - SearchHistoryView.swift
import SwiftUI

struct SearchHistoryView: View {
    @EnvironmentObject var searchManager: SearchManager
    @Environment(\.presentationMode) var presentationMode
    
    let onSelectItem: (String) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(searchManager.searchHistory, id: \.self) { item in
                    Button(action: {
                        onSelectItem(item)
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                            
                            Text(item)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        searchManager.clearSearchHistory()
                    }) {
                        Text("Clear")
                            .foregroundColor(.red)
                    }
                    .disabled(searchManager.searchHistory.isEmpty)
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        var history = searchManager.searchHistory
        history.remove(atOffsets: offsets)
        searchManager.searchHistory = history
        UserDefaults.standard.set(history, forKey: "search_history")
    }
}
