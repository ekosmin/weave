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

package weave.ui.CustomDataGrid
{
	import mx.controls.dataGridClasses.DataGridColumn;
	import mx.core.mx_internal;
	
	import weave.Weave;
	import weave.api.data.IQualifiedKey;
	import weave.data.KeySets.KeySet;
	
	use namespace mx_internal;	                          
	
	public class CustomDataGridWithFilters extends CustomDataGrid
	{
		public function CustomDataGridWithFilters()
		{
			super();
		}

		// need to set default filter when user sets the dataprovider
		override public function set dataProvider(value:Object):void
		{
			super.dataProvider = value;
			collection.filterFunction = filterKeys;
			collection.refresh();
		}

		private var _filtersEnabled:Boolean = false;
		
		public function set enableFilters(val:Boolean):void
		{
			if(_filtersEnabled != val)
			{
				_filtersEnabled = val;
				invalidateFilters();
			}			
		}
		
		public function invalidateFilters():void
		{
			_filtersInValid = true;	
			invalidateDisplayList();
		}
		private var _filtersInValid:Boolean = true;
		
		private var selectedKeySet:KeySet = Weave.defaultSelectionKeySet;
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			if (_filtersInValid)
			{ 
				_filtersInValid = false;	
				if(_filtersEnabled)
				{
					filteredKeys = [];
					filterContainsAllKeys = true;
					columnFilterFunctions = getAllFilterFunctions();
					collection.filterFunction = callAllFilterFunctions;
					//refresh call the respective function(**callAllFilterFunctions**) through internalrefresh in listCollectionView 
					collection.refresh();
					if (filterContainsAllKeys)
						selectedKeySet.clearKeys();
					else
						selectedKeySet.replaceKeys(filteredKeys);
					filteredKeys = null;
				}
				else
				{					
					collection.filterFunction = filterKeys;
					collection.refresh();
					selectedKeySet.clearKeys();
				}
			}			
		}
		
		// contains keys filtered by filterfunctions in each WeaveCustomDataGridColumn
		private var filteredKeys:Array;		
		private var columnFilterFunctions:Array;
		private var filterContainsAllKeys:Boolean;
		
		/**
		 * This function is a logical AND of each WeaveCustomDataGridColumn filter function
		 * Called by following sequnce of Function
		 * commitProperties -> listcollectionview.refresh -> internalrefresh -> callAllfilterFunction through reference
		 */		
		protected function callAllFilterFunctions(key:Object):Boolean
		{
			for each (var cff:Function in columnFilterFunctions)
				if (!cff(key))
					return filterContainsAllKeys = false;
			if (filteredKeys)
				filteredKeys.push(key);
			return true;
		}
				
		
		//Collects all filterfunctions associated with each WeaveCustomDataGridColumn
		// returns those filter functions as Array
		protected function getAllFilterFunctions():Array
		{
			var cff:Array = [filterKeys];
			for each (var column:DataGridColumn in columns)
			{
				if (column is DataGridColumnForQKeyWithFilterAndGraphics)
				{
					var mc:DataGridColumnForQKeyWithFilterAndGraphics = DataGridColumnForQKeyWithFilterAndGraphics(column);					
					if (mc.filterComponent)
					{
						var filter:IFilterComponent = mc.filterComponent;
						if(filter.isActive)
							cff.push(filter.filterFunction);
					}						
				}
			}
			return  cff;
		}
	
		private function filterKeys(item:Object):Boolean
		{
			if(Weave.defaultSubsetKeyFilter.containsKey(item as IQualifiedKey))
				return true;
			else 
				return false;
		}
		
		
	}
}