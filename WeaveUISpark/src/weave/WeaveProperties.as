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

package weave
{
	import flash.display.Stage;
	import flash.events.Event;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.net.URLRequest;
	import flash.text.Font;
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	
	import mx.collections.ArrayCollection;
	import mx.controls.ToolTip;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.StringUtil;
	
	import ru.etcs.utils.FontLoader;
	
	import weave.api.copySessionState;
	import weave.api.core.ICallbackCollection;
	import weave.api.core.ILinkableHashMap;
	import weave.api.core.ILinkableObject;
	import weave.api.core.ILinkableObjectWithNewProperties;
	import weave.api.disposeObject;
	import weave.api.linkBindableProperty;
	import weave.api.registerDisposableChild;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.api.setSessionState;
	import weave.api.ui.IVisTool_R;
	import weave.compiler.StandardLib;
	import weave.core.CallbackCollection;
	import weave.core.ClassUtils;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableFunction;
	import weave.core.LinkableHashMap;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.core.LinkableVariable;
	import weave.core.SessionManager;
	import weave.data.AttributeColumns.SecondaryKeyNumColumn;
	import weave.data.AttributeColumns.StreamedGeometryColumn;
	import weave.services.WeaveRServlet;
	import weave.services.addAsyncResponder;
	import weave.utils.CSSUtils;
	import weave.utils.LinkableTextFormat;
	import weave.utils.NumberUtils;
	import weave.utils.ProbeTextUtils;
	import weave.visualization.layers.InteractionController;
	import weave.visualization.layers.LinkableEventListener;
	import weave.visualization.layers.filters.LinkableDropShadowFilter;
	import weave.visualization.layers.filters.LinkableGlowFilter;

	/**
	 * A list of global settings for a Weave instance.
	 */
	public class WeaveProperties implements ILinkableObject, ILinkableObjectWithNewProperties
	{
		[Embed(source="/weave/weave_version.txt", mimeType="application/octet-stream")]
		private static const WeaveVersion:Class;
		
		public const version:LinkableString = new LinkableString(); // Weave version
		
		public function WeaveProperties()
		{
			version.value = StringUtil.trim((new WeaveVersion() as ByteArray).toString());
			version.lock(); // don't allow changing the version
			
			// register all properties as children of this object
			for each (var propertyName:String in (WeaveAPI.SessionManager as SessionManager).getLinkablePropertyNames(this))
				registerLinkableChild(this, this[propertyName] as ILinkableObject);
			
			loadWeaveFontsSWF();
			visTextFormat.size.value = 11;
			axisTitleTextFormat.size.value = 13;
			visTitleTextFormat.size.value = 16;

			// handle dynamic changes to the session state that change what CSS file to use
			cssStyleSheetName.addGroupedCallback(
				this,
				function():void
				{
					CSSUtils.loadStyleSheet(cssStyleSheetName.value);
				}
			);

//			_toggleMenuItem("ThermometerTool", false);
//			_toggleMenuItem("GaugeTool", false);
			_toggleMenuItem("TreeTool", false);
			_toggleMenuItem("CytoscapeWebTool", false);
			_toggleMenuItem("CustomGraphicsTool", false);
			_toggleMenuItem("KeyMappingTool", false);
			_toggleMenuItem("RDataSource", false);
			
			panelTitleTextFormat.font.value = "Verdana";
			panelTitleTextFormat.size.value = 10;
			panelTitleTextFormat.color.value = 0xFFFFFF;
			
			linkBindableProperty(maxComputationTimePerFrame, WeaveAPI.StageUtils, 'maxComputationTimePerFrame');
			
			showCollaborationMenuItem.addGroupedCallback(this, function():void {
				if (showCollaborationMenuItem.value)
				{
					enableCollaborationBar.delayCallbacks();
					showCollaborationEditor.delayCallbacks();
					
					enableCollaborationBar.value = false;
					showCollaborationEditor.value = false;
					
					enableCollaborationBar.resumeCallbacks();
					showCollaborationEditor.resumeCallbacks();
				}
			});
			function handleCollabBar():void
			{
				if (enableCollaborationBar.value || showCollaborationEditor.value)
					showCollaborationMenuItem.value = false;
			};
			enableCollaborationBar.addGroupedCallback(this, handleCollabBar);
			showCollaborationEditor.addGroupedCallback(this, handleCollabBar);
			initBitmapFilterCallbacks();
		}
		
		public static const embeddedFonts:ArrayCollection = new ArrayCollection();
		private function loadWeaveFontsSWF(bytes:ByteArray = null):void
		{
			if (!bytes)
			{
				try
				{
					// attempt to load from embedded file
					var WF:Class = getDefinitionByName('WeaveFonts') as Class;
					bytes = (new WF()) as ByteArray;
				}
				catch (e:Error) { }
			}
			if (bytes)
			{
				var fontLoader:FontLoader = new FontLoader();
				fontLoader.addEventListener(
					Event.COMPLETE,
					function(event:Event):void
					{
						try
						{
							var fonts:Array = fontLoader.fonts;
							for each (var font:Font in fonts)
							{
								var fontClass:Class = Object(font).constructor;
								Font.registerFont(fontClass);
								if (!embeddedFonts.contains(font.fontName))
									embeddedFonts.addItem(font.fontName);
							}
						}
						catch (e:Error)
						{
							var app:Object = WeaveAPI.topLevelApplication;
							if (app.parent && app.parent.parent is Stage) // don't report error if loaded as a nested app
								reportError(e);
						}
					}
				);
				fontLoader.loadBytes(bytes, false);
			}
			else
			{
				addAsyncResponder(
					WeaveAPI.URLRequestUtils.getURL(null, new URLRequest('WeaveFonts.swf')),
					function(event:ResultEvent, token:Object = null):void
					{
						var bytes:ByteArray = ByteArray(event.result);
						if (bytes)
							loadWeaveFontsSWF(bytes);
						else
							reportError("Unable to get WeaveFonts.swf");
					},
					function(event:FaultEvent, token:Object = null):void
					{
						reportError(event.fault);
					}
				);
			}
		}
		
		public static const DEFAULT_BACKGROUND_COLOR:Number = 0xCCCCCC;
		
		private static const WIKIPEDIA_URL:String = "Wikipedia|http://en.wikipedia.org/wiki/Special:Search?search=";
		private static const GOOGLE_URL:String = "Google|http://www.google.com/search?q=";
		private static const GOOGLE_MAPS_URL:String = "Google Maps|http://maps.google.com/maps?t=h&q=";
		private static const GOOGLE_IMAGES_URL:String = "Google Images|http://images.google.com/images?q=";
		
		private function verifyAlpha(value:Number):Boolean { return 0 <= value && value <= 1; }
		private function verifyWindowSnapGridSize(value:String):Boolean
		{
			if (!NumberUtils.verifyNumberOrPercentage(value))
				return false;
			if (value && value.substr(-1) == '%')
				return StandardLib.asNumber(value.substr(0, -1)) > 0;
			return StandardLib.asNumber(value) >= 1;
		}
		
		public const showErrors:LinkableBoolean = new LinkableBoolean(true);
		
		public const dataInfoURL:LinkableString = new LinkableString(); // file to link to for metadata information
		
		public const windowSnapGridSize:LinkableString = new LinkableString("1%", verifyWindowSnapGridSize); // window snap grid size in pixels
		
		public const cssStyleSheetName:LinkableString = new LinkableString("weaveStyle.css"); // CSS Style Sheet Name/URL
		public const backgroundColor:LinkableNumber = new LinkableNumber(DEFAULT_BACKGROUND_COLOR, isFinite);
		public const showBackgroundImage:LinkableBoolean = new LinkableBoolean(true);
		public const panelBackgroundColor:LinkableNumber = new LinkableNumber(0xFFFFFF, isFinite);
		
		public const enableMouseWheel:LinkableBoolean = new LinkableBoolean(true);
		
		// Collaboration
		public const enableCollaborationBar:LinkableBoolean = new LinkableBoolean(false); // collaboration menu bar (bottom of screen)
		public const showCollaborationEditor:LinkableBoolean = new LinkableBoolean(false); // menu item
		public const collabServerIP:LinkableString = new LinkableString("demo.iweave.com");
		public const collabServerName:LinkableString = new LinkableString("ivpr-vm");
		public const collabServerPort:LinkableString = new LinkableString("5222");
		public const collabServerRoom:LinkableString = new LinkableString("");
		public const collabSpectating:LinkableBoolean = new LinkableBoolean(false);
		public const showCollaborationMenuItem:LinkableBoolean = new LinkableBoolean(true); // menu item
		
		public const enableDynamicTools:LinkableBoolean = new LinkableBoolean(true); // tools menu
		public const showColorController:LinkableBoolean = new LinkableBoolean(true); // Show Color Controller option tools menu
		public const showProbeToolTipEditor:LinkableBoolean = new LinkableBoolean(true);  // Show Probe Tool Tip Editor tools menu
		public const showProbeWindow:LinkableBoolean = new LinkableBoolean(true); // Show Probe Tool Tip Window in tools menu
		public const showEquationEditor:LinkableBoolean = new LinkableBoolean(true); // Show Equation Editor option tools menu
		public const showKMeansClustering:LinkableBoolean = new LinkableBoolean(false);
		public const showAddExternalTools:LinkableBoolean = new LinkableBoolean(false); // Show Add External Tools dialog in tools menu.
		
		public const menuToggles:ILinkableHashMap = new LinkableHashMap(LinkableBoolean); // className -> LinkableBoolean
		public function getMenuToggle(classDef:Class):LinkableBoolean
		{
			var className:String = getQualifiedClassName(classDef).split('::').pop();
			var existsPreviously:Boolean = menuToggles.getObject(className) is LinkableBoolean;
			var toggle:LinkableBoolean = menuToggles.requestObject(className, LinkableBoolean, false);
			var deprecatedToggle:LinkableBoolean = menuToggles.getObject(toolToggleBackwardsCompatibility[className]) as LinkableBoolean;
			if (!existsPreviously)
			{
				if (deprecatedToggle)
				{
					// backwards compatibility for old session states
					toggle.value = deprecatedToggle.value;
					menuToggles.removeObject(toolToggleBackwardsCompatibility[className]);
				}
				else
				{
					// set default value
					var is_r_tool:Boolean = ClassUtils.classImplements(getQualifiedClassName(classDef), getQualifiedClassName(IVisTool_R));
					toggle.value = !is_r_tool;
				}
			}
			return toggle;
		}
		// maps new tool name to old tool name
		private const toolToggleBackwardsCompatibility:Object = {
			"AdvancedDataTable": "DataTableTool",
			"TableTool": "DataTableTool"
		};

		public const enableToolAttributeEditing:LinkableBoolean = new LinkableBoolean(true);
		public const enableToolSelection:LinkableBoolean = new LinkableBoolean(true);
		public const enableToolProbe:LinkableBoolean = new LinkableBoolean(true);
		public const showVisToolCloseDialog:LinkableBoolean = new LinkableBoolean(false);
		
		public const enableRightClick:LinkableBoolean = new LinkableBoolean(true);
		
		public const maxTooltipRecordsShown:LinkableNumber = new LinkableNumber(1, verifyNonNegativeNumber); // maximum number of records shown in the probe toolTips
		public const showSelectedRecordsText:LinkableBoolean = new LinkableBoolean(true); // show the tooltip in the lower-right corner of the application
		public const enableBitmapFilters:LinkableBoolean = new LinkableBoolean(true); // enable/disable bitmap filters while probing or selecting
		public const enableGeometryProbing:LinkableBoolean = new LinkableBoolean(true); // use the geometry probing (default to on even though it may be slow for mapping)
		public function get geometryMetadataRequestMode():LinkableString { return StreamedGeometryColumn.metadataRequestMode; }
		public function get geometryMinimumScreenArea():LinkableNumber { return StreamedGeometryColumn.geometryMinimumScreenArea; }
		
		public const enableSessionMenu:LinkableBoolean = new LinkableBoolean(true); // all sessioning
		public const enableManagePlugins:LinkableBoolean = new LinkableBoolean(false); // show "manage plugins" menu item
		public const enableSessionHistoryControls:LinkableBoolean = new LinkableBoolean(true); // show session history controls inside Weave interface
		public const showCreateTemplateMenuItem:LinkableBoolean = new LinkableBoolean(true);
		public const isTemplate:LinkableBoolean = new LinkableBoolean(false);

		public const enableUserPreferences:LinkableBoolean = new LinkableBoolean(true); // open the User Preferences Panel
		
		public const enableSearchForRecord:LinkableBoolean = new LinkableBoolean(true); // allow user to right click search for record
		
		public const enableMarker:LinkableBoolean = new LinkableBoolean(true);
		public const enableDrawCircle:LinkableBoolean = new LinkableBoolean(true);
		//public const enableAnnotation:LinkableBoolean = new LinkableBoolean(true);
		public const enablePenTool:LinkableBoolean = new LinkableBoolean(true);
		
		public const enableMenuBar:LinkableBoolean = new LinkableBoolean(true); // top menu for advanced features		
		public const enableSubsetControls:LinkableBoolean = new LinkableBoolean(true); // creating subsets
		public const enableExportToolImage:LinkableBoolean = new LinkableBoolean(true); // print/export tool images
		public const enableExportCSV:LinkableBoolean = new LinkableBoolean(true);
		public const enableExportApplicationScreenshot:LinkableBoolean = new LinkableBoolean(true); // print/export application screenshot
		
		public const enableDataMenu:LinkableBoolean = new LinkableBoolean(true); // enable/disable Data Menu
		public const enableBrowseData:LinkableBoolean = new LinkableBoolean(false); // enable/disable Browse Data option
		public const enableRefreshHierarchies:LinkableBoolean = new LinkableBoolean(false);
		public const enableManageDataSources:LinkableBoolean = new LinkableBoolean(true); // enable/disable Edit Datasources option
			
		public const enableWindowMenu:LinkableBoolean = new LinkableBoolean(true); // enable/disable Window Menu
		public const enableFullScreen:LinkableBoolean = new LinkableBoolean(false); // enable/disable FullScreen option
		public const enableCloseAllWindows:LinkableBoolean = new LinkableBoolean(true); // enable/disable Close All Windows
		public const enableRestoreAllMinimizedWindows:LinkableBoolean = new LinkableBoolean(true); // enable/disable Restore All Minimized Windows 
		public const enableMinimizeAllWindows:LinkableBoolean = new LinkableBoolean(true); // enable/disable Minimize All Windows
		public const enableCascadeAllWindows:LinkableBoolean = new LinkableBoolean(true); // enable/disable Cascade All Windows
		public const enableTileAllWindows:LinkableBoolean = new LinkableBoolean(true); // enable/disable Tile All Windows
		
		public const enableSelectionsMenu:LinkableBoolean = new LinkableBoolean(false);// enable/disable Selections Menu
		public const enableSaveCurrentSelection:LinkableBoolean = new LinkableBoolean(true);// enable/disable Save Current Selection option
		public const enableClearCurrentSelection:LinkableBoolean = new LinkableBoolean(true);// enable/disable Clear Current Selection option
		public const enableManageSavedSelections:LinkableBoolean = new LinkableBoolean(true);// enable/disable Manage Saved Selections option
		public const enableSelectionSelectorBox:LinkableBoolean = new LinkableBoolean(true); //enable/disable SelectionSelector option
		public const selectionMode:LinkableString = new LinkableString(InteractionController.SELECTION_MODE_RECTANGLE, verifySelectionMode);
		
		private function verifySelectionMode(value:String):Boolean { return InteractionController.enumSelectionMode().indexOf(value) >= 0; }
		
		public const enableSubsetsMenu:LinkableBoolean = new LinkableBoolean(false);// enable/disable Subsets Menu
		public const enableCreateSubsets:LinkableBoolean = new LinkableBoolean(true);// enable/disable Create subset from selected records option
		public const enableRemoveSubsets:LinkableBoolean = new LinkableBoolean(true);// enable/disable Remove selected records from subset option
		public const enableShowAllRecords:LinkableBoolean = new LinkableBoolean(true);// enable/disable Show All Records option
		public const enableSaveCurrentSubset:LinkableBoolean = new LinkableBoolean(true);// enable/disable Save current subset option
		public const enableManageSavedSubsets:LinkableBoolean = new LinkableBoolean(true);// enable/disable Manage saved subsets option
		public const enableSubsetSelectionBox:LinkableBoolean = new LinkableBoolean(true);// enable/disable Subset Selection Combo Box option
		
		
		public const enableWeaveAnalystMode:LinkableBoolean = new LinkableBoolean(false);// enable/disable use of the Weave Analyst
		public const dashboardMode:LinkableBoolean = new LinkableBoolean(false);	 // enable/disable borders/titleBar on windows
		public const enableToolControls:LinkableBoolean = new LinkableBoolean(true); // enable tool controls (which enables attribute selector too)
		public const enableAxisToolTips:LinkableBoolean = new LinkableBoolean(true);
		
		public const showKeyTypeInColumnTitle:LinkableBoolean = new LinkableBoolean(false);
		
		// probing and selection
		public const selectionAlphaAmount:LinkableNumber    = new LinkableNumber(0.5, verifyAlpha);
		
		//selection location information
		public const recordsTooltipLocation:LinkableString = new LinkableString(RECORDS_TOOLTIP_LOWER_LEFT, verifyLocationMode);
		
		public static const RECORDS_TOOLTIP_LOWER_LEFT:String = 'Lower left';
		public static const RECORDS_TOOLTIP_LOWER_RIGHT:String = 'Lower right';
		public function get recordsTooltipEnum():Array
		{
			return [RECORDS_TOOLTIP_LOWER_LEFT, RECORDS_TOOLTIP_LOWER_RIGHT];
		}
		
		private function verifyLocationMode(value:String):Boolean
		{
			return recordsTooltipEnum.indexOf(value) >= 0;
		}
		
		/**
		 * This is an array of LinkableEventListeners which specify a function to run on an event.
		 */
		public const eventListeners:LinkableHashMap = new LinkableHashMap(LinkableEventListener);
		
		public const dashedSelectionColor:LinkableNumber = new LinkableNumber(0x00ff00);
		public const dashedZoomColor:LinkableNumber = new LinkableNumber(0x00faff);
		public const dashedLengths:LinkableVariable = new LinkableVariable(null, verifyDashedLengths, [5, 5]);
		public function verifyDashedLengths(object:Object):Boolean
		{
			// backwards compatibility and support for linkBindableProperty with a text area
			if (object is String)
			{
				dashedLengths.setSessionState((object as String).split(',').map(function(str:String, i:int, a:Array):Number { return StandardLib.asNumber(str); }));
				return false;
			}
			
			var values:Array = object as Array;
			if (!values) 
				return false;
			var foundNonZero:Boolean = false;
			for (var i:int = 0; i < values.length; ++i)
			{
				// We want every value >= 0 with at least one value > 0 
				// Undefined and negative numbers are invalid.
				var value:int = int(values[i]);
				if (isNaN(value)) 
					return false;
				if (value < 0) 
					return false;
				if (value != 0)
					foundNonZero = true; 
			}
			
			return foundNonZero;
		}
		[Deprecated(replacement="dashedLengths")] public function get dashedSelectionBox():LinkableVariable { return dashedLengths; }
		
		public const panelTitleTextFormat:LinkableTextFormat = new LinkableTextFormat();
		public function get visTextFormat():LinkableTextFormat { return LinkableTextFormat.defaultTextFormat; }
		public const visTitleTextFormat:LinkableTextFormat = new LinkableTextFormat();
		public const axisTitleTextFormat:LinkableTextFormat = new LinkableTextFormat();
		public const mouseoverTextFormat:LinkableTextFormat = new LinkableTextFormat();
		
		public function get probeLineFormatter():LinkableFunction { return ProbeTextUtils.probeLineFormatter; }
		
		public const probeInnerGlow:LinkableGlowFilter = new LinkableGlowFilter(0xffffff, 1, 5, 5, 10);
		[Deprecated(replacement="probeInnerGlow")] public function set probeInnerGlowColor(value:Number):void { probeInnerGlow.color.value = value; }
		[Deprecated(replacement="probeInnerGlow")] public function set probeInnerGlowAlpha(value:Number):void { probeInnerGlow.alpha.value = value; }
		[Deprecated(replacement="probeInnerGlow")] public function set probeInnerGlowBlur(value:Number):void { probeInnerGlow.blurX.value = value; probeInnerGlow.blurY.value = value; }
		[Deprecated(replacement="probeInnerGlow")] public function set probeInnerGlowStrength(value:Number):void { probeInnerGlow.strength.value = value; }
		
		public const probeOuterGlow:LinkableGlowFilter = new LinkableGlowFilter(0, 1, 3, 3, 3);
		[Deprecated(replacement="probeOuterGlow")] public function set probeOuterGlowColor(value:Number):void { probeOuterGlow.color.value = value; }
		[Deprecated(replacement="probeOuterGlow")] public function set probeOuterGlowAlpha(value:Number):void { probeOuterGlow.alpha.value = value; }
		[Deprecated(replacement="probeOuterGlow")] public function set probeOuterGlowBlur(value:Number):void { probeOuterGlow.blurX.value = value; probeOuterGlow.blurY.value = value; }
		[Deprecated(replacement="probeOuterGlow")] public function set probeOuterGlowStrength(value:Number):void { probeOuterGlow.strength.value = value; }
		
		public const selectionDropShadow:LinkableDropShadowFilter = new LinkableDropShadowFilter(2, 45, 0, 0.5);
		[Deprecated(replacement="selectionDropShadow")] public function set shadowDistance(value:Number):void { selectionDropShadow.distance.value = value; }
		[Deprecated(replacement="selectionDropShadow")] public function set shadowAngle(value:Number):void { selectionDropShadow.angle.value = value; }
		[Deprecated(replacement="selectionDropShadow")] public function set shadowColor(value:Number):void { selectionDropShadow.color.value = value; }
		[Deprecated(replacement="selectionDropShadow")] public function set shadowAlpha(value:Number):void { selectionDropShadow.alpha.value = value; }
		[Deprecated(replacement="selectionDropShadow")] public function set shadowBlur(value:Number):void { selectionDropShadow.blurX.value = value; selectionDropShadow.blurY.value = value; }
		
		public const probeToolTipBackgroundAlpha:LinkableNumber = new LinkableNumber(1.0, verifyAlpha);
		public const probeToolTipBackgroundColor:LinkableNumber = new LinkableNumber(NaN);
		public const probeToolTipFontColor:LinkableNumber = new LinkableNumber(0x000000, isFinite);
		public const probeToolTipMaxWidth:LinkableNumber = registerLinkableChild(this, new LinkableNumber(400), handleToolTipMaxWidth);
		private function handleToolTipMaxWidth():void
		{
			ToolTip.maxWidth = Weave.properties.probeToolTipMaxWidth.value;
		}
		
		public const enableProbeLines:LinkableBoolean = new LinkableBoolean(true);
		public const enableAnnuliCircles:LinkableBoolean = new LinkableBoolean(false);
		public function get enableProbeToolTip():LinkableBoolean { return ProbeTextUtils.enableProbeToolTip; }
		public function get showEmptyProbeRecordIdentifiers():LinkableBoolean { return ProbeTextUtils.showEmptyProbeRecordIdentifiers; }

		public const probeBufferSize:LinkableNumber = new LinkableNumber(10, verifyNonNegativeNumber);
		
		public const toolInteractions:InteractionController = new InteractionController();
		
		// temporary?
		public const rServiceURL:LinkableString = registerLinkableChild(this, new LinkableString("/WeaveServices/RService"), handleRServiceURLChange);// url of Weave R service using Rserve
		public const pdbServiceURL:LinkableString = new LinkableString("/WeavePDBService/PDBService");
		private var _rService:WeaveRServlet;
		public function getRService():WeaveRServlet
		{
			if (!_rService || _rService.servletURL != Weave.properties.rServiceURL.value)
			{
				if (_rService)
					disposeObject(_rService);
				_rService = registerDisposableChild(this, new WeaveRServlet(Weave.properties.rServiceURL.value));
			}
			return _rService;
		}

		public const externalTools:LinkableHashMap = registerLinkableChild(this, new LinkableHashMap(LinkableString));
		
		private function handleRServiceURLChange():void
		{
			rServiceURL.value = rServiceURL.value.replace('OpenIndicatorsRServices', 'WeaveServices');
			if (rServiceURL.value == '/WeaveServices')
				rServiceURL.value += '/RService';
		}
		
		//default URL
		public const searchServiceURLs:LinkableString = new LinkableString([WIKIPEDIA_URL, GOOGLE_URL, GOOGLE_IMAGES_URL, GOOGLE_MAPS_URL].join('\n'));
		
		// when this is true, a rectangle will be drawn around the screen bounds with the background
		public const debugScreenBounds:LinkableBoolean = new LinkableBoolean(false);
		
		/**
		 * This field contains JavaScript code that will run when Weave is loaded, immediately after the session state
		 * interface is initialized.  The variable 'weave' can be used in the JavaScript code to refer to the weave instance.
		 */
		public const startupJavaScript:LinkableString = new LinkableString();
		
		[Embed(source="WeaveStartup.js", mimeType="application/octet-stream")]
		private static const WeaveStartup:Class;

		/**
		 * This function will run the JavaScript code specified in the startupScript LinkableString.
		 */
		public function runStartupJavaScript():void
		{
			WeaveAPI.initializeJavaScript(WeaveStartup);
			if (startupJavaScript.value)
				JavaScript.exec({"this": "weave", "catch": reportError}, startupJavaScript.value);
		}
		
		/**
		 * @see weave.core.LinkableFunction#macros
		 */
		public function get macros():ILinkableHashMap { return LinkableFunction.macros; }
		/**
		 * @see weave.core.LinkableFunction#macroLibraries
		 */
		public function get macroLibraries():LinkableVariable { return LinkableFunction.macroLibraries; }
		/**
		 * @see weave.core.LinkableFunction#includeMacroLibrary
		 */
		public function includeMacroLibrary(libraryName:String):void
		{
			LinkableFunction.includeMacroLibrary(libraryName);
		}
		
		public const workspaceWidth:LinkableNumber = new LinkableNumber(NaN);
		public const workspaceHeight:LinkableNumber = new LinkableNumber(NaN);
		public const workspaceMultiplier:LinkableNumber = new LinkableNumber(1, verifyWorkspaceMultiplier);

		private function verifyWorkspaceMultiplier(value:Number):Boolean
		{
			return value >= 1 && value <= 4;
		}
		
		public function get SecondaryKeyNumColumn_useGlobalMinMaxValues():LinkableBoolean { return SecondaryKeyNumColumn.useGlobalMinMaxValues; }
		public const maxComputationTimePerFrame:LinkableNumber = new LinkableNumber(100);
		
		
		public const filter_callbacks:ICallbackCollection = new CallbackCollection();
		public const filter_probeGlowInnerText:GlowFilter = new GlowFilter(0, 0.9, 2, 2, 255);
		public const filter_probeGlowInner:GlowFilter = new GlowFilter(0, 0.9, 5, 5, 10);
		public const filter_probeGlowOuter:GlowFilter = new GlowFilter(0, 0.7, 3, 3, 10);
		public const filter_selectionShadow:DropShadowFilter = new DropShadowFilter(1, 45, 0, 0.5, 4, 4, 2);
		private function updateFilters():void
		{
			probeInnerGlow.copyTo(filter_probeGlowInnerText);
			filter_probeGlowInnerText.blurX = 2;
			filter_probeGlowInnerText.blurY = 2;
			filter_probeGlowInnerText.strength = 255;
			
			probeInnerGlow.copyTo(filter_probeGlowInner);
			probeOuterGlow.copyTo(filter_probeGlowOuter);
			selectionDropShadow.copyTo(filter_selectionShadow);
		}
		private function initBitmapFilterCallbacks():void
		{
			var objects:Array = [
				enableBitmapFilters,
				selectionAlphaAmount,
				probeInnerGlow,
				probeOuterGlow,
				selectionDropShadow
			];
			for each (var object:ILinkableObject in objects)
				registerLinkableChild(filter_callbacks, object);
			filter_callbacks.addImmediateCallback(this, updateFilters, true);
		}
		
		private function verifyNonNegativeNumber(value:Number):Boolean { return value >= 0; }

		//--------------------------------------------
		// BACKWARDS COMPATIBILITY
		[Deprecated(replacement="visTextFormat")] public function set defaultTextFormat(value:*):void
		{
			setSessionState(visTextFormat, value);
			setSessionState(visTitleTextFormat, value);
			setSessionState(axisTitleTextFormat, value);
		}
		
		[Deprecated(replacement="panelTitleTextFormat.color")] public function set panelTitleFontColor(value:Number):void { panelTitleTextFormat.color.value = value; }
		[Deprecated(replacement="panelTitleTextFormat.size")] public function set panelTitleFontSize(value:Number):void { panelTitleTextFormat.size.value = value; }
		[Deprecated(replacement="panelTitleTextFormat.font")] public function set panelTitleFontStyle(value:String):void { panelTitleTextFormat.font.value = value; }
		[Deprecated(replacement="panelTitleTextFormat.font")] public function set panelTitleFontFamily(value:String):void { panelTitleTextFormat.font.value = value; }
		[Deprecated(replacement="panelTitleTextFormat.bold")] public function set panelTitleFontBold(value:Boolean):void { panelTitleTextFormat.bold.value = value; }
		[Deprecated(replacement="panelTitleTextFormat.italic")] public function set panelTitleFontItalic(value:Boolean):void { panelTitleTextFormat.italic.value = value; }
		[Deprecated(replacement="panelTitleTextFormat.underline")] public function set panelTitleFontUnderline(value:Boolean):void { panelTitleTextFormat.underline.value = value; }
		
		[Deprecated(replacement="visTextFormat.color")] public function set axisFontFontColor(value:Number):void { visTextFormat.color.value = value; }
		[Deprecated(replacement="visTextFormat.size")] public function set axisFontFontSize(value:Number):void { visTextFormat.size.value = value; }
		[Deprecated(replacement="visTextFormat.font")] public function set axisFontFontFamily(value:String):void { visTextFormat.font.value = value; }
		[Deprecated(replacement="visTextFormat.bold")] public function set axisFontFontBold(value:Boolean):void { visTextFormat.bold.value = value; }
		[Deprecated(replacement="visTextFormat.italic")] public function set axisFontFontItalic(value:Boolean):void { visTextFormat.italic.value = value; }
		[Deprecated(replacement="visTextFormat.underline")] public function set axisFontFontUnderline(value:Boolean):void { visTextFormat.underline.value = value; }
		
		[Deprecated(replacement="enableSessionHistoryControls")] public function set showSessionHistoryControls(value:Boolean):void { enableSessionHistoryControls.value = enableSessionMenu.value && value; }
		[Deprecated(replacement="dashboardMode")] public function set enableToolBorders(value:Boolean):void { dashboardMode.value = !value; }
		[Deprecated(replacement="dashboardMode")] public function set enableBorders(value:Boolean):void { dashboardMode.value = !value; }
		[Deprecated(replacement="showProbeToolTipEditor")] public function set showProbeColumnEditor(value:Boolean):void { showProbeToolTipEditor.value = value; }
		[Deprecated(replacement="windowSnapGridSize")] public function set enableToolAutoResizeAndPosition(value:Boolean):void { if (!value) windowSnapGridSize.value = value ? '1%' : '1'; }
		[Deprecated(replacement="windowSnapGridSize")] public function set enablePanelCoordsPercentageMode(value:Boolean):void { if (!value) windowSnapGridSize.value = value ? '1%' : '1'; }
		[Deprecated(replacement="rServiceURL")] public function set rServicesURL(value:String):void
		{
			if (value != '/OpenIndicatorsRServices')
				rServiceURL.value = value + '/RService';
		}
		
		[Deprecated(replacement="menuToggles")] public function get toolToggles():ILinkableHashMap { return menuToggles; }
		private function _toggleMenuItem(className:String, value:Boolean):void
		{
			var lb:LinkableBoolean = menuToggles.requestObject(className, LinkableBoolean, false);
			lb.value = value;
		}
		[Deprecated(replacement="getMenuToggle")] public function getToolToggle(classDef:Class):LinkableBoolean { return getMenuToggle(classDef); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddAttributeMenuTool(value:Boolean):void { _toggleMenuItem("AttributeMenuTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddBarChart(value:Boolean):void { _toggleMenuItem("CompoundBarChartTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddColorLegend(value:Boolean):void { _toggleMenuItem("ColorBinLegendTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddColormapHistogram(value:Boolean):void { _toggleMenuItem("ColormapHistogramTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddCompoundRadViz(value:Boolean):void { _toggleMenuItem("CompoundRadVizTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddCustomTool(value:Boolean):void { _toggleMenuItem("CustomTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddSchafersMissingDataTool(value:Boolean):void { _toggleMenuItem("SchafersMissingDataTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddDataTable(value:Boolean):void { _toggleMenuItem("DataTableTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddGaugeTool(value:Boolean):void { _toggleMenuItem("GaugeTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddHistogram(value:Boolean):void { _toggleMenuItem("HistogramTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAdd2DHistogram(value:Boolean):void { _toggleMenuItem("Histogram2DTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddLineChart(value:Boolean):void { _toggleMenuItem("LineChartTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddDimensionSliderTool(value:Boolean):void { _toggleMenuItem("DimensionSliderTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddMap(value:Boolean):void { _toggleMenuItem("MapTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddPieChart(value:Boolean):void { _toggleMenuItem("PieChartTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddPieChartHistogram(value:Boolean):void { _toggleMenuItem("PieChartHistogramTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddRadViz(value:Boolean):void { _toggleMenuItem("RadVizTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddRScriptEditor(value:Boolean):void { _toggleMenuItem("RTextEditor", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddScatterplot(value:Boolean):void { _toggleMenuItem("ScatterPlotTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddThermometerTool(value:Boolean):void { _toggleMenuItem("ThermometerTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddTimeSliderTool(value:Boolean):void { _toggleMenuItem("TimeSliderTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddRamachandranPlot(value:Boolean):void { _toggleMenuItem("RamachandranPlotTool", value); }
		[Deprecated(replacement="getMenuToggle")] public function set enableAddDataStatisticsTool(value:Boolean):void { _toggleMenuItem("DataStatisticsTool", value); }
		//--------------------------------------------
		
		public function handleMissingSessionStateProperty(newState:Object, missingProperty:String):void
		{
			if (newState.hasOwnProperty('version') && missingProperty == 'mouseoverTextFormat')
				copySessionState(visTextFormat, mouseoverTextFormat);
			if (missingProperty == 'panelBackgroundColor')
				panelBackgroundColor.value = 0xFFFFFF;
		}
	}
}
