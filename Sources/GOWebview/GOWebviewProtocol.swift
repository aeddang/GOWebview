//
//  GOWebviewProtocol.swift
//  GOWebview
//
//  Created by JeongCheol Kim on 1/7/25.
//
import Foundation
import SwiftUI
import WebKit

public class GOWebview{
}
protocol GOWebviewProtocol {}
extension GOWebviewProtocol {
    var tag:String {
        get{ "\(String(describing: Self.self))" }
    }
}

protocol WebViewProtocol:GOWebviewProtocol {
    var path: String { get set }
    var request: URLRequest? { get }
    var scriptMessageHandler :WKScriptMessageHandler? { get set }
    var scriptMessageHandlerName : String { get set }
    var uiDelegate:WKUIDelegate? { get set }
}
