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

package weave.menus
{
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;
	
	import mx.containers.TitleWindow;
	import mx.controls.Button;
	import mx.controls.Image;
	import mx.controls.Label;
	import mx.core.IToolTip;
	import mx.core.UIComponent;
	import mx.events.CloseEvent;
	import mx.managers.PopUpManager;
	import mx.managers.ToolTipManager;
	
	import spark.components.Group;
	import spark.layouts.HorizontalLayout;
	
	import weave.Weave;
	import weave.api.core.ICallbackCollection;
	import weave.api.core.ILinkableObject;
	import weave.api.getCallbackCollection;
	import weave.api.objectWasDisposed;
	import weave.api.ui.IInitSelectableAttributes;
	import weave.api.ui.IVisTool;
	import weave.api.ui.IVisTool_Basic;
	import weave.api.ui.IVisTool_R;
	import weave.api.ui.IVisTool_Utility;
	import weave.core.ClassUtils;
	import weave.ui.AddExternalTool;
	import weave.ui.ColorController;
	import weave.ui.DraggablePanel;
	import weave.ui.ProbeToolTipEditor;
	import weave.ui.ProbeToolTipWindow;
	import weave.ui.collaboration.CollaborationEditor;
	import weave.utils.ColumnUtils;
	import weave.visualization.tools.Histogram2DTool;
	import weave.visualization.tools.HistogramTool;
	import weave.visualization.tools.ScatterPlotTool;
	import spark.layouts.VerticalLayout;

	public class ToolsMenu extends WeaveMenuItem
	{
		private static function openStaticInstance(item:WeaveMenuItem):void
		{
			DraggablePanel.openStaticInstance(item.data as Class);
		}
		public static function openPopup():void
		{
			// create and configure the TitleWindow
			var tw:TitleWindow = new TitleWindow();
			tw.title = "Visualization Picker";
			tw.showCloseButton = true;
			tw.addEventListener(Event.CLOSE, closeTitleWindow);
			// create and configure a Label
			var label:Label = new Label();
			label.text = "Select a visualization from below:";
			// add images
			var histo: Image = new Image();
			histo.source = "histogram.png";
			histo.addEventListener(MouseEvent.CLICK, makeHistogram);
			histo.height = 64;
			histo.width = 64;
			
			var scatter: Image = new Image();
			scatter.source = "scatterplot.png";
			scatter.addEventListener(MouseEvent.CLICK, makeScatter);
			scatter.height = 64;
			scatter.width = 64;
			// image labels
			var histoLabel:Label = new Label();
			histoLabel.text = "Histogram";
			
			var scatterLabel:Label = new Label();
			scatterLabel.text = "Scatter Plot";
			// Graph combos
			var histoGroup: Group = new Group();
			histoGroup.layout = new VerticalLayout();
			histoGroup.addElement(histo);
			histoGroup.addElement(histoLabel);
			
			var scatterGroup: Group = new Group();
			scatterGroup.layout = new VerticalLayout();
			scatterGroup.addElement(scatter);
			scatterGroup.addElement(scatterLabel);
			// Image layout
			var group: Group = new Group();
			group.layout = new HorizontalLayout();
			group.addElement(histoGroup);
			group.addElement(scatterGroup);

			// add the Label to the TitleWindow
			tw.addChild(label);
			tw.addChild(group);
			// open the TitleWindow as a modal popup window
			PopUpManager.addPopUp(tw, WeaveAPI.topLevelApplication as UIComponent);
			PopUpManager.centerPopUp(tw);
		}
		// method to close the TitleWindow targeted by a close event
		private static function closeTitleWindow(evt:CloseEvent):void {
			PopUpManager.removePopUp(TitleWindow(evt.target));
		}
		private static function makeHistogram(evt:MouseEvent):void {
			createGlobalObject(new WeaveMenuItem({
				shown: Weave.properties.getMenuToggle(HistogramTool),
				label: "Histogram",
				click: createGlobalObject,
				data: HistogramTool
			}));
		}
		private static function makeScatter(evt:MouseEvent):void {
			createGlobalObject(new WeaveMenuItem({
				shown: Weave.properties.getMenuToggle(ScatterPlotTool),
				label: "Scatter",
				click: createGlobalObject,
				data: ScatterPlotTool
			}));
		}
		public static function createGlobalObject(item:WeaveMenuItem):ILinkableObject
		{
			Weave.properties.dashboardMode.value = false;
			
			var classDef:Class = item.data is Array ? item.data[0] : item.data as Class;
			var name:String = item.data is Array ? item.data[1] : null;
			
			var className:String = getQualifiedClassName(classDef).split("::").pop();
			
			if (name == null)
				name = WeaveAPI.globalHashMap.generateUniqueName(className);
			var object:ILinkableObject = WeaveAPI.globalHashMap.requestObject(name, classDef, false);
			
			// put panel in front
			WeaveAPI.globalHashMap.setNameOrder([name]);
			
			var iisa:IInitSelectableAttributes = object as IInitSelectableAttributes;
			if (iisa)
				iisa.initSelectableAttributes(ColumnUtils.getColumnsWithCommonKeyType());
			
			// add "Start here" tip for a panel
			var dp:DraggablePanel = object as DraggablePanel;
			if (dp)
				dp.onUserCreation();
			
			return object;
		}
		public static function handleDraggablePanelAdded(dp:DraggablePanel):void
		{
			if (objectWasDisposed(dp) || !dp.parent)
				return;
			
			dp.validateNow();
			var dpc:ICallbackCollection = getCallbackCollection(dp);
			
			var b:Button = dp.userControlButton;
			if (!b.parent)
				b = dp.subMenuButton;
			if (!b.parent)
				b = dp.attributeButton;
			if (!b.parent)
				b = dp.toggleButton;
			
			var color:uint = 0x0C4785;//0x0b333c;
			var timeout:int = getTimer() + 1000 * 5;
			var tip:UIComponent = ToolTipManager.createToolTip(lang("Start here"), 0, 0, null, dp) as UIComponent;
			Weave.properties.panelTitleTextFormat.copyToStyle(tip);
			tip.setStyle('color', 0xFFFFFF);
			tip.setStyle('fontWeight', 'bold');
			tip.setStyle('borderStyle', "errorTipBelow");
			tip.setStyle("backgroundColor", color);
			tip.setStyle("borderColor", color);
			tip.setStyle('borderSkin', CustomToolTipBorder);
			var callback:Function = function():void {
				var p:Point = b.localToGlobal(new Point(0, b.height + 5));
				tip.move(int(p.x), int(p.y));
				tip.visible = !!b.parent;
				if (getTimer() > timeout)
					removeTip();
			};
			var removeTip:Function = function(..._):void {
				ToolTipManager.destroyToolTip(tip as IToolTip);
				WeaveAPI.StageUtils.removeEventCallback(Event.ENTER_FRAME, callback);
				dpc.removeCallback(removeTip);
				b.removeEventListener(MouseEvent.ROLL_OVER, removeTip);
			};
			b.addEventListener(MouseEvent.ROLL_OVER, removeTip);
			dpc.addDisposeCallback(null, removeTip);
			WeaveAPI.StageUtils.addEventCallback(Event.ENTER_FRAME, dp, callback, true);
		}
		
		public static const staticItems:Array = createItems([
			{
				shown: [Weave.properties.showColorController],
				label: lang("Create Histogram"),
				click: createGlobalObject,
				data: HistogramTool
			},{
				shown: [Weave.properties.showProbeToolTipEditor],
				label: lang("Select Visualization"),
				click: openPopup,
				data: ProbeToolTipEditor
			},{
				shown: [Weave.properties.showProbeWindow],
				label: lang("Show Mouseover Window"),
				click: createGlobalObject,
				data: [ProbeToolTipWindow, "ProbeToolTipWindow"]
			},{
				shown: [Weave.properties.showCollaborationEditor],
				label: lang("Collaboration Settings"),
				click: openStaticInstance,
				data: CollaborationEditor
			},{
				shown: [Weave.properties.showAddExternalTools],
				label: lang("Add external tool..."),
				click: AddExternalTool.show
			}
		]);
		
		public static function getVisToolDisplayName(implementation:Class):String
		{
			var displayName:String = WeaveAPI.ClassRegistry.getDisplayName(implementation);
			if (ClassUtils.classImplements(getQualifiedClassName(implementation), getQualifiedClassName(IVisTool_R)))
				return lang("{0} ({1})", displayName, lang("Requires Rserve"));
			return displayName;
		}
		
		/**
		 * Gets an Array of WeaveMenuItem objects for creating IVisTools.
		 * @param labelFormat A format string to be passed to lang().
		 * @param itemVistor A function like function(item:WeaveMenuItem):void that will be called for each tool menu item.
		 * @param flatList Set this to true to get a flat list of items rather than a nested menu structure.
		 */
		public static function getDynamicItems(labelFormat:String = null, itemVisitor:Function = null, flatList:Boolean = false):Array
		{
			function getToolItemLabel(item:WeaveMenuItem):String
			{
				var displayName:String = getVisToolDisplayName(item.data as Class);
				return labelFormat ? lang(labelFormat, displayName) : displayName;
			}
			return createItems(
				ClassUtils.partitionClassList(
					WeaveAPI.ClassRegistry.getImplementations(IVisTool),
					IVisTool_Basic,
					IVisTool_Utility,
					IVisTool_R
				).map(
					function(group:Array, iGroup:int, groups:Array):* {
						var items:Array = group.map(
							function(impl:Class, i:int, a:Array):* {
								var item:WeaveMenuItem = new WeaveMenuItem({
									shown: Weave.properties.getMenuToggle(impl),
									label: getToolItemLabel,
									click: createGlobalObject,
									data: impl
								});
								if (itemVisitor != null)
									itemVisitor(item);
								return item;
							}
						);
						if (!flatList && iGroup == groups.length - 1)
							return {
								shown: function():Boolean { return this.children.length > 0 },
								label: lang('Other tools'),
								children: items
							};
						return items;
					}
				)
			);
		}
		
		public function ToolsMenu()
		{
			super({
				dependency: Weave.properties.menuToggles.childListCallbacks,
				shown: Weave.properties.enableDynamicTools,
				label: lang("Tools"),
				children: function():Array
				{
					return createItems([
						staticItems,
						getDynamicItems("+ {0}")
					]);
				}
			});
		}
	}
}

import flash.display.Graphics;

import mx.skins.halo.ToolTipBorder;

/**
 * Modifies behavior of borderStyle="errorTipBelow" so the arrow appears close to the left side.
 */
internal class CustomToolTipBorder extends ToolTipBorder
{
	override protected function updateDisplayList(w:Number, h:Number):void
	{
		super.updateDisplayList(w, h);
		
		var borderStyle:String = getStyle("borderStyle");
		
		if (borderStyle == "errorTipBelow")
		{
			var backgroundColor:uint = getStyle("backgroundColor");
			var backgroundAlpha:Number= getStyle("backgroundAlpha");
			var borderColor:uint = getStyle("borderColor");
			var cornerRadius:Number = getStyle("cornerRadius");
			
			var g:Graphics = graphics;
			g.clear();
			var radius:int = 3;
			// border
			drawRoundRect(0, 11, w, h - 13, radius, borderColor, backgroundAlpha);
			// top pointer 
			g.beginFill(borderColor, backgroundAlpha);
			g.moveTo(radius + 0, 11);
			g.lineTo(radius + 6, 0);
			g.lineTo(radius + 12, 11);
			g.moveTo(radius, 11);
			g.endFill();
		}
	}
}
