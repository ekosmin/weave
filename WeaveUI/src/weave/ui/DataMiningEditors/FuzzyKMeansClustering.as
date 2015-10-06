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

/**
 * Makes calls to R to carry out fuzzy kmeans clustering
 * Takes columns as input
 * returns clustering object 
 * 
 * @author spurushe
 */
package weave.ui.DataMiningEditors
{
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import weave.Weave;
	import weave.api.core.ILinkableObject;
	import weave.api.data.IAttributeColumn;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.core.LinkableHashMap;
	import weave.services.WeaveRServlet;
	import weave.services.addAsyncResponder;
	import weave.services.beans.FuzzyKMeansClusteringResult;
	import weave.services.beans.RResult;
	import weave.utils.ResultUtils;

	public class FuzzyKMeansClustering implements ILinkableObject
	{
		public const identifier:String = "FuzzyKMeans";
		private var algoCaller:Object;//this identifies which UI component is calling the kMeans i.e. the Data Mining Platter or the FuzzyKMeansClusteringEditor
		
		public const inputColumns:LinkableHashMap = registerLinkableChild(this, new LinkableHashMap(IAttributeColumn));
		private var Rservice:WeaveRServlet = new WeaveRServlet(Weave.properties.rServiceURL.value);
		public var finalResult:FuzzyKMeansClusteringResult;
		
		public var checkingIfFilled:Function;
		
		public function FuzzyKMeansClustering(caller:Object, fillingResult:Function = null)
		{
			checkingIfFilled = fillingResult;
			this.algoCaller = caller;
		}
		
		
		//sends the columns to R to do fuzzy k means
		public function doFuzzyKMeans(_columns:Array,token:Array,_numberOfClusters:Number, _numberOfIterations:Number, _metric:String):void
		{
			var inputValues:Array = new Array();
			inputValues.push(_columns);
			inputValues.push(_numberOfClusters);
			inputValues.push(_metric);
			inputValues.push(_numberOfIterations);
			var inputNames: Array = ["inputColumns","clusterNumber","check","iterationNumber"];
			
			var outputNames:Array = ["fuzzResult$clustering"];
			 var fuzzkMeansScript:String = "library(cluster)\n" +
			"frame <- data.frame(inputColumns)\n"+
			"fuzzResult <- fanny(frame,clusterNumber, metric = check, maxit = iterationNumber)\n";
			
			
			var query:AsyncToken = Rservice.runScript(token,inputNames, inputValues,outputNames,fuzzkMeansScript,"",false, false, false);
			addAsyncResponder(query,handleRunScriptResult, handleRunScriptFault,token);
			
		}
		
		public function handleRunScriptResult(event:ResultEvent, keys:Array):void
		{
			var clusterArray:Array = new Array();
			//Object to stored returned result - Which is array of object{name: , value: }
			var Robj:Array = event.result as Array;
			//trace('Robj:',ObjectUtil.toString(Robj));
			if (Robj == null)
			{
				reportError("R Servlet did not return an Array of results as expected.");
				return;
			}
			
			
			var RresultArray:Array = new Array();
			//collecting Objects of type RResult(Should Match result object from Java side)
			for (var i:int = 0; i < (event.result).length; i++)
			{
				if (Robj[i] == null)
				{
					trace("WARNING! R Service returned null in results array at index "+i);
					continue;
				}
				var rResult:RResult = new RResult(Robj[i]);
				clusterArray.push(rResult.value);
			}
			
			RresultArray.push(Robj[0]);
			
			if(algoCaller is DataMiningChannelToR)
			{
				finalResult = new FuzzyKMeansClusteringResult(clusterArray,keys);
				if(checkingIfFilled != null)
					checkingIfFilled(finalResult);
			}
			else
			{
				ResultUtils.rResultToColumn(keys, RresultArray, Robj);
			}
	    }
		
		public function handleRunScriptFault(event:FaultEvent, token:Object = null):void
		{
			trace(["fault", token, event.message].join('\n'));
			reportError(event);
		}
	}
}
