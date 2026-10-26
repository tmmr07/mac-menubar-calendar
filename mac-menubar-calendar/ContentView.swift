import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = GoogleAuthManager()
    
    var body: some View {
        VStack {
            if authManager.isAuthenticated {
                VStack {
                    HStack {
                        Text("直近の予定")
                            .font(.headline)
                        Spacer()
                        
                        // 【追加】ログアウトボタン
                        Button(action: {
                            authManager.logout()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .help("ログアウト")
                        
                        Button(action: {
                            authManager.fetchCalendarEvents()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("更新")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    List(authManager.events) { event in
                        VStack(alignment: .leading) {
                            Text(event.summary ?? "タイトルなし")
                                .font(.body)
                                .bold()
                            
                            if let dateTime = event.start?.dateTime {
                                Text(dateTime.prefix(16).replacingOccurrences(of: "T", with: " "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let date = event.start?.date {
                                Text("終日: \(date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
                .onAppear {
                    authManager.fetchCalendarEvents()
                }
            } else {
                Image(systemName: "calendar.badge.exclamationmark")
                    .imageScale(.large)
                    .foregroundStyle(.red)
                Text("Google連携が必要です")
                
                Button("Googleでログイン") {
                    authManager.signIn()
                }
                .padding(.top, 10)
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 300, height: 400)
    }
}

#Preview {
    ContentView()
}
