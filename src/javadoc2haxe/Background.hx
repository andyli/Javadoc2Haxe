package javadoc2haxe;

import js.Lib;
import jQuery.JQuery;
import javadoc2haxe.Request;

class Background {	
	static function main():Void {
		chrome.Extension.onRequest.addListener(onRequest);
		chrome.PageAction.onClicked.addListener(onClick);
	}
	
	static function onRequest(request:Request, sender:chrome.MessageSender, sendResponse:Dynamic->Void):Void {
		switch (request) {
			case showPageAction: chrome.PageAction.show(sender.tab.id);
			case hidePageAction: chrome.PageAction.hide(sender.tab.id);
			default: throw "Background does not handle " + request;
		}
	}
	
	static function onClick(tab:chrome.Tab):Void {
		chrome.Tabs.executeScript(tab.id, cast {
			file: "javatohaxe.js",
			allFrames: true
		});
	}
}
