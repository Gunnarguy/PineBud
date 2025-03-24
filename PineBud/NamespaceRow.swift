// MARK: - NamespaceRow.swift
import SwiftUI

struct NamespaceRow: View {
    let name: String
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(isActive ? .blue : .gray)
                
                Text(name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isActive ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}
