//
//  GOWebviewComponent.swift
//  GOWebview
//
//  Created by JeongCheol Kim on 1/7/25.
//
import Foundation
import SwiftUI
import WebKit
import Combine
import GOLibrary

extension GOWebview {
    struct GOWebviewComponent: View {
        @EnvironmentObject var viewModel:ViewModel
        var config: WKWebViewConfiguration? = nil
        var scriptMessageHandler :WKScriptMessageHandler? = nil
        var scriptMessageHandlerName : String = ""
        var uiDelegate:WKUIDelegate? = nil
        var body: some View {
            ZStack{
                GOWebviewRepresentable(
                    config: self.config ,
                    scriptMessageHandler: scriptMessageHandler,
                    scriptMessageHandlerName: scriptMessageHandlerName,
                    uiDelegate: uiDelegate
                )
                if self.isLoading {
                    
                }
            }
            .onReceive(self.viewModel.$isLoading) { isLoading in
                withAnimation {
                    self.isLoading = isLoading
                }
            }
        }
        @State private var isLoading:Bool = false
    }
}


struct GOWebviewRepresentable : UIViewRepresentable, @preconcurrency WebViewProtocol {
    @EnvironmentObject var viewModel:GOWebview.ViewModel
    var config: WKWebViewConfiguration? = nil
    var scriptMessageHandler :WKScriptMessageHandler? = nil
    var scriptMessageHandlerName : String = ""
    var uiDelegate:WKUIDelegate? = nil
    var path: String = ""
    var request: URLRequest? {
        get{
            ComponentLog.log("origin request " + viewModel.path , tag:self.tag )
            guard let url:URL = URL(string: viewModel.path) else { return nil }
            return URLRequest(url: url)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    func makeUIView(context: Context) -> WKWebView  {
        let uiView = creatWebView(config: self.config)
        uiView.navigationDelegate = context.coordinator
        uiView.uiDelegate = context.coordinator
        uiView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        self.viewModel.setupExcuter(){ request in
            self.excute(request, uiView: uiView)
        }
        return uiView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    
    
    private func excute(_ request: GOWebview.Request, uiView:WKWebView) {
        switch request {
        case .home:
            goHome(uiView)
            return
        case .writeHtml(let html):
            uiView.loadHTMLString(html, baseURL: nil)
            return
        case .evaluateJavaScript(let jsStr):
            self.callJS(uiView, jsStr: jsStr)
            return
        case .evaluateJavaScriptMethod(let fn, let dic):
            var jsStr = ""
            if let dic = dic {
                let jsonString = AppUtil.getJsonString(dic: dic) ?? ""
                jsStr = fn + "(\'" + jsonString + "\')"
            } else {
                jsStr = fn + "()"
            }
            self.callJS(uiView, jsStr: jsStr)
            return
        case .back:
            if uiView.canGoBack {uiView.goBack()}
            else {
                self.viewModel.error = .update(.back)
                return
            }
        case .foward:
            if uiView.canGoForward {uiView.goForward() }
            else {
                self.viewModel.error = .update(.foward)
                return
            }
        case .reload:
            uiView.reload()
            
        case .link(let path) :
            self.goLink(uiView, path: path)
            uiView.becomeFirstResponder()
        }
    }
    
    
    
    
    private func goHome(_ uiView: WKWebView){
        self.viewModel.path = self.viewModel.base
        if self.viewModel.path == "" {
            self.viewModel.error = .update(.home)
            return
        }
        self.viewModel.isLoading = true
        guard let request = self.request else {
            self.viewModel.error = .update(.home)
            return
        }
        uiView.load(request)
    }
    
    private func goLink(_ uiView: WKWebView, path:String){
        self.viewModel.path = path
        if self.viewModel.path == "" {
            self.viewModel.error = .update(.link(path))
            return
        }
        self.viewModel.isLoading = true
        guard let request = self.request else {
            self.viewModel.error = .update(.link(path))
            return
        }
        uiView.load(request)
    }
    
    private func callJS(_ uiView: WKWebView, jsStr: String) {
        ComponentLog.d("callJS -> "+jsStr, tag: self.tag)
        uiView.evaluateJavaScript(jsStr, completionHandler: { (result, error) in
            let resultString = result.debugDescription
            let errorString = error.debugDescription
            let msg = "callJS -> result: " + resultString + "\n error: " + errorString
            ComponentLog.d(msg, tag: self.tag)
        })
    }
}

class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, GOWebviewProtocol {
    var parent: GOWebviewRepresentable
    init(_ parent: GOWebviewRepresentable) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        let path = navigationAction.request.url?.absoluteString ?? ""
        if let find = self.parent.viewModel.prefixUrls.first(where: {path.hasPrefix($0)}) {
            self.parent.viewModel.isLoading = false
            ComponentLog.d("redirect prefix url -> " + find, tag: self.tag)
            AppUtil.openURL(path)
            return (.cancel, preferences)
        }
        self.parent.viewModel.isLoading = true
        return (.allow, preferences)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        ComponentLog.e("error -> " + error.localizedDescription, tag: self.tag)
        self.parent.viewModel.error = .error(error)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.parent.viewModel.isLoading = false
    }
    
    
}

