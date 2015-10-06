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

package weave.visualization.tools
{
	import flash.events.Event;
	
	import mx.binding.utils.BindingUtils;
	import mx.containers.Canvas;
	import mx.containers.VBox;
	import mx.core.UIComponent;
	
	import weave.Weave;
	import weave.api.core.ILinkableHashMap;
	import weave.api.data.IQualifiedKey;
	import weave.api.data.ISimpleGeometry;
	import weave.api.getCallbackCollection;
	import weave.api.getLinkableDescendants;
	import weave.api.getLinkableOwner;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IInitSelectableAttributes;
	import weave.api.ui.ILinkableContainer;
	import weave.api.ui.IPlotter;
	import weave.api.ui.IPlotterWithGeometries;
	import weave.api.ui.ISelectableAttributes;
	import weave.api.ui.IVisTool;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableHashMap;
	import weave.core.UIUtils;
	import weave.editors.SimpleAxisEditor;
	import weave.editors.WindowSettingsEditor;
	import weave.editors.managers.LayerListComponent;
	import weave.ui.DraggablePanel;
	import weave.ui.Paragraph;
	import weave.ui.PenTool;
	import weave.utils.ColumnUtils;
	import weave.visualization.layers.LayerSettings;
	import weave.visualization.layers.SimpleInteractiveVisualization;
	import weave.visualization.plotters.SimpleAxisPlotter;

	/**
	 * A simple visualization is one with a single SelectablePlotLayer
	 * 
	 * @author adufilie
	 */
	public class SimpleVisTool extends DraggablePanel implements IVisTool, IInitSelectableAttributes, ILinkableContainer
	{
		public function SimpleVisTool()
		{
			// Don't put any code here.
			// Put code in the inConstructor() function instead.
		}

		override protected function inConstructor():void
		{
			super.inConstructor();
			
			// lock an InteractiveVisualization onto the panel
			_visualization = children.requestObject("visualization", SimpleInteractiveVisualization, true);
			
			_visualization.addEventListener(Event.RESIZE, handleVisualizationResize);
			function handleVisualizationResize(event:Event):void
			{
				invalidateDisplayList();
			}
			getCallbackCollection(Weave.properties.visTitleTextFormat).addGroupedCallback(this, updateTitleLabel, true);
		}

		public const enableTitle:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), handleTitleToggleChange, true);
		public const children:LinkableHashMap = newLinkableChild(this, LinkableHashMap);

		private var toolVBox:VBox; // simpleVisToolVBox contains titleLabel and visCanvas
		private var visTitle:Paragraph; // For display of title inside the window area
		protected var visCanvas:Canvas; // For linkDisplayObjects
		private var _visualization:SimpleInteractiveVisualization;
		internal var layersEditor:LayerListComponent;
		internal var axesEditor:SimpleAxisEditor;
		internal var windowEditor:WindowSettingsEditor;
		
		override protected function createChildren():void
		{
			if (createdChildren)
				return;
			
			super.createChildren();
			
			toolVBox = new VBox();
			toolVBox.percentHeight = 100;
			toolVBox.percentWidth = 100;
			toolVBox.setStyle("verticalGap", 0);
			toolVBox.setStyle("horizontalAlign", "center");
			
			visTitle = new Paragraph();
			visTitle.setStyle('textAlign', 'center');
			updateTitleLabel();
			
			visCanvas = new Canvas();
			visCanvas.percentHeight = 100;
			visCanvas.percentWidth = 100;
			toolVBox.addChild(visCanvas);
			
			UIUtils.linkDisplayObjects(visCanvas, children);
			
			var flexChildren:Array = getChildren();
			removeAllChildren();
			
			for ( var i:int = 0; i < flexChildren.length; i++ )
				visCanvas.addChild(flexChildren[i]);
			
			this.addChild(toolVBox);
		}
		
		override protected function childrenCreated():void
		{
			super.childrenCreated();
			
			BindingUtils.bindSetter(handleBindableTitle, this, 'title');
		}
		
		override protected function initControlPanel():void
		{
			super.initControlPanel();
			
			layersEditor = new LayerListComponent();
			layersEditor.visualization = visualization;
			
			//TODO: hide axis controls when axis isn't enabled

			axesEditor = new SimpleAxisEditor();
			axesEditor.setTargets(visualization, enableTitle, panelTitle);
			
			windowEditor = new WindowSettingsEditor();
			windowEditor.target = this;
			
			if (controlPanel)
				controlPanel.children = [layersEditor, axesEditor, windowEditor];
		}
		
		private function handleBindableTitle(value:String):void
		{
			visTitle.text = title;
		}
		private function updateTitleLabel():void
		{
			if (!createdChildren)
				return callLater(updateTitleLabel);
			
			Weave.properties.visTitleTextFormat.copyToStyle(visTitle);
		}
		
		
		/**
		 * This function should be defined with override by subclasses.
		 * @return An Array of names corresponding to the objects returned by getSelectableAttributes().
		 */		
		public function getSelectableAttributeNames():Array
		{
			var obj:ISelectableAttributes = mainPlotter as ISelectableAttributes;
			if (obj)
				return obj.getSelectableAttributeNames();
			
			var descendants:Array = visualization.plotManager.plotters.getObjects(ISelectableAttributes);
			return [].concat.apply(null, descendants.map(function(descendant:ISelectableAttributes, i:int, a:Array):Array {
				var owner:ILinkableHashMap = getLinkableOwner(descendant);
				if (!owner)
					return [];
				var descendantName:String = owner.getName(descendant);
				return descendant.getSelectableAttributeNames().map(function(attrName:String, i:int, a:Array):String {
					if (descendants.length == 1)
						return attrName;
					// translate the name by itself
					var translated:String = lang(attrName);
					// TODO - attribute selector needs option to not translate these names (since this is already translated)
					return lang("{0} ({1})", translated, descendantName);
				});
			}));
		}

		/**
		 * This function should be defined with override by subclasses.
		 * @return An Array of DynamicColumn and/or ILinkableHashMap objects that an AttributeSelectorPanel can link to.
		 */		
		public function getSelectableAttributes():Array
		{
			var obj:ISelectableAttributes = mainPlotter as ISelectableAttributes;
			if (obj)
				return obj.getSelectableAttributes();
			
			var descendants:Array = visualization.plotManager.plotters.getObjects(ISelectableAttributes);
			return [].concat.apply(null, descendants.map(function(descendant:ISelectableAttributes, i:int, a:Array):Array {
				return descendant.getSelectableAttributes();
			}));
		}

		private function updateToolWindowSettings():void
		{
			creationPolicy = "all"; // this prevents ui components from being null in childrenCreated()
			horizontalScrollPolicy = "off";
			verticalScrollPolicy = "off";
		}
		
		private function handleTitleToggleChange():void
		{
			if (!createdChildren)
			{
				callLater(handleTitleToggleChange);
				return;
			}
			if (!enableTitle.value)
			{
				if (toolVBox == visTitle.parent)
					toolVBox.removeChild(visTitle);
			}
			else
			{
				if (toolVBox != visTitle.parent)
					toolVBox.addChildAt(visTitle,0);
			}
		}
		
		private const MIN_TOOL_WIDTH:int  = 250;
		private const MIN_TOOL_HEIGHT:int = 250;
		
		// NOT WORKING YET -- the intention is to scale the things inside a tool if the size is below a certain value
		// this would scale the UI and vis
		override public function set width(value:Number):void
		{
			/*var scale:Number = calculateScale();
			
			if(scale < 1)
			{
				for each(var child:UIComponent in getChildren())
				{
					child.scaleX = scale;
					child.scaleY = scale;
				}
			}
			else
			{*/
				super.width = value;
			//}
		}
		override public function set height(value:Number):void
		{
			/*var scale:Number = calculateScale();
			
			if(scale < 1)
			{
				for each(var child:UIComponent in getChildren())
				{
					child.scaleX = scale;
					child.scaleY = scale;
				}
			}
			else
			{*/
				super.height = value;
			//}
		}
		private function calculateScale():Number
		{
			var childScale:Number = 1;
			for each(var child:UIComponent in getChildren())
			{
				var widthScale:Number  = Math.min(1, (child.width  / child.scaleX) / MIN_TOOL_WIDTH);
				var heightScale:Number = Math.min(1, (child.height / child.scaleY) / MIN_TOOL_HEIGHT);
				
				// if the width scale is the smallest so far, set the returned value to this
				if(widthScale < childScale)
					childScale = widthScale;
				// if the height scale is the smallest so far, set the returned value to this
				if(heightScale < childScale)
					childScale = heightScale;
			}
			
			return childScale;
		}
		
		/**
		 * @inheritDoc
		 */
		public function initSelectableAttributes(input:Array):void
		{
			ColumnUtils.initSelectableAttributes(getSelectableAttributes(), input);
		}
		
		/**
		 * This function will return an array of IQualifiedKey objects which overlap
		 * the geometries of the layer specified by <code>layerName</code>.
		 * 
		 * @param layerName The name of the layer with the geometries used for the query.
		 */		
		public function getOverlappingQKeys(layerName:String):Array
		{
			var key:IQualifiedKey;
			var simpleGeometries:Array = [];
			var simpleGeometry:ISimpleGeometry;
			
			// First check the children to see if the specified layer is a penTool
			var penTool:PenTool = children.getObject(layerName) as PenTool;
			if (penTool)
			{
				return penTool.getOverlappingKeys();
			}
			
			var plotter:IPlotter = visualization.plotManager.getPlotter(layerName);
			var polygonPlotter:IPlotterWithGeometries = plotter as IPlotterWithGeometries;
			if (!polygonPlotter)
				return [];
			
			return visualization.getKeysOverlappingGeometry( polygonPlotter.getBackgroundGeometries() || [] );
		}
		
		/**
		 * This function will set the defaultSelectionKeySet to contain the keys
		 * which overlap the geometries specified by the layer called <code>layerName</code>.
		 * 
		 * @param layerName The name of the layer with the geometries used for the query.
		 */
		public function selectRecords(layerName:String):void
		{
			var keys:Array = getOverlappingQKeys(layerName);
			Weave.defaultSelectionKeySet.replaceKeys(keys);
		}
		
		/**
		 * @param mainPlotterClass The main plotter class definition.
		 * @param showAxes Set to true if axes should be added.
		 * @return The main plotter.
		 */		
		protected function initializePlotters(mainPlotterClass:Class, showAxes:Boolean):*
		{
			return visualization.initializePlotters(mainPlotterClass, showAxes);
		}

		protected function get mainLayerSettings():LayerSettings
		{
			return visualization.getMainLayerSettings();
		}
		protected function get mainPlotter():IPlotter
		{
			return visualization.getMainPlotter();
		}
		protected function get xAxisPlotter():SimpleAxisPlotter
		{
			return visualization.getXAxisPlotter();
		}
		protected function get yAxisPlotter():SimpleAxisPlotter
		{
			return visualization.getYAxisPlotter();
		}
		
		// returns the interactive visualization
		public function get visualization():SimpleInteractiveVisualization
		{
			return _visualization;
		}
		
		// UI children
		public function getLinkableChildren():ILinkableHashMap { return children; }
		
		override public function dispose():void
		{
			super.dispose();
		}
	}
}
