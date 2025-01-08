// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
import SwiftUI
import WebKit
import GOLibrary

extension GOWebview {
    public enum Request {
        case home, foward, back, reload,
             link(String), writeHtml(String), evaluateJavaScript(String), evaluateJavaScriptMethod(String, [String:Any]?)
    }
    public enum WebviewError{
        case update(Request), busy, error(Error)
    }
    public enum Event {
        case callPage(String, [URLQueryItem]?), callFuncion(String,String?,String?)
    }
    
    open class ViewModel: ObservableObject {
        @Published public internal(set)var path:String = ""
        @Published public internal(set)var request:Request? = nil{
            didSet{
                if request != nil { self.request = nil }
            }
        }
        @Published public internal(set) var event:Event? = nil{didSet{ if event != nil { event = nil} }}
        @Published public internal(set) var error:WebviewError? = nil
        @Published public internal(set) var screenHeight:CGFloat = 0
        @Published public internal(set) var isLoading:Bool = true
        @Published public internal(set) var canGoBack:Bool = false
        @Published public internal(set) var title:String? = nil
        public var prefixUrls:[String] = []
        
        let base:String
        public init(base:String = ""){
            self.base = base
        }
        public convenience init(base:String, path: String? = nil) {
            self.init(base: base)
            if let p = path { self.path = p }
            else { self.path = base }
        }
        
        func setupExcuter (_ completion:@escaping (Request) -> Void) {
            self.requestHandler = completion
        }
        
        private var requestHandler:((Request) -> Void)? = nil
        @discardableResult
        public func excute(_ request:Request)->ViewModel {
            self.request = request
            self.requestHandler?(request)
            return self
        }
        
        public func makeCookies(headers: [String: String], path: String? = nil) -> [HTTPCookie]? {
            let path = path ?? self.path
            let domain = URL(string: path)?.host
            let cookies = headers
                .enumerated()
                .map { _, element -> HTTPCookie? in
                    let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                        HTTPCookiePropertyKey.name: element.key,
                        HTTPCookiePropertyKey.value: element.value,
                        HTTPCookiePropertyKey.domain: domain ?? "",
                        HTTPCookiePropertyKey.path: "/"
                    ]
                    return HTTPCookie(properties: cookieProperties)
                }
                .compactMap { $0 }
            return cookies
        }
    }

}





extension WebViewProtocol{
    var request: URLRequest? {
        get{
            guard let url:URL = path.toUrl() else { return nil }
            return URLRequest(url: url)
        }
    }
    var scriptMessageHandler :WKScriptMessageHandler? { get{ nil } set{} }
    var scriptMessageHandlerName : String { get{""} set{} }
    var uiDelegate:WKUIDelegate? { get{nil} set{} }
    
    @MainActor
    func creatWebView(config:WKWebViewConfiguration? = nil, viewHeight:CGFloat? = nil) -> WKWebView  {
        let webView:WKWebView
        var configuration:WKWebViewConfiguration = config ?? WKWebViewConfiguration()
        if let scriptMessage = scriptMessageHandler {
            let contentController = WKUserContentController()
            contentController.add(scriptMessage, name: scriptMessageHandlerName)
            configuration.userContentController = contentController
        }
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.sizeToFit()
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #if DEBUG
        let source = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        webView.configuration.userContentController.add(Console() , name: "logHandler")
        webView.hack_removeInputAccessory()
        #endif
        return webView
    }
    
}

/*
class WKScriptController: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message:WKScriptMessage) {
        // message.name = "scriptHandler" -> 위에 WKUserContentController()에 설정한 name
        // message.body = "searchBar" -> 스크립트 부분에 webkit.messageHandlers.scriptHandler.postMessage(<<이부분>>)
        if let body = message.body as? String, body == "searchBar" {
            //guard let url = URL(string: Key.searchUrl) else { return }
            //let safariVC = SFSafariViewController(url: url)
            //present(safariVC, animated: true, completion: nil)
            
        }
        if message.body is Array<Any> { print(message.body) }
        
    }
}
*/
