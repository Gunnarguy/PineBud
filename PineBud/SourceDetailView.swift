// MARK: - SourceDetailView.swift
import SwiftUI

struct SourceDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let source: SourceResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Source header
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(source.source)
                            .font(.headline)
                        
                        Text("Relevance Score: \(String(format: "%.2f", source.score))")
                            .font(.subheadline)
                            .foregroundColor(scoreColor)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                // Source content
                Text(source.text)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Source Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
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


