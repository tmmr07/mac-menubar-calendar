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
    
    // UI表示用にデータを分割して保持
    @Published var todayEvents: [CalendarEvent] = []
    @Published var tomorrowEvents: [CalendarEvent] = []
    @Published var todayTasks: [TaskItem] = []
    @Published var tomorrowTasks: [TaskItem] = []
    
    let clientID = Secrets.clientID
    let clientSecret = Secrets.clientSecret
    let scheme = Secrets.scheme
    
    var redirectURI: String {
        return "\(scheme):/oauth2redirect"
    }
    
    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    
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
        // カレンダーとタスクの読み取り権限
        let scope = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/tasks.readonly"
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURLString = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(encodedScope)&access_type=offline&prompt=consent"
        
        guard let authURL = URL(string: authURLString) else { return }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
            guard error == nil, let callbackURL = callbackURL else { return }
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else { return }
            
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
                
                UserDefaults.standard.set(token, forKey: self.accessTokenKey)
                if let refreshToken = json["refresh_token"] as? String {
                    UserDefaults.standard.set(refreshToken, forKey: self.refreshTokenKey)
                }
                
                DispatchQueue.main.async {
                    self.accessToken = token
                    self.isAuthenticated = true
                    self.fetchAllData()
                }
            }
        }.resume()
    }
    
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
    
    // カレンダーとタスクの両方を取得
    func fetchAllData() {
        fetchCalendarEvents()
        fetchTasks()
    }
    
    private func fetchCalendarEvents() {
        guard let token = accessToken else { return }
        
        // 今日の0時から明後日の0時までを取得範囲に設定
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: todayStart)!
        
        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: todayStart)
        let timeMax = formatter.string(from: dayAfterTomorrow)
        
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&maxResults=50&orderBy=startTime&singleEvents=true"
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                self.refreshAccessToken { success in
                    if success { self.fetchAllData() }
                    else { DispatchQueue.main.async { self.logout() } }
                }
                return
            }
            
            guard let data = data, error == nil else { return }
            
            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(CalendarResponse.self, from: data)
                    let events = response.items ?? []
                    self.distributeEvents(events)
                } catch {
                    print("カレンダー解析エラー: \(error)")
                }
            }
        }.resume()
    }
    
    private func fetchTasks() {
        guard let token = accessToken else { return }
        
        // 未完了のタスクを取得（@defaultリストから）
        let urlString = "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks?showCompleted=false"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 { return } // カレンダー側でリフレッシュを処理するためここは無視
            guard let data = data, error == nil else { return }
            
            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(TaskResponse.self, from: data)
                    let tasks = response.items ?? []
                    self.distributeTasks(tasks)
                } catch {
                    print("タスク解析エラー: \(error)")
                }
            }
        }.resume()
    }
    
    // 予定を今日と明日に振り分け
    private func distributeEvents(_ events: [CalendarEvent]) {
        let calendar = Calendar.current
        var today: [CalendarEvent] = []
        var tomorrow: [CalendarEvent] = []
        
        for event in events {
            guard let dateString = event.start?.dateTime ?? event.start?.date,
                  let date = parseDate(dateString) else { continue }
            
            if calendar.isDateInToday(date) {
                today.append(event)
            } else if calendar.isDateInTomorrow(date) {
                tomorrow.append(event)
            }
        }
        self.todayEvents = today
        self.tomorrowEvents = tomorrow
    }
    
    // タスクを今日（過去含む）と明日に振り分け
    private func distributeTasks(_ tasks: [TaskItem]) {
        let calendar = Calendar.current
        var today: [TaskItem] = []
        var tomorrow: [TaskItem] = []
        let todayStart = calendar.startOfDay(for: Date())
        
        for task in tasks {
            guard let dueString = task.due, let dueDate = parseTaskDate(dueString) else { continue }
            
            if calendar.isDateInTomorrow(dueDate) {
                tomorrow.append(task)
            } else if dueDate < calendar.date(byAdding: .day, value: 1, to: todayStart)! {
                // 今日が期限、またはすでに期限切れのタスク
                today.append(task)
            }
        }
        self.todayTasks = today
        self.tomorrowTasks = tomorrow
    }
    
    // 日付パース用のヘルパー
    private func parseDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let d = isoFormatter.date(from: string) { return d }
        
        let ymdFormatter = DateFormatter()
        ymdFormatter.dateFormat = "yyyy-MM-dd"
        return ymdFormatter.date(from: string)
    }
    
    private func parseTaskDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: string) { return d }
        
        let fb = ISO8601DateFormatter()
        return fb.date(from: string)
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        self.accessToken = nil
        self.isAuthenticated = false
        self.todayEvents = []
        self.tomorrowEvents = []
        self.todayTasks = []
        self.tomorrowTasks = []
    }
}
