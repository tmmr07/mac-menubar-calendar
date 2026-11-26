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
    
    // Googleから取得するデータ（今日・明日）
    @Published var todayEvents: [CalendarEvent] = []
    @Published var tomorrowEvents: [CalendarEvent] = []
    @Published var todayTasks: [TaskItem] = []
    @Published var tomorrowTasks: [TaskItem] = []
    
    // アプリ内で独自に追加・保存するデータ（4列目：今後）
    @Published var customTasks: [CustomTask] = []
    @Published var customEvents: [CustomEvent] = []
    
    let clientID = Secrets.clientID
    let clientSecret = Secrets.clientSecret
    let scheme = Secrets.scheme
    
    var redirectURI: String {
        return "\(scheme):/oauth2redirect"
    }
    
    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let customTasksKey = "local_custom_tasks"
    private let customEventsKey = "local_custom_events"
    
    override init() {
        super.init()
        if let savedToken = UserDefaults.standard.string(forKey: accessTokenKey) {
            self.accessToken = savedToken
            self.isAuthenticated = true
        }
        // 保存されている独自タスクと予定を読み込む
        loadCustomData()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
    
    func signIn() {
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
    
    func fetchAllData() {
        fetchCalendarEvents()
        fetchTasks()
    }
    
    private func fetchCalendarEvents() {
        guard let token = accessToken else { return }
        
        // 今日の0時から明後日の0時まで（今日と明日分）を取得
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
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
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
        
        let urlString = "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks?showCompleted=false&maxResults=100&showHidden=true"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 { return }
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
    
    private func distributeTasks(_ tasks: [TaskItem]) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        var today: [TaskItem] = []
        var tomorrow: [TaskItem] = []
        
        for task in tasks {
            guard let dueString = task.due, let dueDate = parseTaskDate(dueString) else { continue }
            
            if calendar.isDateInTomorrow(dueDate) {
                tomorrow.append(task)
            } else if dueDate < tomorrowStart {
                today.append(task)
            }
        }
        
        self.todayTasks = today
        self.tomorrowTasks = tomorrow
    }
    
    // MARK: - 独自タスク・予定の管理（4列目用）
    
    func addCustomTask(title: String, dueDate: Date, category: TaskCategory) {
        let newTask = CustomTask(title: title, dueDate: dueDate, category: category)
        customTasks.append(newTask)
        // 期限が短い（早い）順にソート
        customTasks.sort { $0.dueDate < $1.dueDate }
        saveCustomTasks()
    }
    
    func deleteCustomTask(id: UUID) {
        customTasks.removeAll { $0.id == id }
        saveCustomTasks()
    }
    
    func addCustomEvent(title: String, startDate: Date, endDate: Date) {
        let newEvent = CustomEvent(title: title, startDate: startDate, endDate: endDate)
        customEvents.append(newEvent)
        // 開始日時が早い順にソート
        customEvents.sort { $0.startDate < $1.startDate }
        saveCustomEvents()
    }
    
    func deleteCustomEvent(id: UUID) {
        customEvents.removeAll { $0.id == id }
        saveCustomEvents()
    }
    
    private func saveCustomTasks() {
        if let encoded = try? JSONEncoder().encode(customTasks) {
            UserDefaults.standard.set(encoded, forKey: customTasksKey)
        }
    }
    
    private func saveCustomEvents() {
        if let encoded = try? JSONEncoder().encode(customEvents) {
            UserDefaults.standard.set(encoded, forKey: customEventsKey)
        }
    }
    
    private func loadCustomData() {
        if let taskData = UserDefaults.standard.data(forKey: customTasksKey),
           let decodedTasks = try? JSONDecoder().decode([CustomTask].self, from: taskData) {
            self.customTasks = decodedTasks.sorted { $0.dueDate < $1.dueDate }
        }
        if let eventData = UserDefaults.standard.data(forKey: customEventsKey),
           let decodedEvents = try? JSONDecoder().decode([CustomEvent].self, from: eventData) {
            self.customEvents = decodedEvents.sorted { $0.startDate < $1.startDate }
        }
    }
    
    // MARK: - ヘルパー
    
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
