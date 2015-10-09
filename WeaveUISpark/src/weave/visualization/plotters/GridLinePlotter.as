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
	import flash.display.CapsStyle;
	import flash.display.Graphics;
	import flash.geom.Point;
	
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.ui.IPlotter;
	import weave.core.LinkableNumber;
	import weave.primitives.Bounds2D;
	import weave.primitives.LinkableBounds2D;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	public class GridLinePlotter extends AbstractPlotter
	{
		WeaveAPI.ClassRegistry.registerImplementation(IPlotter, GridLinePlotter, "Grid lines");
		
		public function GridLinePlotter()
		{
			lineStyle.caps.defaultValue.value = CapsStyle.NONE;
		}
		
		public const lineStyle:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		
		public const bounds:LinkableBounds2D = newSpatialProperty(LinkableBounds2D);
		public const xInterval:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const yInterval:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const xOffset:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const yOffset:LinkableNumber = newLinkableChild(this, LinkableNumber);
		
		private const tempPoint:Point = new Point();
		private const lineBounds:Bounds2D = new Bounds2D();
		
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			bounds.copyTo(output);
		}
		
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var graphics:Graphics = tempShape.graphics;
			graphics.clear();
			lineStyle.beginLineStyle(null, graphics);
			
			bounds.copyTo(lineBounds);

			// find appropriate bounds for lines
			var xMin:Number = numericMax(lineBounds.getXNumericMin(), dataBounds.getXNumericMin());
			var yMin:Number = numericMax(lineBounds.getYNumericMin(), dataBounds.getYNumericMin());
			var xMax:Number = numericMin(lineBounds.getXNumericMax(), dataBounds.getXNumericMax());
			var yMax:Number = numericMin(lineBounds.getYNumericMax(), dataBounds.getYNumericMax());
			
			// x
			if (yMin < yMax)
			{
				var x0:Number = xOffset.value || 0;
				var dx:Number = Math.abs(xInterval.value);
				var xScale:Number = dataBounds.getXCoverage() / screenBounds.getXCoverage();
				
				if (xMin < xMax && ((xMin - x0) % dx == 0 || dx == 0))
					drawLine(xMin, yMin, xMin, yMax, graphics, dataBounds, screenBounds);
				
				if (dx > xScale) // don't draw sub-pixel intervals
				{
					var xStart:Number = xMin - (xMin - x0) % dx;
					if (xStart <= xMin)
						xStart += dx;
					for (var ix:int = 0, x:Number = xStart; x < xMax; x = xStart + dx * ++ix)
						drawLine(x, yMin, x, yMax, graphics, dataBounds, screenBounds);
				}
				else if (isFinite(xOffset.value) && xMin < x0 && x0 < xMax)
					drawLine(x0, yMin, x0, yMax, graphics, dataBounds, screenBounds);
				
				if (xMin <= xMax && ((xMax - x0) % dx == 0 || dx == 0))
					drawLine(xMax, yMin, xMax, yMax, graphics, dataBounds, screenBounds);
			}
			
			// y
			if (xMin < xMax)
			{
				var y0:Number = yOffset.value || 0;
				var dy:Number = Math.abs(yInterval.value);
				var yScale:Number = dataBounds.getYCoverage() / screenBounds.getYCoverage();
				
				if (yMin < yMax && ((yMin - y0) % dy == 0 || dy == 0))
					drawLine(xMin, yMin, xMax, yMin, graphics, dataBounds, screenBounds);
				
				if (dy > yScale) // don't draw sub-pixel intervals
				{
					var yStart:Number = yMin - (yMin - y0) % dy;
					if (yStart <= yMin)
						yStart += dy;
					for (var iy:int = 0, y:Number = yStart; y < yMax; y = yStart + dy * ++iy)
						drawLine(xMin, y, xMax, y, graphics, dataBounds, screenBounds);
				}
				else if (isFinite(yOffset.value) && yMin < y0 && y0 < yMax)
					drawLine(xMin, y0, xMax, y0, graphics, dataBounds, screenBounds);
				
				if (yMin <= yMax && ((yMax - y0) % dy == 0 || dy == 0))
					drawLine(xMin, yMax, xMax, yMax, graphics, dataBounds, screenBounds);
			}
			
			// flush buffer
			destination.draw(tempShape);
		}
		
		private function numericMin(userValue:Number, systemValue:Number):Number
		{
			return userValue < systemValue ? userValue : systemValue; // if userValue is NaN, returns systemValue
		}
		
		private function numericMax(userValue:Number, systemValue:Number):Number
		{
			return userValue > systemValue ? userValue : systemValue; // if userValue is NaN, returns systemValue
		}
		
		private function drawLine(xMin:Number, yMin:Number, xMax:Number, yMax:Number, graphics:Graphics, dataBounds:IBounds2D, screenBounds:IBounds2D):void
		{
			tempPoint.x = xMin;
			tempPoint.y = yMin;
			dataBounds.projectPointTo(tempPoint, screenBounds);
			graphics.moveTo(tempPoint.x, tempPoint.y);
			
			tempPoint.x = xMax;
			tempPoint.y = yMax;
			dataBounds.projectPointTo(tempPoint, screenBounds);
			graphics.lineTo(tempPoint.x, tempPoint.y);
		}
		
		//////////////////////////////////////////////////////////////////////////////////////////////
		// backwards compatibility
		
		[Deprecated] public function set interval(value:Number):void { handleDeprecated('interval', value); }
		[Deprecated] public function set start(value:Number):void { handleDeprecated('start', value); }
		[Deprecated] public function set end(value:Number):void { handleDeprecated('end', value); }
		[Deprecated] public function set horizontal(value:Boolean):void { handleDeprecated('alongXAxis', !value); }
		[Deprecated] public function set alongXAxis(value:Boolean):void { handleDeprecated('alongXAxis', value); }
		private var _deprecated:Object;
		private function handleDeprecated(name:String, value:*):void
		{
			if (!_deprecated)
				_deprecated = {};
			_deprecated[name] = value;
			
			for each (name in ['start','end','alongXAxis','interval'])
				if (!_deprecated.hasOwnProperty(name))
					return;
			
			if (_deprecated['alongXAxis'])
			{
				xInterval.value = _deprecated['interval'];
				xOffset.value = _deprecated['start'];
				bounds.setBounds(_deprecated['start'], NaN, _deprecated['end'], NaN);
			}
			else
			{
				yInterval.value = _deprecated['interval'];
				yOffset.value = _deprecated['start'];
				bounds.setBounds(NaN, _deprecated['start'], NaN, _deprecated['end']);
			}
			_deprecated = null;
		}
	}
}
