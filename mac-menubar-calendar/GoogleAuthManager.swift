//
//  GoogleAuthManager.swift
//  mac-menubar-calendar
//

import Foundation
import AuthenticationServices
import AppKit
import Combine

class GoogleAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    
    // 【追加】取得したカレンダーの予定を保持する配列
    @Published var events: [CalendarEvent] = []
    
    // Secrets.swift から認証情報を読み込む
    let clientID = Secrets.clientID
    let clientSecret = Secrets.clientSecret
    let scheme = Secrets.scheme
    
    var redirectURI: String {
        return "\(scheme):/oauth2redirect"
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
    
    func signIn() {
        let scope = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/tasks.readonly"
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(encodedScope)"
        
        guard let authURL = URL(string: authURLString) else { return }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
            guard error == nil, let callbackURL = callbackURL else {
                print("認証エラー: \(String(describing: error))")
                return
            }
            
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                return
            }
            
            self.exchangeCodeForToken(code: code)
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "code=\(code)&client_id=\(clientID)&client_secret=\(clientSecret)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                DispatchQueue.main.async {
                    self.accessToken = token
                    self.isAuthenticated = true
                    print("アクセストークン取得成功: \(token)")
                }
            } else {
                if let dataString = String(data: data, encoding: .utf8) {
                    print("トークン取得失敗: \(dataString)")
                }
            }
        }.resume()
    }
    
    // 【追加】カレンダーの予定を取得するメソッド
    func fetchCalendarEvents() {
        guard let token = accessToken else { return }
        
        // 現在時刻以降の予定を取得するため、時刻をISO8601にフォーマット
        let timeMin = ISO8601DateFormatter().string(from: Date())
        // 直近10件を取得するエンドポイント
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&maxResults=10&orderBy=startTime&singleEvents=true"
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("データ取得エラー: \(String(describing: error))")
                return
            }
            
            // JSONのデコード処理もメインスレッドの中で行うように移動
            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(CalendarResponse.self, from: data)
                    self.events = response.items ?? []
                } catch {
                    print("JSON解析エラー: \(error)")
                }
            }
        }.resume()
    }
}
