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

package weave.visualization.layers
{
	import flash.events.Event;
	
	import mx.events.ResizeEvent;
	
	import spark.components.Group;
	import spark.core.SpriteVisualElement;
	
	import weave.api.core.ILinkableObject;
	import weave.api.newLinkableChild;
	import weave.api.objectWasDisposed;
	import weave.api.primitives.IBounds2D;
	import weave.api.setSessionState;
	import weave.core.ClassUtils;
	import weave.core.SessionManager;

	/**
	 * @author adufilie
	 */
	public class Visualization extends Group implements ILinkableObject
	{
		public function Visualization()
		{
			super();
			
			/*this.horizontalScrollPolicy = "off";
			this.verticalScrollPolicy = "off";*/

			autoLayout = true;
			percentHeight = 100;
			percentWidth = 100;
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			var sprCont:SpriteVisualElement = new SpriteVisualElement();
			sprCont.addChild(plotManager.bitmap);
			addElement(sprCont);
			//rawChildren.addChild(plotManager.bitmap);
			addEventListener(ResizeEvent.RESIZE, handleResize);
		}
		
		private function handleResize(e:Event):void
		{
			if (objectWasDisposed(this))
				return;
			
			plotManager.setBitmapDataSize(unscaledWidth, unscaledHeight);
		}
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList.apply(this, arguments);
			
			if (objectWasDisposed(this))
				return;
			
			plotManager.setBitmapDataSize.apply(null, arguments);
		}
		
		public const plotManager:PlotManager = newLinkableChild(this, PlotManager);

		
		/*******************************
		 **  backwards compatibility  **
		 *******************************/
		
		[Deprecated] public function set layers(array:Array):void
		{
			plotManager.plotters.delayCallbacks();
			plotManager.layerSettings.delayCallbacks();
			
			var dynamicState:Object;
			var removeMissingDynamicObjects:Boolean = (WeaveAPI.SessionManager as SessionManager).deprecatedSetterShouldRemoveMissingDynamicObjects;
			
			if (removeMissingDynamicObjects)
				plotManager.plotters.removeAllObjects();
			
			for each (dynamicState in array)
			{
				if (dynamicState is String)
					continue;
				if (deprecatedLayerNames.indexOf(dynamicState.objectName) >= 0)
					continue;
				
				var layerState:Object = dynamicState.sessionState;
				var plotterState:Object = null;
				if (layerState && layerState.plotter is Array && layerState.plotter.length)
				{
					plotterState = layerState.plotter[0];
					var className:String = plotterState.className;
					var plotterClass:Class = ClassUtils.getClassDefinition(className);
					if (plotterClass)
						plotManager.plotters.requestObject(dynamicState.objectName, plotterClass, false);
					
					var plotter:ILinkableObject = plotManager.plotters.getObject(dynamicState.objectName);
					var settings:ILinkableObject = plotManager.getLayerSettings(dynamicState.objectName);
					if (plotter && plotterState)
					{
						try {
							var sps:Array = plotterState.sessionState.symbolPlotters;
							for each (var sp:Object in sps)
							{
								try {
									sp.sessionState.filteredKeySet = sp.sessionState.keySet;
								} catch (e:Error) { }
							}
						} catch (e:Error) { }
						setSessionState(plotter, plotterState.sessionState, removeMissingDynamicObjects);
					}
					if (settings)
						setSessionState(settings, layerState, removeMissingDynamicObjects);
				}
			}
			
			plotManager.plotters.resumeCallbacks();
			plotManager.layerSettings.resumeCallbacks();
		}
		
		private static const deprecatedLayerNames:Array = ["undefinedX", "undefinedY", "undefinedXY"];
		
		[Deprecated] public function set zoomBounds(value:Object):void { plotManager.zoomBounds.setSessionState(value); }
		
		[Deprecated] public function set marginRight(value:String):void { plotManager.marginRight.value = value; }
		[Deprecated] public function set marginLeft(value:String):void { plotManager.marginLeft.value = value; }
		[Deprecated] public function set marginTop(value:String):void { plotManager.marginTop.value = value; }
		[Deprecated] public function set marginBottom(value:String):void { plotManager.marginBottom.value = value; }
		
		[Deprecated] public function set minScreenSize(value:Number):void { plotManager.minScreenSize.value = value; }
		[Deprecated] public function set minZoomLevel(value:Number):void { plotManager.minZoomLevel.value = value; }
		[Deprecated] public function set maxZoomLevel(value:Number):void { plotManager.maxZoomLevel.value = value; }
		[Deprecated] public function set enableFixedAspectRatio(value:Boolean):void { plotManager.enableFixedAspectRatio.value = value; }
		[Deprecated] public function set enableAutoZoomToExtent(value:Boolean):void { plotManager.enableAutoZoomToExtent.value = value; }
		[Deprecated] public function set enableAutoZoomToSelection(value:Boolean):void { plotManager.enableAutoZoomToSelection.value = value; }
		[Deprecated] public function set includeNonSelectableLayersInAutoZoom(value:Boolean):void { plotManager.includeNonSelectableLayersInAutoZoom.value = value; }
		[Deprecated] public function set overrideXMin(value:Number):void { plotManager.overrideXMin.value = value; }
		[Deprecated] public function set overrideYMin(value:Number):void { plotManager.overrideYMin.value = value; }
		[Deprecated] public function set overrideXMax(value:Number):void { plotManager.overrideXMax.value = value; }
		[Deprecated] public function set overrideYMax(value:Number):void { plotManager.overrideYMax.value = value; }
		
		[Deprecated] public function get fullDataBounds():IBounds2D { return plotManager.fullDataBounds; }
		[Deprecated] public function get zoomToSelection():Function { return plotManager.zoomToSelection; }
		[Deprecated] public function get getZoomLevel():Function { return plotManager.getZoomLevel; }
		[Deprecated] public function get setZoomLevel():Function { return plotManager.setZoomLevel; }
		[Deprecated] public function get getKeysOverlappingGeometry():Function { return plotManager.getKeysOverlappingGeometry; }
		
		[Deprecated] public function set dataBounds(value:Object):void { plotManager.zoomBounds.setSessionState(value); }
	}
}
