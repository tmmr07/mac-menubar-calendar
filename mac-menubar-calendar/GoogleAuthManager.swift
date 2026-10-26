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
    @Published var events: [CalendarEvent] = []
    
    let clientID = Secrets.clientID
    let clientSecret = Secrets.clientSecret
    let scheme = Secrets.scheme
    
    var redirectURI: String {
        return "\(scheme):/oauth2redirect"
    }
    
    // アプリ内に保存するためのキー
    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    
    // 【追加】アプリ起動時に保存されているトークンを読み込む
    override init() {
        super.init()
        if let savedToken = UserDefaults.standard.string(forKey: accessTokenKey) {
            self.accessToken = savedToken
            self.isAuthenticated = true
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
    
    func signIn() {
        let scope = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/tasks.readonly"
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // 【変更】リフレッシュトークンを取得するために「&access_type=offline&prompt=consent」をURLに追加
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(encodedScope)&access_type=offline&prompt=consent"
        
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
                
                // 【追加】取得したトークンをMacに保存
                UserDefaults.standard.set(token, forKey: self.accessTokenKey)
                
                // 【追加】リフレッシュトークンも一緒に保存
                if let refreshToken = json["refresh_token"] as? String {
                    UserDefaults.standard.set(refreshToken, forKey: self.refreshTokenKey)
                }
                
                DispatchQueue.main.async {
                    self.accessToken = token
                    self.isAuthenticated = true
                    self.fetchCalendarEvents() // ログイン直後に予定を取得
                }
            } else {
                if let dataString = String(data: data, encoding: .utf8) {
                    print("トークン取得失敗: \(dataString)")
                }
            }
        }.resume()
    }
    
    // 【追加】トークンが1時間で切れた場合に、裏で新しいトークンを取り直すメソッド
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(clientID)&client_secret=\(clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newToken = json["access_token"] as? String {
                
                // 新しいトークンで上書き保存
                UserDefaults.standard.set(newToken, forKey: self.accessTokenKey)
                
                DispatchQueue.main.async {
                    self.accessToken = newToken
                    self.isAuthenticated = true
                    completion(true)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    func fetchCalendarEvents() {
        guard let token = accessToken else { return }
        
        let timeMin = ISO8601DateFormatter().string(from: Date())
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&maxResults=10&orderBy=startTime&singleEvents=true"
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 【追加】HTTPステータスコード401（認証エラー/期限切れ）が返ってきたら自動リフレッシュ
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                print("アクセストークンが期限切れです。リフレッシュを試みます...")
                self.refreshAccessToken { success in
                    if success {
                        self.fetchCalendarEvents() // リフレッシュ成功後、再度予定を取得
                    } else {
                        DispatchQueue.main.async { self.logout() } // 失敗時はログアウト
                    }
                }
                return
            }
            
            guard let data = data, error == nil else { return }
            
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
    
    // 【追加】ログアウト処理（保存したトークンをすべて削除）
    func logout() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        self.accessToken = nil
        self.isAuthenticated = false
        self.events = []
    }
}
