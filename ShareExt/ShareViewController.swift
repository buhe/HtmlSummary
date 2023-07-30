//
//  ShareViewController.swift
//  ShareExt
//
//  Created by 顾艳华 on 2023/7/3.
//

import UIKit
import Social
import SwiftUI
import LangChain
import AsyncHTTPClient
import Foundation
import NIOPosix
import StoreKit
import CoreData

enum Cause {
    case Failed
    case Expired
    case Success
    case HttpFailFetch
}
struct VideoInfo {
    let title: String
    let summarize: String
    let description: String
    let thumbnail: String
    let url: String
    let successed: Bool
    let cause: Cause
    let id: String
}
@available(iOSApplicationExtension, unavailable)
class ShareViewController: UIViewController {
    var requested = false
    let persistenceController = PersistenceController.shared
    @AppStorage(wrappedValue: NSLocale.preferredLanguages.first!, "lang_html", store: UserDefaults.shared) var lang: String
    
    @AppStorage(wrappedValue: 10, "html_tryout", store: UserDefaults.shared) var tryout: Int
//    let userDefaults = UserDefaults(suiteName: suiteName)
//    let semaphore = DispatchSemaphore(value: 0)
    var hasTry = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        print("lang: \(userDefaults?.object(forKey: "lang") ?? "")")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let sui = SwiftUIView(close: {
            self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
        })
        // Do any additional setup after loading the view.
        let vc  = UIHostingController(rootView: sui)
        self.addChild(vc)
        self.view.addSubview(vc.view)
        vc.didMove(toParent: self)

        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.heightAnchor.constraint(equalTo: self.view.heightAnchor).isActive = true
        vc.view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        vc.view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        vc.view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        vc.view.backgroundColor = UIColor.clear
    
       
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if checkSubscriptionStatus() {
            if !extensionContext!.inputItems.isEmpty {
                if let item = extensionContext!.inputItems.first! as? NSExtensionItem {
                    if let attachments = item.attachments {
                        for itemProvider in attachments {
                            // brower
                            if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                                itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil, completionHandler: { (item, error) in
                                    
                                    Task {
                                        let url = (item as! NSURL).absoluteString!
                                        await self.sum(url: url)
                                    }
                                })
                            }
                        }
                    }
                }
            }
        }
        else {
            let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .Expired, id: "")
            NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
        }
    }
  
    func sum(url: String) async {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        defer {
            // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
            try? httpClient.syncShutdown()
        }
        do {
            var request = HTTPClientRequest(url: url)
            request.headers.add(name: "User-Agent", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/115.0.5790.130 Mobile/15E148 Safari/604.1")
            request.method = .GET
            
            
            let response = try await httpClient.execute(request, timeout: .seconds(120))
            print(response.headers)
            if response.status == .ok {
                let plain = String(buffer: try await response.body.collect(upTo: 10240 * 1024))
                var p = ""
                switch lang {
                case let x where x.hasPrefix("zh-Hans"):
                    p = """
        以下是网页内容 : %@ , 请总结主要内容, 要求在100个字以内.
        """
                case let x where x.hasPrefix("zh-Hant"):
                    p = """
        以下是網頁內容 ： %@ ， 請總結主要內容， 要求在100個字以內.
        """
                case let x where x.hasPrefix("en"):
                    p = """
        The following is the content of the page : %@ , please summarize the main content, within 100 words.
        """
                case let x where x.hasPrefix("fr"):
                    p = """
        Voici le contenu de la page : %@ , veuillez résumer le contenu principal, dans les 100 mots.
        """
                case let x where x.hasPrefix("ja"):
                    p = """
        以下はページの内容です:%@、100語以内のメインコンテンツを要約してください。
        """
                case let x where x.hasPrefix("ko"):
                    p = """
        다음은 페이지의 내용입니다 : %@ , 주요 내용을 100 단어 이내로 요약하십시오.
        """
                case let x where x.hasPrefix("es"):
                    p = """
        El siguiente es el contenido de la página: %@ , por favor resuma el contenido principal, dentro de 100 palabras.
        """
                case let x where x.hasPrefix("it"):
                    p = """
        Di seguito è riportato il contenuto della pagina: %@ , si prega di riassumere il contenuto principale, entro 100 parole.
        """
                case let x where x.hasPrefix("de"):
                    p = """
        Das Folgende ist der Inhalt der Seite: %@ , bitte fassen Sie den Hauptinhalt innerhalb von 100 Wörtern zusammen.
        """
                default:
                    p = ""
                }
                print(lang)
                let loader = HtmlLoader(html: plain, url: url)
                let doc = await loader.load()
                if doc.isEmpty {
                    let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .Failed, id: "")
                    NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
                } else {
                    let prompt = PromptTemplate(input_variables: ["html"], template: p)
                    let request = prompt.format(args: [String(doc.first!.page_content.prefix(3000))])
                    let llm = OpenAI()
                    let reply = await llm.send(text: request)
                    print(reply)
                    
                    let uuid = UUID()
                    let uuidString = uuid.uuidString
                    let image = findImage(text: plain)
                    print("image: \(image)")
                    let payload = VideoInfo(title: doc.first!.metadata["title"]!, summarize: reply, description: "", thumbnail: image, url: url, successed: true, cause: .Success,id: uuidString)
                    if hasTry {
                        tryout -= 1
                        hasTry = false
                    }
                    NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
                }
            } else {
                // handle remote error
                print("get html, http code is not 200. \(response.status)")
                let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .Failed, id: "")
                NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
            }
        } catch {
            // handle error
            print(error)
            let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .HttpFailFetch, id: "")
            NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
        }
        
    }

    func checkSubscriptionStatus() -> Bool {
        
        let semaphore = DispatchSemaphore(value: 0)
        let request = SKReceiptRefreshRequest()
//        request.delegate = self
        request.start()
        var vaild = true
        #if DEBUG
            print("Debug mode")
            let storeURL = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")
        #else
            print("Release mode")
            let storeURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt")
        #endif
        print("store url: \(storeURL!.absoluteString)")
        
        if let receiptUrl = Bundle.main.appStoreReceiptURL {
            do {
                let receiptData = try Data(contentsOf: receiptUrl)
                let receiptString = receiptData.base64EncodedString(options: [])
                let requestContents = ["receipt-data": receiptString,
                                       "password": "4f933e61515b40b1ae3347cecad8e52e"]

                let requestData = try JSONSerialization.data(withJSONObject: requestContents,
                                                              options: [])
                
                var request = URLRequest(url: storeURL!)
                request.httpMethod = "POST"
                request.httpBody = requestData

                let session = URLSession.shared
                let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
                    if let data = data {
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                                let receiptInfo = jsonResponse["latest_receipt_info"] as? [[String: Any]] {
                                let last = receiptInfo.first!
                                let expires = Int(last["expires_date_ms"] as! String)!
                                let now = Date()
                                
                                let utcMilliseconds = Int(now.timeIntervalSince1970 * 1000)
                                if utcMilliseconds > expires {
                                    // timeout
                                    vaild = false
                                }
                            }
                        } catch {
                            print("Pasre server error: \(error)")
                        }
                    }
                    
                    semaphore.signal()
                })
                task.resume()
            } catch {
                print("Can not load receipt：\(error), user not subscriptio.")
                vaild = false
                semaphore.signal()
            }
            
        } else {
            vaild = false
            semaphore.signal()
        }
        semaphore.wait()
        if !vaild {
            if tryout > 0 {
                hasTry = true
                return true
            } else {
                //
                
                UIApplication.shared.open(URL(string:"pagily://")!)
                return false
            }
        } else {
            return true
        }
    }
    
    func findImage(text: String) -> String {
        let pattern = "(http|https)://[\\S]+?\\.(jpg|jpeg|png|gif)"

        do {
            print(text)
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            if matches.isEmpty {
                return ""
            } else {
                return String(text[Range(matches.first!.range, in: text)!])
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            return ""
        }
    }

}
struct SwiftUIView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @State var title = "Get the web page and Summarizing..."
    @State var text = ""
    init(close: @escaping () -> Void) {
        self.close = close
        NotificationCenter.default.addObserver(forName: NSNotification.Name("Summarize"), object: nil, queue: .main) { msg in
            
        }
    }
    let close: () -> Void
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(colorScheme == .light ? .white : .gray)
                .shadow(radius: 10)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .font(.title)
                    .padding()
                }
                Text(title)
                    .bold()
                    .font(.title)
                    .padding(.horizontal)
                ScrollView {
                    Text(text)
                        .font(.title2)
                }
                .padding([.bottom,.horizontal])
                Spacer()
            
            }
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Summarize"))) { msg in
            let payload = msg.object as! VideoInfo
            if payload.successed {
                title = payload.title
                text = payload.summarize
                addItem(payload: payload)
            } else {
                switch payload.cause {
                    case .HttpFailFetch:
                        text = "Failed to get webpage, please try again."
                    case .Failed:
                        text = "It is not possible to summarize this page."
                    case .Expired:
                        text = "You have exceeded the number of trials and are not subscribed."
                    default:
                    // not reachered
                        text = ""
                }
            }
        }
    }
    
    private func addItem(payload: VideoInfo) {
        let viewContext = PersistenceController.shared.container.viewContext
        // 创建一个NSFetchRequest对象来指定查询的实体
        let fetchRequest: NSFetchRequest<Html> = Html.fetchRequest()

        // 创建一个NSPredicate对象来定义查询条件
        let predicate = NSPredicate(format: "uuid == %@", payload.id)

        // 将NSPredicate对象赋值给fetchRequest的predicate属性
        fetchRequest.predicate = predicate

        // 指定任何其他所需的排序、限制或排序规则
        // fetchRequest.sortDescriptors = ...

        // 获取需要的ManagedObjectContext对象
//        let context = persistentContainer.viewContext

        do {
            // 执行查询并获取结果
            let results = try viewContext.fetch(fetchRequest)
            
//            // 处理查询结果
//            for result in results {
//                // 打印或对结果进行其他处理
//                print(result)
//            }
            
            if results.isEmpty {
                
                let newItem = Html(context: viewContext)
                newItem.timestamp = Date()
                newItem.summary = payload.summarize
                newItem.title = payload.title
                newItem.url = payload.url
                newItem.desc = payload.description
                newItem.thumbnail = payload.thumbnail
                newItem.fav = false
                newItem.uuid = payload.id
                do {
                    try viewContext.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        } catch {
            // 处理错误
            print("Error fetching data: \(error)")
        }
        
        
    }
}
