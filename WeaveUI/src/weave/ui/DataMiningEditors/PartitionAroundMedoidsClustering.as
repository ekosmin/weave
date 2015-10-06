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
 * Makes calls to R to carry out partition around medoids clustering
 * Takes columns as input
 * returns clustering object 
 * 
 * 
 * @author spurushe
 */
package weave.ui.DataMiningEditors
{
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ObjectUtil;
	
	import weave.Weave;
	import weave.api.core.ILinkableObject;
	import weave.api.data.IAttributeColumn;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.core.LinkableHashMap;
	import weave.services.WeaveRServlet;
	import weave.services.addAsyncResponder;
	import weave.services.beans.PartitionAroundMedoidsClusteringResult;
	import weave.services.beans.RResult;
	import weave.utils.ResultUtils;

	public class PartitionAroundMedoidsClustering implements ILinkableObject
	{
		public const identifier:String = "PamClustering";
		private var algoCaller:Object;
		
		public const inputColumns:LinkableHashMap = registerLinkableChild(this, new LinkableHashMap(IAttributeColumn));
		private var Rservice:WeaveRServlet = new WeaveRServlet(Weave.properties.rServiceURL.value);
		public var finalResult:PartitionAroundMedoidsClusteringResult;
			
		private var checkingIfFilled:Function;
	
		public function PartitionAroundMedoidsClustering(caller:Object, fillingFuzzKMeansResult:Function = null)
		{
				checkingIfFilled = fillingFuzzKMeansResult;
				this.algoCaller = caller;
		}
			
			
			//sends the columns to R to do partitioning around medoids clustering
		public function doPAM(_columns:Array,token:Array,_numberOfClusters:Number, _metric:String):void
		{
				var inputValues:Array = new Array();
				inputValues.push(_columns);
				inputValues.push(_numberOfClusters);
				inputValues.push(_metric);
				var inputNames: Array = ["inputColumns","clusterNumber","check"];
				
				
				var pamScript:String = "library(cluster)\n" +
					"frame <- data.frame(inputColumns)\n" +
					"pResult <- pam(frame, clusterNumber, metric = check)\n";
				var outputNames:Array = ["pResult$clustering"];
				
				
				var query:AsyncToken = Rservice.runScript(token,inputNames, inputValues,outputNames,pamScript,"",false, false, false);
				addAsyncResponder(query,handleRunScriptResult, handleRunScriptFault,token);
				
		}
			
		public function handleRunScriptResult(event:ResultEvent, keys:Array):void
		{
				//Object to stored returned result - Which is array of object{name: , value: }
				var Robj:Array = event.result as Array;
				var clusterResult:Array = new Array();
				trace('Robj:',ObjectUtil.toString(Robj));
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
					clusterResult.push(rResult.value);
				}
				
				RresultArray.push(Robj[0]);				
				
				if(algoCaller is DataMiningChannelToR)
				{
					finalResult = new PartitionAroundMedoidsClusteringResult(clusterResult,keys);
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