/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */
package weave.services
{
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	
	import mx.core.mx_internal;
	import mx.rpc.AsyncToken;
	import mx.rpc.Fault;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.StringUtil;
	import mx.utils.UIDUtil;
	
	import weave.api.reportError;
	import weave.compiler.StandardLib;

	public class ExternalDownloader
	{
		[Embed(source="ExternalDownloader.js", mimeType="application/octet-stream")]
		private static const JS_ExternalDownloader:Class;
		
		/**
		 * This maps a unique ID (generated when a request is made to download from a URL through this class)
		 * to a QueryToken associated with it.
		 */
		private static const uniqueIDToTokenMap:Object = new Object();
		
		private static var _initialized:Boolean = false;
		
		private static function initialize():void
		{
			if(_initialized)
				return;
			
			WeaveAPI.initializeJavaScript(JS_ExternalDownloader);
			JavaScript.registerMethod("ExternalDownloader_callback", callback);
			
			_initialized = true;
		}
		
		public static function download(urlRequest:URLRequest, dataFormat:String, token:AsyncToken):void
		{
			initialize();
			
			var id:String = UIDUtil.createUID();
			var url:String = urlRequest.url;
			var method:String = urlRequest.method;
			var requestHeaders:Object = {};
			var base64data:String = null;
			
			for each (var header:URLRequestHeader in urlRequest.requestHeaders)
				requestHeaders[header.name] = header.value;

			if (method == URLRequestMethod.POST)
			{
				var bytes:ByteArray = urlRequest.data as ByteArray;
				if (urlRequest.data is String)
				{
					bytes = new ByteArray();
					bytes.writeUTFBytes(urlRequest.data as String);
				}
				
				base64data = StandardLib.btoa(bytes);
			}
			else
			{
				if (urlRequest.data is URLVariables)
					url += "?" + urlRequest.data;
			}
			
			uniqueIDToTokenMap[id] = new QueryToken(urlRequest, dataFormat, token);
			
			try
			{
				JavaScript.exec(
					{"args": [id, method, url, requestHeaders, base64data]},
					"this.ExternalDownloader_request.apply(this, args);"
				);
			}
			catch (e:Error)
			{
				_errors[id] = e;
				WeaveAPI.StageUtils.callLater(null, callback, [id, -1, null]);
			}
		}
		
		/**
		 * id -> Error
		 */
		private static const _errors:Object = {};
		
		/**
		 * @param id The id that was passed to weave.ExternalDownloader_get().
		 * @param status The HTTP status (200 = OK)
		 * @param base64data The data, encoded as a base64 String
		 */
		private static function callback(id:String, status:int, base64data:String):void
		{
			var qt:QueryToken = uniqueIDToTokenMap[id] as QueryToken;
			delete uniqueIDToTokenMap[id];
			if (!qt)
				return;
			
			var result:Object;
			if (base64data)
			{
				var bytes:ByteArray = StandardLib.atob(base64data);
				if (qt.dataFormat == URLRequestUtils.DATA_FORMAT_BINARY)
					result = bytes;
				else
					result = bytes.toString();
			}
			
			if (status == 200)
			{
				qt.asyncToken.mx_internal::applyResult(ResultEvent.createEvent(result, qt.asyncToken));
			}
			else
			{
				var fault:Fault;
				if (_errors[id])
				{
					var e:Error = _errors[id];
					fault = new Fault(e.name, StringUtil.trim(e.message) + " URL: " + qt.urlRequest.url);
					fault.rootCause = e;
				}
				else
				{
					var faultCode:String = null;
					if (HTTP_STATUS_CODES[status])
						faultCode = status + " " + lang(HTTP_STATUS_CODES[status]);
					else if (status)
						faultCode = "" + status;
					else
						faultCode = lang("Error");
					
					fault = new Fault(faultCode, lang("HTTP " + qt.urlRequest.method + " failed; Check that the server allows Cross-Origin Resource Sharing (CORS)"), qt.urlRequest.url);
					fault.content = result;
				}
				qt.asyncToken.mx_internal::applyFault(FaultEvent.createEvent(fault, qt.asyncToken));
			}
		}
		
		/**
		 * Maps a status code to a description.
		 */
		public static const HTTP_STATUS_CODES:Object = {
			"100": "Continue",
			"101": "Switching Protocol",
			"200": "OK",
			"201": "Created",
			"202": "Accepted",
			"203": "Non-Authoritative Information",
			"204": "No Content",
			"205": "Reset Content",
			"206": "Partial Content",
			"300": "Multiple Choice",
			"301": "Moved Permanently",
			"302": "Found",
			"303": "See Other",
			"304": "Not Modified",
			"305": "Use Proxy",
			"306": "unused",
			"307": "Temporary Redirect",
			"308": "Permanent Redirect",
			"400": "Bad Request",
			"401": "Unauthorized",
			"402": "Payment Required",
			"403": "Forbidden",
			"404": "Not Found",
			"405": "Method Not Allowed",
			"406": "Not Acceptable",
			"407": "Proxy Authentication Required",
			"408": "Request Timeout",
			"409": "Conflict",
			"410": "Gone",
			"411": "Length Required",
			"412": "Precondition Failed",
			"413": "Request Entity Too Large",
			"414": "Request-URI Too Long",
			"415": "Unsupported Media Type",
			"416": "Requested Range Not Satisfiable",
			"417": "Expectation Failed",
			"500": "Internal Server Error",
			"501": "Not Implemented",
			"502": "Bad Gateway",
			"503": "Service Unavailable",
			"504": "Gateway Timeout",
			"505": "HTTP Version Not Supported"
		};
	}
}

import flash.net.URLRequest;

import mx.rpc.AsyncToken;

internal class QueryToken
{
	public function QueryToken(urlRequest:URLRequest, dataFormat:String, asyncToken:AsyncToken)
	{
		this.urlRequest = urlRequest;
		this.dataFormat = dataFormat;
		this.asyncToken = asyncToken;
	}
	
	public var urlRequest:URLRequest;
	public var dataFormat:String;
	public var asyncToken:AsyncToken;
}
