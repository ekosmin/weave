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

package weave.visualization.plotters
{
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.utils.Dictionary;
	
	import weave.api.data.ColumnMetadata;
	import weave.api.data.IColumnStatistics;
	import weave.api.data.IQualifiedKey;
	import weave.api.linkSessionState;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.setSessionState;
	import weave.api.ui.ISelectableAttributes;
	import weave.api.ui.IPlotTask;
	import weave.core.LinkableNumber;
	import weave.data.AttributeColumns.BinnedColumn;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.EquationColumn;
	import weave.data.AttributeColumns.FilteredColumn;
	import weave.data.AttributeColumns.StringLookupColumn;
	import weave.primitives.ColorRamp;
	import weave.utils.BitmapText;
	import weave.utils.LinkableTextFormat;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * @author adufilie
	 */
	public class PieChartHistogramPlotter extends AbstractPlotter implements ISelectableAttributes
	{
		public function PieChartHistogramPlotter()
		{
			_beginRadians = newSpatialProperty(EquationColumn);
			_beginRadians.equation.value = "0.5 * PI + getRunningTotal(spanRadians) - getNumber(spanRadians)";
			_spanRadians = _beginRadians.requestVariable("spanRadians", EquationColumn, true);
			_spanRadians.equation.value = "getNumber(binSize) / getSum(binSize) * 2 * PI";
			var binSize:EquationColumn = _spanRadians.requestVariable("binSize", EquationColumn, true);
			binSize.equation.value = "getValue(binLookup).length";
			_binLookup = binSize.requestVariable("binLookup", StringLookupColumn, true);
			_binLookupStats = WeaveAPI.StatisticsCache.getColumnStatistics(_binLookup);
			_binnedData = _binLookup.requestLocalObject(BinnedColumn, true);
			_filteredData = binnedData.internalDynamicColumn.requestLocalObject(FilteredColumn, true);
			linkSessionState(filteredKeySet.keyFilter, _filteredData.filter);
			registerLinkableChild(this, _binnedData);
			setSingleKeySource(_filteredData);
			
			var ecArray:Array = [_beginRadians, _spanRadians, binSize];
			var nameArray:Array = ["beginRadians", "spanRadians", "binSize"];
			while (ecArray.length)
			{
				var metadata:Object = {};
				metadata[ColumnMetadata.TITLE] = nameArray.pop();
				(ecArray.pop() as EquationColumn).metadata.value = metadata;
			}
			
			registerLinkableChild(this, LinkableTextFormat.defaultTextFormat); // redraw when text format changes
		}
		
		public function getSelectableAttributeNames():Array
		{
			return ["Data"];
		}
		public function getSelectableAttributes():Array
		{
			return [unfilteredData];
		}
		
		public var _beginRadians:EquationColumn;
		public var _spanRadians:EquationColumn;
		public var _binLookup:StringLookupColumn;
		public var _binLookupStats:IColumnStatistics;
		public var _binnedData:BinnedColumn;
		public var _filteredData:FilteredColumn;
		
		public const chartColors:ColorRamp = registerLinkableChild(this, new ColorRamp(ColorRamp.getColorRampXMLByName("Paired"))); // bars get their color from here
		
		public function get binnedData():BinnedColumn { return _binnedData; }
		
		public function get unfilteredData():DynamicColumn { return _filteredData.internalDynamicColumn; }
		public const line:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		public const labelAngleRatio:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0, verifyLabelAngleRatio));
		public const innerRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0, verifyInnerRadius));
		
		private function verifyLabelAngleRatio(value:Number):Boolean
		{
			return 0 <= value && value <= 1;
		}
		private function verifyInnerRadius(value:Number):Boolean
		{
			return 0 <= value && value <= 1;
		}
		
		/**
		 * This draws the histogram bins that a list of record keys fall into.
		 */
		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			var binKeys:Array;
			var binKeyMap:Dictionary;
			if (task.iteration == 0)
			{
				// convert record keys to bin keys
				// save a mapping of each bin key found to a record key in that bin
				binKeyMap = new Dictionary();
				for each (var recordKey:IQualifiedKey in task.recordKeys)
					binKeyMap[ _binLookup.getStringLookupKeyFromInternalColumnKey(recordKey) ] = recordKey;
				
				binKeys = [];
				for (var binQKey:* in binKeyMap)
					binKeys.push(binQKey);
				
				task.asyncState.binKeys = binKeys;
				task.asyncState.binKeyMap = binKeyMap;
			}
			
			binKeyMap = task.asyncState.binKeyMap;
			binKeys = task.asyncState.binKeys;
			
			if (task.iteration < binKeys.length)
			{
				//------------------------
				// draw one record
				var binKey:IQualifiedKey = binKeys[task.iteration] as IQualifiedKey;
				tempShape.graphics.clear();
				
				drawBin(task, binKey);
				
				if (clipDrawing)
				{
					// get clipRectangle
					task.screenBounds.getRectangle(clipRectangle);
					// increase width and height by 1 to avoid clipping rectangle borders drawn with vector graphics.
					clipRectangle.width++;
					clipRectangle.height++;
				}
				task.buffer.draw(tempShape, null, null, null, clipDrawing ? clipRectangle : null);
				//------------------------
				
				// report progress
				return task.iteration / binKeys.length;
			}
			
			// report progress
			return 1;
		}
		
		protected function drawBin(task:IPlotTask, binKey:IQualifiedKey):void
		{
			// project data coordinates to screen coordinates and draw graphics
			var beginRadians:Number = _beginRadians.getValueFromKey(binKey, Number);
			var spanRadians:Number = _spanRadians.getValueFromKey(binKey, Number);
			
			var graphics:Graphics = tempShape.graphics;
			// begin line & fill
			line.beginLineStyle(binKey, graphics);
			//fill.beginFillStyle(recordKey, graphics);
			
			// draw graphics
			var color:Number = chartColors.getColorFromNorm( _binLookupStats.getNorm(binKey) );
			graphics.beginFill(color, 1);
			
			// move to center point
			WedgePlotter.drawProjectedWedge(graphics, task.dataBounds, task.screenBounds, beginRadians, spanRadians, 0, 0, 1, innerRadius.value);
			// end fill
			graphics.endFill();
		}
		
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			if (_filteredData.keys.length == 0)
				return;
			
			var binKey:IQualifiedKey;
			var beginRadians:Number;
			var spanRadians:Number;
			var midRadians:Number;
			var xScreenRadius:Number;
			var yScreenRadius:Number;
			
			var binKeyMap:Dictionary = new Dictionary();
			for (var j:int = 0; j < _filteredData.keys.length; j++)
				binKeyMap[ _binLookup.getStringLookupKeyFromInternalColumnKey(_filteredData.keys[j] as IQualifiedKey)] = true;
			
			var binKeys:Array = [];
			for (var binQKey:* in binKeyMap)
				binKeys.push(binQKey);
			
			for (var i:int; i < binKeys.length; i++)
			{
				binKey = binKeys[i] as IQualifiedKey;
				beginRadians = _beginRadians.getValueFromKey(binKey, Number) as Number;
				spanRadians = _spanRadians.getValueFromKey(binKey, Number) as Number;
				midRadians = beginRadians + (spanRadians / 2);
				
				var cos:Number = Math.cos(midRadians);
				var sin:Number = Math.sin(midRadians);
				
				_tempPoint.x = cos;
				_tempPoint.y = sin;
				dataBounds.projectPointTo(_tempPoint, screenBounds);
				_tempPoint.x += cos * 10 * screenBounds.getXDirection();
				_tempPoint.y += sin * 10 * screenBounds.getYDirection();
				
				_bitmapText.text = binKey.localName;
				
				_bitmapText.verticalAlign = BitmapText.VERTICAL_ALIGN_MIDDLE;
				
				_bitmapText.angle = screenBounds.getYDirection() * (midRadians * 180 / Math.PI);
				_bitmapText.angle = (_bitmapText.angle % 360 + 360) % 360;
				if (cos > -0.000001) // the label exactly at the bottom will have left align
				{
					_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_LEFT;
					// first get values between -90 and 90, then multiply by the ratio
					_bitmapText.angle = ((_bitmapText.angle + 90) % 360 - 90) * labelAngleRatio.value;
				}
				else
				{
					_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_RIGHT;
					// first get values between -90 and 90, then multiply by the ratio
					_bitmapText.angle = (_bitmapText.angle - 180) * labelAngleRatio.value;
				}
				LinkableTextFormat.defaultTextFormat.copyTo(_bitmapText.textFormat);
				_bitmapText.x = _tempPoint.x;
				_bitmapText.y = _tempPoint.y;
				_bitmapText.draw(destination);
			}
		}
		
		private const _tempPoint:Point = new Point();
		private const _bitmapText:BitmapText = new BitmapText();
		
		/**
		 * This gets the data bounds of the bin that a record key falls into.
		 */
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			var binKey:IQualifiedKey = _binLookup.getStringLookupKeyFromInternalColumnKey(recordKey);
			var beginRadians:Number = _beginRadians.getValueFromKey(binKey, Number);
			var spanRadians:Number = _spanRadians.getValueFromKey(binKey, Number);
			WedgePlotter.getWedgeBounds(initBoundsArray(output), beginRadians, spanRadians);
		}
		
		/**
		 * This function returns a Bounds2D object set to the data bounds associated with the background.
		 * @param outputDataBounds A Bounds2D object to store the result in.
		 */
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			output.setBounds(-1, -1, 1, 1);
		}

		// backwards compatibility
		[Deprecated(replacement="line")] public function set lineStyle(value:Object):void { try { setSessionState(line, value[0].sessionState); } catch (e:Error) { } }
	}
}
