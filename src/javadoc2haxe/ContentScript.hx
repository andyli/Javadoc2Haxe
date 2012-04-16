package javadoc2haxe;

import js.Lib;
import jQuery.JQuery;
import javadoc2haxe.Request;

class ContentScript {	
	static function main():Void {
		if (JavaToHaxe.isJavadocClassPage()) {
			chrome.Extension.onRequest.addListener(onRequest);
			chrome.Extension.sendRequest(showPageAction);
			
			new JQuery(Lib.window).bind('beforeunload', function(){ 
				chrome.Extension.sendRequest(hidePageAction);
				chrome.Extension.onRequest.removeListener(onRequest);
			});
		}
	}
	
	static function onRequest(request:Request, sender:chrome.MessageSender, sendResponse:Dynamic->Void):Void {
		switch (request) {
			case loadJavaToHaxe:
				JavaToHaxe.main();
			default: throw "ContentScript does not handle " + request;
		}
	}
}
