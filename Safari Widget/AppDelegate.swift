
import ObjectiveC
import Cocoa
import WebKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {}

class VCont: NSViewController {
	override func loadView() {
		let webView = WKWebView()
		webView.loadRequest(NSURLRequest(URL: NSURL(string: "http://www.apple.com/")!))
		self.view = webView
	}
}
