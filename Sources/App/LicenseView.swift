import SwiftUI

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MIT 라이센스 헤더
                VStack(alignment: .leading, spacing: 12) {
                    Text("MIT License")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Copyright (c) 2024 ProteinApp")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 라이센스 본문
                VStack(alignment: .leading, spacing: 16) {
                    Text("Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                // 오픈소스 라이브러리
                VStack(alignment: .leading, spacing: 16) {
                    Text("Open Source Libraries")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        LibraryItem(
                            name: "SceneKit",
                            description: "Apple's 3D graphics framework",
                            license: "Apple License"
                        )
                        
                        LibraryItem(
                            name: "SwiftUI",
                            description: "Apple's declarative UI framework",
                            license: "Apple License"
                        )
                        
                        LibraryItem(
                            name: "PDB Database",
                            description: "Protein Data Bank public data",
                            license: "Public Domain"
                        )
                    }
                }
                
                Divider()
                
                // 연락처 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contact Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ContactItem(
                            icon: "envelope",
                            title: "Email",
                            value: "support@proteinapp.com"
                        )
                        
                        ContactItem(
                            icon: "globe",
                            title: "Website",
                            value: "https://proteinapp.com"
                        )
                        
                        ContactItem(
                            icon: "github",
                            title: "GitHub",
                            value: "https://github.com/proteinapp"
                        )
                    }
                }
                
                Divider()
                
                // 앱 정보
                VStack(alignment: .leading, spacing: 8) {
                    Text("App Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        LicenseInfoRow(title: "Version", value: "1.0.0", description: "Current app version")
                        LicenseInfoRow(title: "Build", value: "1.0.1", description: "Build number")
                        LicenseInfoRow(title: "Platform", value: "iOS 15.6+", description: "Minimum supported iOS version")
                        LicenseInfoRow(title: "Last Updated", value: "December 2024", description: "Last update date")
                    }
                }
            }
            .padding()
        }
    }
}

struct LibraryItem: View {
    let name: String
    let description: String
    let license: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(license)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ContactItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct LicenseInfoRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
