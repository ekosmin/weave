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
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.events.MouseEvent;
	
	import mx.containers.Canvas;
	import mx.controls.DataGrid;
	import mx.controls.Image;
	import mx.controls.Label;
	import mx.controls.listClasses.BaseListData;
	import mx.controls.listClasses.IDropInListItemRenderer;
	import mx.core.UIComponent;
	
	import weave.api.data.ColumnMetadata;
	import weave.api.data.DataType;
	import weave.api.data.IQualifiedKey;
	import weave.data.AttributeColumns.ImageColumn;

	public class DataGridQKeyRendererWithGraphics extends Canvas implements IDropInListItemRenderer
	{
		public function DataGridQKeyRendererWithGraphics()
		{
		}
		
		private var _listData:BaseListData;

		public function get listData():BaseListData
		{
			return _listData;
		}
		
		public function set listData(value:BaseListData):void
		{
			_listData = value;
			if (_listData && _listData.owner is CustomDataGrid)
				column = (_listData.owner as CustomDataGrid).getColumn(_listData.columnIndex) as DataGridColumnForQKeyWithFilterAndGraphics;
			else
				column = null;
		}

		override protected function createChildren():void
		{
			super.createChildren();
			
			addChild(lbl);
			lbl.percentWidth = 100;
			horizontalScrollPolicy = "off";
			addEventListener(MouseEvent.ROLL_OVER, handleRollOver);
		}
		
		private function handleRollOver(event:MouseEvent):void
		{
			if (toolTip != lbl.text)
				toolTip = lbl.text;
		}
		
		private var column:DataGridColumnForQKeyWithFilterAndGraphics;
		private var img:Image;
		public const lbl:Label = new Label();
		
		override public function set data(item:Object):void
		{
			super.data = item as IQualifiedKey;
			invalidateProperties();
		}
		
		private static function _setStyle(target:UIComponent, styleProp:String, newValue:*):void
		{
			if (target.getStyle(styleProp) != newValue)
				target.setStyle(styleProp, newValue);
		}
		
		override public function validateProperties():void
		{
			if (column && column.attrColumn)
			{
				var key:IQualifiedKey = data as IQualifiedKey;
				if (column.attrColumn is ImageColumn)
				{
					lbl.visible = false;
					lbl.text = '';
					if (!img)
					{
						img = new Image();
						img.x = 1; // because there is a vertical grid line on the left that overlaps the item renderer
						img.source = new Bitmap(null, 'auto', true);
						addChild(img);
					}
					img.visible = true;
					(img.source as Bitmap).bitmapData = column.attrColumn.getValueFromKey(key, BitmapData) as BitmapData;
				}
				else
				{
					lbl.visible = true;
					lbl.text = column.attrColumn.getValueFromKey(key, String);
					if (img)
					{
						img.visible = false;
						img.source.bitmapData = null;
					}
				}
			}
			super.validateProperties();
		}
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			var g:Graphics = graphics;
			g.clear();
			
			if (!owner || !column || !column.attrColumn)
				return;
			
			var grid:DataGrid = owner as DataGrid || owner.parent as DataGrid;
			var hasSelection:Boolean = column.selectionKeySet && column.selectionKeySet.keys.length > 0;
			var hasProbe:Boolean = column.probeKeySet && column.probeKeySet.keys.length > 0;
			
			if (hasSelection || hasProbe)
			{
				if (grid.isItemSelected(data) || grid.isItemHighlighted(data))
				{
					_setStyle(lbl, "fontWeight", "bold");
					alpha = 1.0;
				}				
				else
				{
					_setStyle(lbl, "fontWeight", "normal");
					alpha = hasSelection ? 0.3 : 1.0;
				}
			}
			else
			{
				_setStyle(lbl, "fontWeight", "normal");
				alpha = 1.0;	
			}
			
			// right-align numbers
			if (column.attrColumn.getMetadata(ColumnMetadata.DATA_TYPE) == DataType.NUMBER)
			{
				_setStyle(lbl, 'textAlign', 'right');
			}
			else
			{
				_setStyle(lbl, 'textAlign', 'left');
			}
			
			if (column.showColors && column.showColors.value)
			{
				var colorValue:Number = column.colorFunction(column.attrColumn, data as IQualifiedKey, this);
				_setStyle(this, 'backgroundColor', colorValue);
			}
			else
			{
				_setStyle(this, 'backgroundColor', null);
			}
		}
	}
}