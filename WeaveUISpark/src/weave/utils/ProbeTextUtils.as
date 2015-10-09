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

package weave.utils
{
	import flash.display.Stage;
	
	import mx.core.IToolTip;
	import mx.core.UIComponent;
	import mx.managers.ToolTipManager;
	
	import weave.Weave;
	import weave.api.core.ILinkableHashMap;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.primitives.IBounds2D;
	import weave.compiler.StandardLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableFunction;
	import weave.core.LinkableHashMap;
	import weave.primitives.Bounds2D;
	
	/**
	 * A static class containing functions to manage a list of probed attribute columns
	 * 
	 * @author adufilie
	 */
	public class ProbeTextUtils
	{
		public static const enableProbeToolTip:LinkableBoolean = new LinkableBoolean(true);
		public static const showEmptyProbeRecordIdentifiers:LinkableBoolean = new LinkableBoolean(true);
		
		public static function get probedColumns():ILinkableHashMap
		{
			// this initializes the probed columns object map if not created yet, otherwise just returns the existing one
			return Weave.root.requestObject("Probed Columns", LinkableHashMap, true);
		}
		
		public static function get probeHeaderColumns():ILinkableHashMap
		{
			return Weave.root.requestObject("Probe Header Columns", LinkableHashMap, true);
		}
		
		public static const DEFAULT_LINE_FORMAT:String = 'str = replace(lpad(string, 8, "\\t"), "\\t", "  ");\nstr + " (" + title + ")"';
		
		/**
		 * This function is used to format each line corresponding to a column in probedColumns.
		 */
		public static const probeLineFormatter:LinkableFunction = new LinkableFunction(DEFAULT_LINE_FORMAT, true, false, ['column', 'key', 'string', 'title']);
		
		/**
		 * Additional columns (or ILinkableHashMaps containing columns) to be used by getProbeText() when the additionalAttributes parameter is not specified.
		 * This variable will be set automatically when that parameter is passed to getProbeText().
		 */
		private static var savedAdditionalAttributes:Array = null;
		
		/**
		 * @param keySet The key set you are interested in.
		 * @param additionalAttributes An array of additional columns (or ILinkableHashMaps containing columns) to be included in the probe text.
		 *                               If this parameter is not specified, the previously specified Array (or null) will be used.
		 * @return A String containing formatted values from the probed columns.
		 */
		public static function getProbeText(keys:Array, additionalAttributes:* = undefined):String
		{
			// save the additional columns for the next time this function is called so the same info will be returned.
			if (additionalAttributes !== undefined)
				savedAdditionalAttributes = additionalAttributes;
			
			var result:String = '';
			var headers:Array = probeHeaderColumns.getObjects(IAttributeColumn);
			// include headers in list of columns so that those appearing in the headers won't be duplicated.
			var columns:Array = headers.concat(probedColumns.getObjects(IAttributeColumn));
			// add additional columns (flatten any hash maps)
			for each (var item:Object in savedAdditionalAttributes)
			{
				if (item is ILinkableHashMap)
					columns = columns.concat((item as ILinkableHashMap).getObjects(IAttributeColumn));
				else if (item is IAttributeColumn)
					columns.push(item);
			}
			
			var keys:Array = keys.concat();
			StandardLib.sort(keys);
			var key:IQualifiedKey;
			var recordCount:int = 0;
			var maxRecordsShown:Number = Weave.properties.maxTooltipRecordsShown.value;
			for (var iKey:int = 0; iKey < keys.length && iKey < maxRecordsShown; iKey++)
			{
				key = keys[iKey] as IQualifiedKey;

				var record:String = '';
				for (var iHeader:int = 0; iHeader < headers.length; iHeader++)
				{
					var header:IAttributeColumn = headers[iHeader] as IAttributeColumn;
					var headerValue:String = StandardLib.asString(header.getValueFromKey(key, String));
					if (headerValue == '')
						continue;
					if (record)
						record += ', ';
					record += headerValue;
				}
				
				if (record)
					record += '\n';
				var lookup:Object = {};
				for (var iColumn:int = 0; iColumn < columns.length; iColumn++)
				{
					var column:IAttributeColumn = columns[iColumn] as IAttributeColumn;
					if (!column)
						continue;
					var value:String = String(column.getValueFromKey(key, String));
					if (!value || value == 'NaN')
						continue;
					var title:String = ColumnUtils.getTitle(column);
					try
					{
						var line:String = probeLineFormatter.apply(null, [column, key, value, title]) + '\n';
						// prevent duplicate lines from being added
						if (lookup[line] == undefined)
						{
							if (!(value.toLowerCase() == 'undefined' || title.toLowerCase() == 'undefined'))
							{
								lookup[line] = true; // this prevents the line from being duplicated
								// the headers are only included so that the information will not be duplicated
								if (iColumn >= headers.length)
									record += line;
							}
						}
					}
					catch (e:Error)
					{
						//reportError(e);
					}
				}
				if (record)
				{
					result += record + '\n';
					recordCount++;
				}
			}
			// remove ending '\n'
			while (result.substr(result.length - 1) == '\n')
				result = result.substr(0, result.length - 1);
			
			if (!result && showEmptyProbeRecordIdentifiers.value)
			{
				result = 'Record Identifier' + (keys.length > 1 ? 's' : '') + ':\n';
				for (var i:int = 0; i < keys.length && i < maxRecordsShown; i++)
				{
					key = keys[i] as IQualifiedKey;
					result += '    ' + key.keyType + '#' + key.localName + '\n';
					recordCount++;
				}
			}
			
			if (result && recordCount >= maxRecordsShown && keys.length > maxRecordsShown)
			{
				result += '\n... (' + keys.length + ' records total, ' + recordCount + ' shown)';
			}

			return result;
		}
		
		private static function setProbeToolTipAppearance():void
		{
			(probeToolTip as UIComponent).setStyle("backgroundAlpha", Weave.properties.probeToolTipBackgroundAlpha.value);
			if (isFinite(Weave.properties.probeToolTipBackgroundColor.value))
				(probeToolTip as UIComponent).setStyle("backgroundColor", Weave.properties.probeToolTipBackgroundColor.value);
			Weave.properties.mouseoverTextFormat.copyToStyle(probeToolTip as UIComponent);
		}

		public static var yAxisToolTip:IToolTip;
		public static var xAxisToolTip:IToolTip;
		//For now the toolTipLocation.value parameter will be utilised by the ColorBinLegendTool. In the future this feature can be generalised for every tool.
		public static function showProbeToolTip(probeText:String, stageX:Number, stageY:Number, stageBounds:IBounds2D = null, margin:int = 5):void
		{
			hideProbeToolTip();
		
			if (!enableProbeToolTip.value)
				return;
			
			if (!probeText || WeaveAPI.globalHashMap.getObject("ProbeToolTipWindow"))
				return;
			
			if (!probeToolTip)
				probeToolTip = ToolTipManager.createToolTip('', 0, 0);
		
			var stage:Stage = WeaveAPI.StageUtils.stage;
			tempBounds.setBounds(stage.x, stage.y, stage.stageWidth, stage.stageHeight);
		
			if (stageBounds == null)
				stageBounds = tempBounds;
		
			// create new tooltip
			probeToolTip.text = probeText;
			probeToolTip.visible = true;
		
			// make tooltip completely opaque because text + graphics on same sprite is slow
			setProbeToolTipAppearance();
		
			//this step is required to set the height and width of probeToolTip to the right size.
			(probeToolTip as UIComponent).validateNow();
		
			var xMin:Number = stageBounds.getXNumericMin();
			var yMin:Number = stageBounds.getYNumericMin();
			var xMax:Number = stageBounds.getXNumericMax() - probeToolTip.width;
			var yMax:Number = stageBounds.getYNumericMax() - probeToolTip.height;
		
			// calculate y coordinate
			var y:int;
			// calculate y pos depending on toolTipAbove setting
			if (toolTipAbove)
			{
				y = stageY - (probeToolTip.height + 2 * margin);
				if (yAxisToolTip != null)
					y = yAxisToolTip.y - margin - probeToolTip.height ;
			}
			else // below
			{
				y = stageY + margin * 2;
				if (yAxisToolTip != null)
					y = yAxisToolTip.y + yAxisToolTip.height+margin;
			}
		
			// flip y position if out of bounds
			if ((y < yMin && toolTipAbove) || (y > yMax && !toolTipAbove))
				toolTipAbove = !toolTipAbove;
			
			// calculate x coordinate
			var x:int;
			if (cornerToolTip)
			{
				// check twice to prevent flipping back and forth when weave desktop size is very small
				for (var checkTwice:int = 0; checkTwice < 2; checkTwice++)
				{
					// want toolTip corner to be near probe point
					if (toolTipToTheLeft)
					{
						x = stageX - margin - probeToolTip.width;
						if(xAxisToolTip != null)
							x = xAxisToolTip.x - margin - probeToolTip.width; 
					}
					else // to the right
					{
						x = stageX + margin;
						if(xAxisToolTip != null)
							x = xAxisToolTip.x+xAxisToolTip.width+margin;
					}
				
					// flip x position if out of bounds
					if ((x < xMin && toolTipToTheLeft) || (x > xMax && !toolTipToTheLeft))
						toolTipToTheLeft = !toolTipToTheLeft;
				}
			}
			else // center x coordinate
			{
				x = stageX - probeToolTip.width / 2;
			}
		
			// if at lower-right corner of mouse, shift to the right 10 pixels to get away from the mouse pointer
			if (x > stageX && y > stageY)
				x += 10;
			
			// enforce min/max values and position tooltip
			x = Math.max(xMin, Math.min(x, xMax));
			y = Math.max(yMin, Math.min(y, yMax));
		
			probeToolTip.move(x, y);
		}
		
		
		/**
		 * cornerToolTip:
		 * false = center of tooltip will be aligned with x probe coordinate
		 * true = corner of tooltip will be aligned with x probe coordinate
		 */
		private static var cornerToolTip:Boolean = true;
		private static var toolTipAbove:Boolean = true;
		private static var toolTipToTheLeft:Boolean = false;
		private static var probeToolTip:IToolTip = null;
		private static const tempBounds:IBounds2D = new Bounds2D();	
		
		
		public static function hideProbeToolTip():void
		{
			if (probeToolTip)
				probeToolTip.visible = false;
		}
	}
}
