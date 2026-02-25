//
//  WebViewViewportManager.swift
//  MedianIOS
//
//  Created by Kevz on 1/16/26.
//  Copyright © 2026 GoNative.io LLC. All rights reserved.
//

import GoNativeCore
import WebKit

@objc final class WebViewViewportManager: NSObject {
    @objc static let shared = WebViewViewportManager()
    
    var currentUserScript: WKUserScript?
    
    @objc func handleUrl(_ url: URL, query: [AnyHashable: Any], webView: WKWebView?, completion: @escaping ([AnyHashable : Any]) -> Void) {
        if url.path.hasPrefix("/getZoom") {
            getViewportScale(webView: webView, completion: completion)
        } else if url.path == "/setZoom" {
            if let zoom = query["zoom"] as? NSNumber {
                setViewport(scale: zoom, width: nil, webView: webView)
            }
        }
    }

    @objc func getViewportScale(webView: WKWebView?, completion: @escaping ([AnyHashable : Any]) -> Void) {
        let javascript =
        """
            (function() {
                var meta = document.querySelector('meta[name=viewport]');
                if (!meta) return null;
                var content = meta.getAttribute('content');
                if (!content) return null;
                var match = content.match(/initial-scale\\s*=\\s*([0-9\\.]+)/);
                return match ? parseFloat(match[1]) : null;
            })();
        """
        
        webView?.evaluateJavaScript(javascript) { result, error in
            guard error == nil, let value = result as? NSNumber else {
                completion(["zoom": 1])
                return
            }
            completion(["zoom": CGFloat(truncating: value)])
        }
    }

    @objc func setViewport(scale: NSNumber?, width: NSNumber?, webView: WKWebView?) {
        let appConfig = GoNativeAppConfig.shared()!
        
        var viewportContent = ""
        if let scale = scale {
            let initialScale = String(format: "%.3f", scale.doubleValue)
            let maximumScale = String(format: "%.3f", scale.doubleValue * 2)
            viewportContent = String(format: "initial-scale=%@,maximum-scale=%@", initialScale, maximumScale)
        } else if let width = width {
            viewportContent = String(format: "width=%@", width)
        }
        
        let javascript = String(format:
        """
            (function() {
                var meta = document.querySelector('meta[name=viewport]');
                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head.appendChild(meta);
                }
                var newMetaContent = '%@';
                var userScalable = 'user-scalable=%@';
                if (newMetaContent) {
                    meta.setAttribute('content', newMetaContent + ',' + userScalable);
                    return;
                }
                var metaContent = meta.getAttribute('content');
                if (metaContent) {
                    meta.setAttribute('content', metaContent + ',' + userScalable);
                    return;
                }
                meta.setAttribute('content', userScalable);
            })();
        """,
            viewportContent,
            appConfig.pinchToZoom ? "yes" : "no"
        )

        updateCurrentScript(javascript, webView: webView)
    }
    
    private func updateCurrentScript(_ javascript: String, webView: WKWebView?) {
        guard let webView = webView else {
            return
        }
        
        webView.evaluateJavaScript(javascript, completionHandler: nil)
        
        let newScript = WKUserScript(source: javascript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        var userScripts = webView.configuration.userContentController.userScripts
        
        if let currentUserScript = currentUserScript {
            userScripts.removeAll(where: { $0 == currentUserScript } )
            webView.configuration.userContentController.removeAllUserScripts()
            
            for userScript in userScripts {
                webView.configuration.userContentController.addUserScript(userScript)
            }
        }
        
        webView.configuration.userContentController.addUserScript(newScript)
        currentUserScript = newScript
    }
}
