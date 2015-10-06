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

package weave.application
{
	import flash.display.DisplayObject;
	import flash.events.ContextMenuEvent;
	import flash.events.MouseEvent;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	
	import mx.collections.ArrayCollection;
	import mx.containers.HBox;
	import mx.controls.Button;
	import mx.controls.ComboBox;
	import mx.controls.Label;
	import mx.controls.Spacer;
	import mx.events.ListEvent;
	
	import weave.Weave;
	import weave.api.copySessionState;
	import weave.data.KeySets.KeySet;
	import weave.ui.AlertTextBox;
	import weave.ui.AlertTextBoxEvent;
	import weave.ui.CustomComboBox;
	import weave.ui.CustomContextMenuManager;
	import weave.utils.ProbeTextUtils;
	
	internal class SearchEngineUtils
	{
		private static var _globalProbeKeySet:KeySet = null; // pointer to global probe key set
		private static const _localProbeKeySet:KeySet = new KeySet(); // local object to store last non-empty probe set
		
		/**
		 * @param context Any object created as a descendant of a Weave instance.
		 * @param destination The display object to add the context menu items to.
		 * @return true on success 
		 */		
		public static function createContextMenuItems(destination:DisplayObject):Boolean
		{
			if(!destination.hasOwnProperty("contextMenu") )
				return false;
				
			if(!Weave.properties.enableSearchForRecord.value)
				return false;
			
			_globalProbeKeySet = Weave.root.getObject(Weave.DEFAULT_PROBE_KEYSET) as KeySet;
				
			var destinationContextMenu:ContextMenu = destination["contextMenu"] as ContextMenu;
			
			destinationContextMenu.addEventListener(ContextMenuEvent.MENU_SELECT, handleContextMenuOpened);
						
			addSearchQueryContextMenuItem(destination);
			
			return true;	
		}
		
		private static var _searchQueryContextMenuItems:Array = [];
		// Add a context menu item for searching for a given probed record in a search engine.
		public static function addSearchQueryContextMenuItem(destination:DisplayObject):void
		{	
			if(!destination.hasOwnProperty("contextMenu") )
				return;
				
			var destinationContextMenu:ContextMenu = destination["contextMenu"] as ContextMenu;
						
			var cmi:ContextMenuItem = CustomContextMenuManager.createAndAddMenuItemToDestination(
					"Search for record online",
					destination, 
					handleSearchQueryContextMenuItemSelect,
					"2 searchMenuItems"
				);
			_searchQueryContextMenuItems.push(cmi);
		}
		
		private static function handleContextMenuOpened(event:ContextMenuEvent):void
		{
			copySessionState(_globalProbeKeySet, _localProbeKeySet);
			
			for each (var cmi:ContextMenuItem in _searchQueryContextMenuItems)
			{
				cmi.enabled = _localProbeKeySet.keys.length > 0;
			}
		}
		
		private static function handleSearchQueryContextMenuItemSelect(event:ContextMenuEvent):void
		{
			var probeText:String = ProbeTextUtils.getProbeText(_localProbeKeySet.keys, null);
			if (probeText == null)
				return;
			// get first line of text only
			var query:String = probeText.split('\n')[0];
			for each(var cmi:ContextMenuItem in _searchQueryContextMenuItems)
			{
				if(cmi == event.currentTarget)
				{
					if(cmi.enabled)
					{
						var combobox:CustomComboBox = new CustomComboBox(); //ComboBox to hold the service names
						var urlAlert:AlertTextBox = AlertTextBox.show("Custom URL",null);
						var hbox:HBox = new HBox();						
						var label:Label = new Label();
						var detailsButton:Button = new Button();
						
						detailsButton.toggle = true;
						detailsButton.label = "Show Details";
						detailsButton.toolTip = "Click to display the URL used for this service"
						urlAlert.removeChild(urlAlert.inputCanvas);
						detailsButton.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void {																	
							if(detailsButton.selected) 
								urlAlert.addChildAt(urlAlert.inputCanvas,2);
							else 								
								urlAlert.removeChild(urlAlert.inputCanvas);							
						});
						
						hbox.toolTip = "Please select a service from the dropdown menu";
						urlAlert.textBox.toolTip = "This is the URL used to search for the record";
						label.text = "Select a service: ";
						
						hbox.addChild(label); hbox.addChild(combobox); hbox.addChild(detailsButton);
						urlAlert.addChildAt(hbox,0 );
						urlAlert.addChildAt(new Spacer(),0);
						
						try { // don't throw error if string is empty
							// replace any combinations of linefeeds and newlines with one newline character for consistency
							Weave.properties.searchServiceURLs.value = Weave.properties.searchServiceURLs.value.replace(/[\r\n]+/g,"\n");
							fillCBoxDataProvider(combobox);
							urlAlert.textInput = combobox.selectedItem.url;
						} catch (e:Error) {} 
						combobox.addEventListener(ListEvent.CHANGE, function(e:ListEvent):void{
							urlAlert.textInput = combobox.selectedItem.url;
						});
						urlAlert.addEventListener(AlertTextBoxEvent.BUTTON_CLICKED, function (e:AlertTextBoxEvent):void {
							if( !e.confirm ) return ;
							//append queried record's name to the end of the url
							navigateToURL(new URLRequest(urlAlert.textInput + query), "_blank");							
						});						
					}
				}
			}
		}
		
		private static function fillCBoxDataProvider(cbox:ComboBox):void
		{
			/* Example string in session state for Weave.properties.searchServiceURLs
			<searchServiceURLs>Wikipedia|http://en.wikipedia.org/wiki/Special:Search?search=
			Google|http://www.google.com/search?q=
			Google Images|http://images.google.com/images?q=
			Google Maps|http://maps.google.com/maps?t=h&amp;q=</searchServiceURLs>
			*/
			var services:Array = Weave.properties.searchServiceURLs.value.split("\n");
			var serviceObjects:Array = [] ;
			var serviceString:Array;
			for( var i:int = 0; i < services.length; i++ ) 
			{
				try{
					var obj:Object = new Object();
					serviceString = (services[i] as String).split( '|');
					obj.name = serviceString[0];
					obj.url = serviceString[1];
					serviceObjects.push(obj);
				} catch(error:Error){}
			}						
			cbox.dataProvider = new ArrayCollection(serviceObjects);
			//display only service name field in combobox
			cbox.labelField = 'name';		
		}		
	}
}