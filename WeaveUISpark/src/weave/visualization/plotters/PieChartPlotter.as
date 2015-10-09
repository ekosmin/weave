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
	import flash.display.Shape;
	import flash.geom.Point;
	
	import weave.Weave;
	import weave.api.data.IQualifiedKey;
	import weave.api.linkSessionState;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.setSessionState;
	import weave.api.ui.ISelectableAttributes;
	import weave.api.ui.IPlotTask;
	import weave.core.LinkableNumber;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.EquationColumn;
	import weave.data.AttributeColumns.FilteredColumn;
	import weave.data.AttributeColumns.SortedColumn;
	import weave.utils.BitmapText;
	import weave.utils.LinkableTextFormat;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * @author adufilie
	 */
	public class PieChartPlotter extends AbstractPlotter implements ISelectableAttributes
	{
		public function PieChartPlotter()
		{
			fill.color.internalDynamicColumn.globalName = Weave.DEFAULT_COLOR_COLUMN;
			
			_beginRadians = newSpatialProperty(EquationColumn);
			_beginRadians.equation.value = "0.5 * PI + getRunningTotal(spanRadians) - getNumber(spanRadians)";
			_spanRadians = _beginRadians.requestVariable("spanRadians", EquationColumn, true);
			_spanRadians.equation.value = "getNumber(sortedData) / getSum(sortedData) * 2 * PI";
			var sortedData:SortedColumn = _spanRadians.requestVariable("sortedData", SortedColumn, true);
			_filteredData = sortedData.internalDynamicColumn.requestLocalObject(FilteredColumn, true);
			linkSessionState(filteredKeySet.keyFilter, _filteredData.filter);
			
			setColumnKeySources([_filteredData]);
			
			registerSpatialProperty(data);
			registerLinkableChild(this, LinkableTextFormat.defaultTextFormat); // redraw when text format changes
		}
		
		public function getSelectableAttributeNames():Array
		{
			return ["Wedge Size","Wedge Color","Label"];
		}
		public function getSelectableAttributes():Array
		{
			return [data, fill.color, label];
		}

		private var _beginRadians:EquationColumn;
		private var _spanRadians:EquationColumn;
		private var _filteredData:FilteredColumn;
		
		public function get data():DynamicColumn { return _filteredData.internalDynamicColumn; }
		public const label:DynamicColumn = newLinkableChild(this, DynamicColumn);
		
		public const line:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		public const fill:SolidFillStyle = newLinkableChild(this, SolidFillStyle);
		
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
		
		private var _destination:BitmapData;
		
		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			_destination = task.buffer;
			return super.drawPlotAsyncIteration(task);
		}
		
		override protected function addRecordGraphicsToTempShape(recordKey:IQualifiedKey, dataBounds:IBounds2D, screenBounds:IBounds2D, tempShape:Shape):void
		{
			// project data coordinates to screen coordinates and draw graphics
			var beginRadians:Number = _beginRadians.getValueFromKey(recordKey, Number);
			var spanRadians:Number = _spanRadians.getValueFromKey(recordKey, Number);
			
			var graphics:Graphics = tempShape.graphics;
			// begin line & fill
			line.beginLineStyle(recordKey, graphics);				
			fill.beginFillStyle(recordKey, graphics);
			// move to center point
			WedgePlotter.drawProjectedWedge(graphics, dataBounds, screenBounds, beginRadians, spanRadians, 0, 0, 1, innerRadius.value);
			// end fill
			graphics.endFill();
			
			//----------------------
			
			// draw label
			var midRadians:Number;
			if (!label.containsKey(recordKey as IQualifiedKey))
				return;
			beginRadians = _beginRadians.getValueFromKey(recordKey, Number) as Number;
			spanRadians = _spanRadians.getValueFromKey(recordKey, Number) as Number;
			midRadians = beginRadians + (spanRadians / 2);
			
			var cos:Number = Math.cos(midRadians);
			var sin:Number = Math.sin(midRadians);
			
			_tempPoint.x = cos;
			_tempPoint.y = sin;
			dataBounds.projectPointTo(_tempPoint, screenBounds);
			_tempPoint.x += cos * 10 * screenBounds.getXDirection();
			_tempPoint.y += sin * 10 * screenBounds.getYDirection();
			
			_bitmapText.text = label.getValueFromKey(recordKey, String);
			
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
			_bitmapText.draw(_destination);
		}
		
		private const _tempPoint:Point = new Point();
		private const _bitmapText:BitmapText = new BitmapText();
		
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			var beginRadians:Number = _beginRadians.getValueFromKey(recordKey, Number);
			var spanRadians:Number = _spanRadians.getValueFromKey(recordKey, Number);
			var bounds:IBounds2D = initBoundsArray(output, 1);
			WedgePlotter.getWedgeBounds(bounds, beginRadians, spanRadians);
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
		[Deprecated(replacement="fill")] public function set fillStyle(value:Object):void { try { setSessionState(fill, value[0].sessionState); } catch (e:Error) { } }
	}
}
