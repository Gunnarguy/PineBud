// MARK: - SourceRow.swift
import SwiftUI

struct SourceRow: View {
    let source: SourceResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                
                Text(source.source)
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.2f", source.score))
                    .font(.caption)
                    .padding(4)
                    .background(scoreColor.opacity(0.2))
                    .foregroundColor(scoreColor)
                    .cornerRadius(4)
            }
            
            Text(source.text.prefix(150))
                .font(.body)
                .lineLimit(3)
            
            if source.text.count > 150 {
                Text("Tap to view more...")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var scoreColor: Color {
        if source.score > 0.8 {
            return .green
        } else if source.score > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

