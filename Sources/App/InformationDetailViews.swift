import SwiftUI

// MARK: - Information Detail Views
struct UserGuideDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("User Guide")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Getting Started")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Welcome to ProteinApp! This guide will help you navigate through the app and make the most of its features.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "atom", title: "3D Protein Visualization", description: "View protein structures in interactive 3D")
                        FeatureRow(icon: "chart.bar", title: "Analysis Tools", description: "Analyze protein properties and characteristics")
                        FeatureRow(icon: "books.vertical", title: "Protein Library", description: "Browse and search protein databases")
                        FeatureRow(icon: "gear", title: "Customization", description: "Customize viewing options and preferences")
                    }
                }
                .padding()
            }
        }
    }
}

struct FeaturesDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Core Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "atom", title: "3D Visualization", description: "Interactive 3D protein structure viewing")
                        FeatureRow(icon: "chart.bar", title: "Data Analysis", description: "Comprehensive protein analysis tools")
                        FeatureRow(icon: "books.vertical", title: "Protein Database", description: "Access to extensive protein libraries")
                        FeatureRow(icon: "gear", title: "Customization", description: "Personalize your viewing experience")
                    }
                }
                .padding()
            }
        }
    }
}

struct HelpDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Help & Support")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Frequently Asked Questions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HelpRow(question: "How do I load a protein?", answer: "Use the Library menu to browse and select proteins from the database.")
                        HelpRow(question: "How do I rotate the 3D view?", answer: "Use touch gestures to rotate, zoom, and pan the 3D protein structure.")
                        HelpRow(question: "Can I change the visualization style?", answer: "Yes, use the Style and Color options in the Protein Viewer.")
                        HelpRow(question: "How do I analyze protein properties?", answer: "Select different tabs like Chains, Residues, and Ligands for detailed analysis.")
                    }
                }
                .padding()
            }
        }
    }
}

struct PrivacyDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Collection")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("ProteinApp respects your privacy. We do not collect personal information or protein data without your explicit consent.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Data Usage")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    Text("Any data you choose to share is used solely for the purpose of providing protein analysis services and improving the app experience.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

struct TermsDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Usage Terms")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("By using ProteinApp, you agree to use the application for educational and research purposes only.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Limitations")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    Text("The app is provided as-is without warranty. Users are responsible for the accuracy of their analysis results.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

struct LicenseDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("License Information")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Open Source Components")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("ProteinApp uses various open source libraries and frameworks. All components are properly licensed and attributed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("Attributions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• SwiftUI Framework")
                        Text("• SceneKit Framework")
                        Text("• Protein Data Bank")
                        Text("• Various open source libraries")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HelpRow: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
                .fontWeight(.medium)
            
            Text(answer)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
